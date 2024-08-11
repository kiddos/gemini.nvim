# gtest
include(FetchContent)
FetchContent_Declare(
  googletest
  GIT_REPOSITORY https://github.com/google/googletest.git
  GIT_TAG        release-1.12.0
)
# For Windows: Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

include_directories(${CMAKE_SOURCE_DIR}/src)

enable_testing()

add_executable(
  gemini_test
  gemini_test.cc
)
target_link_libraries(
  gemini_test
  GTest::gtest_main
  gemini
)

include(GoogleTest)
gtest_discover_tests(gemini_test)
