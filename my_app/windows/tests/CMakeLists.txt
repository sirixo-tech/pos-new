cmake_minimum_required(VERSION 3.15)
project(windows_printer_channel_test LANGUAGES CXX)
set(EPHEMERAL "${CMAKE_CURRENT_SOURCE_DIR}/../flutter/ephemeral")
set(WRAPPER "${EPHEMERAL}/cpp_client_wrapper")
add_executable(windows_printer_channel_test
  windows_printer_channel_test.cpp
  ../runner/windows_printer.cpp
  ../runner/scanner_status.cpp
  "${WRAPPER}/standard_codec.cc"
  "${WRAPPER}/core_implementations.cc")
target_compile_features(windows_printer_channel_test PRIVATE cxx_std_17)
target_compile_definitions(windows_printer_channel_test PRIVATE
  UNICODE _UNICODE NOMINMAX _HAS_EXCEPTIONS=0)
target_compile_options(windows_printer_channel_test PRIVATE /EHsc /W4 /WX /wd4100)
target_include_directories(windows_printer_channel_test PRIVATE
  "${WRAPPER}/include" "${EPHEMERAL}")
target_link_libraries(windows_printer_channel_test PRIVATE
  "${EPHEMERAL}/flutter_windows.dll.lib" winspool.lib setupapi.lib)
add_custom_command(TARGET windows_printer_channel_test POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${EPHEMERAL}/flutter_windows.dll" "$<TARGET_FILE_DIR:windows_printer_channel_test>")
