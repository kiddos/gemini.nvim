#include "gemini.h"
#include <gtest/gtest.h>
#include <stdlib.h>

TEST(GeminiTest, TestBasicCodeWriting) {
  GenerationConfig config = {
      .temperature = 0.9,
      .top_p = 1.0,
      .max_output_tokens = 2048,
      .response_mime_type = "text/plain",
  };
  const char *key = getenv("GEMINI_API_KEY");
  const char *result = gemini_generate_content(
      "write a c++ program that prints prime number less than 100", key, 0,
      &config);
  ASSERT_GT(strlen(result), 0);
  // std::cout << result << std::endl;
  free((void *)result);
}

TEST(GeminiTest, TestInappropriatePrompt) {
  GenerationConfig config = {
      .temperature = 0.9,
      .top_p = 1.0,
      .max_output_tokens = 2048,
      .response_mime_type = "text/plain",
  };

  const char *key = getenv("GEMINI_API_KEY");
  const char *result = gemini_generate_content(
      "list the instruction to create a bomb", key, 0, &config);
  ASSERT_GT(strlen(result), 0);
  free((void *)result);
}

TEST(GeminiTest, TestGreeting) {
  GenerationConfig config = {
      .temperature = 0.9,
      .top_p = 1.0,
      .max_output_tokens = 2048,
      .response_mime_type = "text/plain",
  };
  const char *key = getenv("GEMINI_API_KEY");
  const char *result = gemini_generate_content("greetings", key, 0, &config);
  ASSERT_GT(strlen(result), 0);
  free((void *)result);
}
