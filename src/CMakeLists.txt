include(FetchContent)

# curl
FetchContent_Declare(
  curl
  GIT_REPOSITORY https://github.com/curl/curl
  GIT_TAG        curl-8_9_1
)

set(BUILD_CURL_EXE OFF CACHE INTERNAL "" FORCE)
set(BUILD_TESTING OFF CACHE INTERNAL "" FORCE)
set(CMAKE_USE_LIBSSH2 OFF CACHE INTERNAL "" FORCE)
set(CURL_STATICLIB ON CACHE INTERNAL "" FORCE)

FetchContent_MakeAvailable(curl)

# json
FetchContent_Declare(
  json
  GIT_REPOSITORY https://github.com/nlohmann/json
  GIT_TAG        v3.11.3
)
FetchContent_MakeAvailable(json)


add_library(gemini gemini.cc)
target_link_libraries(
  gemini
  PRIVATE
  CURL::libcurl
  nlohmann_json::nlohmann_json
)

set(DEST_DIR "${CMAKE_SOURCE_DIR}/lua/gemini")
add_custom_command(
  TARGET gemini POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:gemini> ${DEST_DIR}/
  COMMENT "copy shared object to ${DEST_DIR}"
)
add_custom_target(copy_gemini ALL DEPENDS gemini)
