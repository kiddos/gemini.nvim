-- Helper for libuv operations
local uv = vim.loop or vim.uv

local M = {}

-- Base URL for the Google Gemini API
local API = "https://generativelanguage.googleapis.com/v1beta/models/"

-- A list of available Gemini models
M.MODELS = {
	GEMINI_2_5_FLASH_PREVIEW = "gemini-2.5-flash-preview-04-17",
	GEMINI_2_5_PRO_PREVIEW = "gemini-2.5-pro-preview-03-25",
	GEMINI_2_5_FLASH = "gemini-2.5-flash",
	GEMINI_2_5_PRO = "gemini-2.5-pro",
	GEMINI_2_0_FLASH = "gemini-2.0-flash",
	GEMINI_2_0_FLASH_LITE = "gemini-2.0-flash-lite",
	GEMINI_2_0_FLASH_EXP = "gemini-2.0-flash-exp",
	GEMINI_2_0_FLASH_THINKING_EXP = "gemini-2.0-flash-thinking-exp-1219",
	GEMINI_1_5_PRO = "gemini-1.5-pro",
	GEMINI_1_5_FLASH = "gemini-1.5-flash",
	GEMINI_1_5_FLASH_8B = "gemini-1.5-flash-8b",
}

local function get_api_key_from_file(callback)
	local path = vim.fn.expand("~/.gemini/api.key")
	vim.uv.fs_open(path, "r", 438, function(err, fd)
		if err then
			callback(nil) -- File doesn't exist or can't be opened, fallback.
			return
		end
		vim.uv.fs_fstat(fd, function(err, stat)
			if err then
				vim.uv.fs_close(fd, function() end)
				callback(nil)
				return
			end
			vim.uv.fs_read(fd, stat.size, 0, function(err, data)
				vim.uv.fs_close(fd, function() end)
				if err then
					callback(nil)
					return
				end
				local key = vim.trim(data)
				if key == "" then
					vim.notify("API key file is empty.", vim.log.levels.WARN)
					callback(nil)
				else
					vim.notify("Gemini: Successfully loaded API key from ~/.gemini/api.key")
					callback(key)
				end
			end)
		end)
	end)
end

--- Retrieves the Gemini API key.
-- It first tries to read from ~/.gemini/api.key.
-- If that fails, it falls back to the macOS keychain.
-- @param callback (function) A callback function that receives the API key.
local function get_api_key_async(callback)
	get_api_key_from_file(function(key)
		if key then
			callback(key)
			return
		end

		-- Fallback to keychain if file method fails.
		if vim.fn.has("mac") == 0 then
			vim.notify("API key file not found and keychain access is only supported on macOS.", vim.log.levels.ERROR)
			callback(nil)
			return
		end

		local cmd = "security"
		local args = { "find-generic-password", "-l", "gemini-cli", "-w" }
		local stdout = vim.loop.new_pipe(false)
		local stderr = vim.loop.new_pipe(false)
		local key_buffer = ""
		local err_buffer = ""

		local handle
		handle = vim.loop.spawn(cmd, {
			args = args,
			stdio = { nil, stdout, stderr },
		}, function(code, _)
			stdout:close()
			stderr:close()
			handle:close()

			if code ~= 0 then
				vim.notify(
					"Gemini: Could not find API key in file or keychain.",
					vim.log.levels.ERROR
				)
				if err_buffer ~= "" then
					vim.notify("Keychain Error: " .. err_buffer, vim.log.levels.INFO)
				end
				callback(nil)
			else
				local key = vim.trim(key_buffer)
				if key == "" then
					vim.notify("Gemini API key from keychain is empty.", vim.log.levels.WARN)
					callback(nil)
				else
					vim.notify("Gemini: Successfully loaded API key from macOS keychain.")
					callback(key)
				end
			end
		end)

		vim.loop.read_start(stdout, function(err, data)
			assert(not err, err)
			if data then
				key_buffer = key_buffer .. data
			end
		end)

		vim.loop.read_start(stderr, function(err, data)
			assert(not err, err)
			if data then
				err_buffer = err_buffer .. data
			end
		end)
	end)
end

---
-- Generates content using the Gemini API (non-streaming).
-- @param user_text (string) The user's prompt.
-- @param system_text (string|nil) Optional system instructions.
-- @param model_name (string) The model to use from M.MODELS.
-- @param generation_config (table) Configuration for the generation request.
-- @param callback (function|nil) Optional callback for asynchronous execution.
M.gemini_generate_content = function(user_text, system_text, model_name, generation_config, callback)
	get_api_key_async(function(api_key)
		if not api_key then
			if callback then
				callback(nil, "Failed to get API key")
			end
			return
		end

		local api = API .. model_name .. ":generateContent?key=" .. api_key
		local contents = {
			{
				role = "user",
				parts = {
					{
						text = user_text,
					},
				},
			},
		}
		local data = {
			contents = contents,
			generationConfig = generation_config,
		}
		if system_text then
			data.systemInstruction = {
				role = "user",
				parts = {
					{
						text = system_text,
					},
				},
			}
		end

		local json_text = vim.json.encode(data)
		local cmd = { "curl", "-X", "POST", api, "-H", "Content-Type: application/json", "--data-binary", "@-" }
		local opts = { stdin = json_text }

		-- Execute synchronously or asynchronously based on whether a callback is provided.
		if callback then
			vim.system(cmd, opts, callback)
		else
			return vim.system(cmd, opts)
		end
	end)
end

---
-- Generates content using the Gemini API (streaming).
-- @param user_text (string) The user's prompt.
-- @param model_name (string) The model to use from M.MODELS.
-- @param generation_config (table) Configuration for the generation request.
-- @param callback (function) Callback to handle each streamed data chunk.
M.gemini_generate_content_stream = function(user_text, model_name, generation_config, callback)
	if not callback then
		vim.notify("Streaming requires a callback function.", vim.log.levels.ERROR)
		return
	end

	get_api_key_async(function(api_key)
		if not api_key then
			return
		end

		local api = API .. model_name .. ":streamGenerateContent?alt=sse&key=" .. api_key
		local data = {
			contents = {
				{
					role = "user",
					parts = {
						{
							text = user_text,
						},
					},
				},
			},
			generationConfig = generation_config,
		}
		local json_text = vim.json.encode(data)

		local stdout = uv.new_pipe(false)
		local stderr = uv.new_pipe(false)
		local handle
		local stderr_buffer = ""

		-- Arguments for the curl command. Using -N disables output buffering, which is ideal for streams.
		-- The API URL is placed at the end, which is the standard position for curl.
		local options = {
			args = { "curl", "-X", "POST", "-s", "-N", "-H", "Content-Type: application/json", "-d", json_text, api },
			stdio = { nil, stdout, stderr },
		}

		-- Spawn the curl process.
		handle = uv.spawn("curl", options, function(code, _)
			-- Ensure pipes are closed when the process exits.
			stdout:close()
			stderr:close()
			if code ~= 0 then
				vim.schedule(function()
					vim.notify(
						"Gemini stream finished with non-zero exit code: " .. tostring(code),
						vim.log.levels.ERROR
					)
					if stderr_buffer ~= "" then
						vim.notify("Gemini API Error: " .. stderr_buffer, vim.log.levels.ERROR)
					end
				end)
			end
		end)

		if not handle then
			vim.notify("Failed to spawn curl for streaming.", vim.log.levels.ERROR)
			stdout:close()
			stderr:close()
			return
		end

		local streamed_data = ""
		-- Start reading from stdout.
		uv.read_start(stdout, function(err, data)
			if err then
				return
			end
			if data then
				streamed_data = streamed_data .. data

				-- Process Server-Sent Events (SSE). Events are separated by double newlines.
				while true do
					local s, e = string.find(streamed_data, "\n\n", 1, true)
					if not s then
						break -- No complete event block found, wait for more data.
					end

					-- Extract the complete event block.
					local chunk = string.sub(streamed_data, 1, e - 1)
					-- Remove the processed block from the buffer.
					streamed_data = string.sub(streamed_data, e + 1)

					-- Find the 'data:' line within the event block and pass it to the callback.
					local data_line = string.match(chunk, "data: (.*)")
					if data_line then
						callback(data_line)
					end
				end
			end
		end)

		-- Optionally, read from stderr for debugging.
		uv.read_start(stderr, function(err, data)
			if not err and data then
				stderr_buffer = stderr_buffer .. data
			end
		end)
	end)
end



return M
