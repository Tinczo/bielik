cmake_minimum_required(VERSION 3.24)
project(reaper_mobile_mixer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
# Link the MSVC runtime statically so the extension is a single drop-in .dll.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

if(NOT MSVC)
  message(FATAL_ERROR "REAPER extensions on Windows must be built with MSVC "
                      "(use -G \"Visual Studio 17 2022\" -A x64).")
endif()

include(cmake/Dependencies.cmake)

# Our own code: UTF-8 sources (the monitor prefix is "Odsłuch:"), strict warnings.
function(rmm_compile_options target)
  target_compile_options(${target} PRIVATE /utf-8 /W4 /permissive-)
  # windows.h (pulled in by reaper_plugin.h) must not drag in winsock.h before winsock2.h.
  target_compile_definitions(${target} PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
endfunction()

# Monitors core: pure logic, knows neither the REAPER API nor sockets.
add_library(monitor_core STATIC
  src/core/monitor_core.cpp
  src/core/monitors.cpp
)
target_include_directories(monitor_core PUBLIC src)
target_link_libraries(monitor_core PUBLIC nlohmann_json::nlohmann_json)
rmm_compile_options(monitor_core)

# Transport: WebSocket server on its own thread, queues to and from the main thread,
# and the mDNS announcement (Windows DNS-SD API from dnsapi).
add_library(transport STATIC
  src/transport/websocket_transport.cpp
  src/transport/mixer_server.cpp
  src/transport/mdns_advertiser.cpp
)
target_include_directories(transport PUBLIC src)
target_link_libraries(transport PUBLIC monitor_core ixwebsocket dnsapi)
rmm_compile_options(transport)

# The REAPER extension itself: reaper_mobile_mixer.dll, drop into UserPlugins.
add_library(reaper_mobile_mixer SHARED
  src/reaper/plugin_main.cpp
  src/reaper/reaper_project_adapter.cpp
)
target_link_libraries(reaper_mobile_mixer PRIVATE transport reaper_sdk)
rmm_compile_options(reaper_mobile_mixer)

include(CTest)
if(BUILD_TESTING)
  add_subdirectory(tests)
endif()
