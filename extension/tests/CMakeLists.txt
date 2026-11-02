add_executable(extension_tests
  main.cpp
  test_client.cpp
  protocol_examples_test.cpp
  mixer_service_test.cpp
)
target_link_libraries(extension_tests PRIVATE transport doctest::doctest)
target_compile_definitions(extension_tests PRIVATE
  PROTOCOL_EXAMPLES_DIR="${PROJECT_SOURCE_DIR}/../protocol/examples"
)
rmm_compile_options(extension_tests)

add_test(NAME extension_tests COMMAND extension_tests)
