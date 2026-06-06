local uv = vim.loop or vim.uv
local config = require('gemini.config')

local M = {}

local TOKEN_FILE = vim.fn.stdpath("cache") .. "/gemini.nvim/oauth_token.json"
local AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
local TOKEN_URL = "https://oauth2.googleapis.com/token"
local SCOPE = "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/generative-language.retriever"
local REDIRECT_URI = "http://localhost:3333"

local function save_tokens(tokens)
  vim.schedule(function()
    local dir = vim.fn.fnamemodify(TOKEN_FILE, ":h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
    local f = io.open(TOKEN_FILE, "w")
    if f then
      f:write(vim.json.encode(tokens))
      f:close()
    end
  end)
end

local function load_tokens()
  local f = io.open(TOKEN_FILE, "r")
  if f then
    local content = f:read("*a")
    f:close()
    return vim.json.decode(content)
  end
  return nil
end

local function exchange_code(code, callback)
  local oauth_cfg = config.get_config('oauth')
  local data = {
    code = code,
    client_id = oauth_cfg.client_id,
    client_secret = oauth_cfg.client_secret,
    redirect_uri = REDIRECT_URI,
    grant_type = "authorization_code",
  }

  local cmd = {
    'curl', '-s', '-X', 'POST', TOKEN_URL,
    '-H', 'Content-Type: application/x-www-form-urlencoded',
    '-d', string.format("code=%s&client_id=%s&client_secret=%s&redirect_uri=%s&grant_type=%s",
      data.code, data.client_id, data.client_secret, data.redirect_uri, data.grant_type)
  }

  vim.system(cmd, {}, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        local tokens = vim.json.decode(obj.stdout)
        if tokens.access_token then
          tokens.expires_at = os.time() + (tokens.expires_in or 3600)
          save_tokens(tokens)
          print("Tokens saved successfully at " .. TOKEN_FILE)
          if callback then callback(tokens) end
        else
          print("Error exchanging code: " .. obj.stdout)
          vim.notify("OAuth Error: " .. (tokens.error_description or tokens.error or "Unknown error"), vim.log.levels.ERROR)
        end
      else
        print("Error in curl: " .. obj.stderr)
        vim.notify("OAuth Curl Error: " .. obj.stderr, vim.log.levels.ERROR)
      end
    end)
  end)
end

M.authenticate = function()
  local oauth_cfg = config.get_config('oauth')
  if not oauth_cfg or oauth_cfg.client_id == "" or oauth_cfg.client_secret == "" then
    print("OAuth client_id and client_secret must be configured in gemini.nvim setup.")
    return
  end

  local server = uv.new_tcp()
  server:bind("127.0.0.1", 3333)
  server:listen(128, function(err)
    vim.schedule(function()
      if err then
        print("Error listening on port 3333: " .. err)
        return
      end

      local client = uv.new_tcp()
      server:accept(client)
      client:read_start(function(read_err, data)
        vim.schedule(function()
          if read_err then
            client:close()
            return
          end

          if data then
            local first_line = data:match("([^\r\n]+)")
            local code = first_line:match("[?&]code=([^&%s]+)")

            local response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n"
                .. "<html><body><h1>Authentication Successful!</h1><p>You can close this window now and return to Neovim.</p></body></html>"
            client:write(response, function()
              client:shutdown(function()
                client:close()
                server:close()
              end)
            end)

            if code then
              print("Received authorization code, exchanging for tokens...")
              exchange_code(code, function()
                print("OAuth authentication successful!")
              end)
            else
              print("No code found in callback URL")
            end
          end
        end)
      end)
    end)
  end)

  local url = string.format("%s?client_id=%s&redirect_uri=%s&response_type=code&scope=%s&access_type=offline&prompt=consent",
    AUTH_URL, oauth_cfg.client_id, REDIRECT_URI, SCOPE:gsub(" ", "%%20"))

  print("Opening browser for OAuth authentication...")
  print("URL: " .. url)
  local opener
  if vim.ui.open then
    opener = function() vim.ui.open(url) end
  else
    opener = function() vim.fn.jobstart({ "xdg-open", url }) end
  end
  
  local status, err = pcall(opener)
  if not status then
    print("Failed to open browser: " .. tostring(err))
    vim.notify("Failed to open browser. Please open the URL manually from messages (:messages)", vim.log.levels.ERROR)
  end
end

M.refresh_token = function(tokens, callback)
  local oauth_cfg = config.get_config('oauth')
  local cmd = {
    'curl', '-s', '-X', 'POST', TOKEN_URL,
    '-H', 'Content-Type: application/x-www-form-urlencoded',
    '-d', string.format("refresh_token=%s&client_id=%s&client_secret=%s&grant_type=refresh_token",
      tokens.refresh_token, oauth_cfg.client_id, oauth_cfg.client_secret)
  }

  vim.system(cmd, {}, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        local new_tokens = vim.json.decode(obj.stdout)
        if new_tokens.access_token then
          tokens.access_token = new_tokens.access_token
          tokens.expires_at = os.time() + (new_tokens.expires_in or 3600)
          -- Keep old refresh_token if not provided
          if new_tokens.refresh_token then
            tokens.refresh_token = new_tokens.refresh_token
          end
          save_tokens(tokens)
          if callback then callback(tokens.access_token) end
        else
          print("Error refreshing token: " .. obj.stdout)
          if callback then callback(nil) end
        end
      else
        print("Error in curl: " .. obj.stderr)
        if callback then callback(nil) end
      end
    end)
  end)
end

M.get_token = function(callback)
  local tokens = load_tokens()
  if not tokens then
    print("No OAuth tokens found. Please run :GeminiAuthenticate")
    if callback then callback(nil) end
    return
  end

  if os.time() > (tokens.expires_at - 60) then -- Refresh 1 minute before expiry
    M.refresh_token(tokens, callback)
  else
    if callback then callback(tokens.access_token) end
  end
end

return M
