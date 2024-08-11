#ifndef GEMINI_H
#define GEMINI_H

extern "C" {

typedef struct {
  double temperature;
  double top_p;
  int max_output_tokens;
  const char *response_mime_type;
} GenerationConfig;

char *gemini_generate_content(const char *user_input, const char *api_key,
                              int model_id, GenerationConfig *config);
}

#endif /* end of include guard: GEMINI_H */
