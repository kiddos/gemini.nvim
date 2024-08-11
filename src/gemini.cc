#include "gemini.h"

#include <curl/curl.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

struct memory {
  char *response;
  size_t size;
};

static size_t cb(char *data, size_t size, size_t nmemb, void *clientp) {
  size_t realsize = size * nmemb;
  struct memory *mem = (struct memory *)clientp;

  char *ptr = (char *)realloc(mem->response, mem->size + realsize + 1);
  if (!ptr) {
    return 0;
  }

  mem->response = ptr;
  memcpy(&(mem->response[mem->size]), data, realsize);
  mem->size += realsize;
  mem->response[mem->size] = '\0';

  return realsize;
}

std::string http_post(const std::string &url, const std::string &json) {
  curl_global_init(CURL_GLOBAL_ALL);
  CURL *curl = curl_easy_init();
  struct memory chunk = {nullptr, 0};

  std::string result;
  if (curl) {
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_POST, 1L);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk);

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    CURLcode res = curl_easy_perform(curl);

    if (res == CURLE_OK) {
      result = chunk.response;
    }
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
  }
  curl_global_cleanup();
  return result;
}

nlohmann::json parse_config_to_json(GenerationConfig *config) {
  using json = nlohmann::json;
  json config_json;
  if (config) {
    if (config->temperature > 0) {
      config_json["temperature"] = config->temperature;
    }
    if (config->top_p > 0) {
      config_json["topP"] = config->top_p;
    }
    if (config->max_output_tokens > 0) {
      config_json["maxOutputTokens"] = config->max_output_tokens;
    }
    if (config->response_mime_type) {
      config_json["responseMimeType"] = config->response_mime_type;
    }
  }
  return config_json;
}

nlohmann::json get_content(nlohmann::json &j,
                           const std::vector<std::string> &keys) {
  using json = nlohmann::json;
  json output = j;
  for (std::string key : keys) {
    if (output.is_array()) {
      int index = stoi(key);
      if (output.size() == 0) {
        return json();
      }
      output = output[index];
    } else if (output.is_object()) {
      if (!output.contains(key)) {
        return json();
      }
      output = output[key];
    } else {
      return json();
    }
  }
  return output;
}

std::string get_model(int model_id) {
  if (model_id == 0) {
    return "gemini-1.0-pro";
  } else if (model_id == 1) {
    return "gemini-1.5-pro";
  } else if (model_id == 2) {
    return "gemini-1.5-flash";
  }
  return "";
}

extern "C" char *gemini_generate_content(const char *user_input,
                                         const char *api_key, int model_id,
                                         GenerationConfig *config) {
  using json = nlohmann::json;

  if (!api_key || strlen(api_key) == 0 || !user_input ||
      strlen(user_input) == 0) {
    return nullptr;
  }

  std::string model_name = get_model(model_id);
  if (model_name.empty()) {
    return nullptr;
  }

  std::string api = "https://generativelanguage.googleapis.com/v1beta/models/";
  api += model_name;
  api += ":generateContent?key=";
  api += api_key;

  json j;
  j["contents"] = {{{"role", "user"}, {"parts", {{"text", user_input}}}}};
  j["generationConfig"] = parse_config_to_json(config);

  std::string result = http_post(api, j.dump());

  json response_json = json::parse(result);
  json model_text_json = get_content(
      response_json, {"candidates", "0", "content", "parts", "0", "text"});
  std::string model_text;
  if (model_text_json.is_string()) {
    model_text = model_text_json.template get<std::string>();
  }
  char *output = (char *)malloc(model_text.length() + 1);
  strcpy(output, model_text.c_str());
  return output;
}
