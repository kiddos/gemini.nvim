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

--- Retrieves the Gemini API key from the macOS keychain.
-- This function executes the `security` command to fetch the password
-- stored for the "gemini-cli" generic password item.
-- @return (string|nil) The API key if found, or nil if an error occurs.
local function get_api_key()
	-- The `security` command is specific to macOS.
	if vim.fn.has("mac") == 0 then
		vim.notify("Keychain access is only supported on macOS.", vim.log.levels.ERROR)
		return nil
	end

	local cmd = { "security", "find-generic-password", "-l", "gemini-cli", "-w" }
	-- Execute the command synchronously and wait for the result.
	local result = vim.system(cmd):wait()

	-- Check if the command executed successfully. A non-zero exit code indicates an error.
	if result.code ~= 0 then
		vim.notify("Error getting Gemini API key from keychain. Is it stored under 'gemini-cli'?", vim.log.levels.ERROR)
		-- Log stderr for debugging purposes.
		if result.stderr and result.stderr ~= "" then
			vim.notify("Keychain Error: " .. result.stderr, vim.log.levels.INFO)
		end
		return nil
	end

	-- The key is in stdout. Trim whitespace and newlines from the output.
	local key = vim.trim(result.stdout)

	-- Check if the retrieved key is empty.
	if key == "" then
		vim.notify("Gemini API key from keychain is empty.", vim.log.levels.WARN)
		return nil
	end

	return key
end

--- Generates content using the Gemini API (non-streaming).
-- @param user_text (string) The user's prompt.
-- @param system_text (string|nil) Optional system instructions.
-- @param model_name (string) The model to use from M.MODELS.
-- @param generation_config (table) Configuration for the generation request.
-- @param callback (function|nil) Optional callback for asynchronous execution.
M.gemini_generate_content = function(user_text, system_text, model_name, generation_config, callback)
	-- Retrieve the API key from the keychain instead of an environment variable.
	local api_key = get_api_key()
	if not api_key then
		-- Return an empty string to maintain the original function's behavior on failure.
		return ""
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
		return vim.system(cmd, opts, callback)
	else
		return vim.system(cmd, opts)
	end
end

--- Generates content using the Gemini API (streaming).
-- @param user_text (string) The user's prompt.
-- @param model_name (string) The model to use from M.MODELS.
-- @param generation_config (table) Configuration for the generation request.
-- @param callback (function) Callback to handle each streamed data chunk.
M.gemini_generate_content_stream = function(user_text, model_name, generation_config, callback)
	-- Retrieve the API key from the keychain.
	local api_key = get_api_key()
	if not api_key then
		return
	end

	if not callback then
		vim.notify("Streaming requires a callback function.", vim.log.levels.ERROR)
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
			vim.notify("Gemini stream finished with non-zero exit code: " .. tostring(code), vim.log.levels.WARN)
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
			vim.notify("Gemini stream stderr: " .. data, vim.log.levels.INFO)
		end
	end)
end

return M
