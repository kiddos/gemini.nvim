local M = {}

local ffi = require('ffi')

local get_current_dir = function()
  return string.gsub(debug.getinfo(1).short_src, "^(.+/)[^/]+$", "%1");
end

local get_lib = function()
  local current_dir = get_current_dir()
  return current_dir .. '/libgemini.so'
end

ffi.cdef [[
void free(void *ptr);
]]

ffi.cdef [[
typedef struct {
  double temperature;
  double top_p;
  int max_output_tokens;
  const char *response_mime_type;
} GenerationConfig;

char *gemini_generate_content(const char *user_input, const char *api_key,
                              int model_id, GenerationConfig *config);
]]

local lib = ffi.load(get_lib())

M.MODELS = {
  GEMINI_1_0_PRO = 0,
  GEMINI_1_5_PRO = 1,
  GEMINI_1_5_FLASH = 2,
}

M.gemini_generate_content = function(user_text, model_id, generation_config)
  local key = os.getenv("GEMINI_API_KEY")
  local config = ffi.new("GenerationConfig[1]", { generation_config })
  local result = lib.gemini_generate_content(user_text, key, model_id, config)
  if result then
    local response = ffi.string(result)
    ffi.C.free(result)
    return response
  end
  return ''
end

return M
