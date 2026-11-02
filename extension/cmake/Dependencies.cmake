# Third-party dependencies, pinned and fetched at configure time.
include(FetchContent)

# REAPER SDK headers (reaper_plugin.h, reaper_plugin_functions.h). Header-only on Windows.
FetchContent_Declare(reaper_sdk
  URL https://github.com/justinfrankel/reaper-sdk/archive/b2ca1ec92c9a7864fb72346037986a384971ed03.zip
)
FetchContent_MakeAvailable(reaper_sdk)
add_library(reaper_sdk INTERFACE)
target_include_directories(reaper_sdk SYSTEM INTERFACE ${reaper_sdk_SOURCE_DIR}/sdk)

# JSON (MIT).
FetchContent_Declare(nlohmann_json
  URL https://github.com/nlohmann/json/releases/download/v3.12.0/json.tar.xz
)
FetchContent_MakeAvailable(nlohmann_json)

# WebSocket server and client (BSD-3), without TLS: local network only.
set(USE_TLS OFF CACHE BOOL "" FORCE)
set(USE_ZLIB OFF CACHE BOOL "" FORCE)
FetchContent_Declare(ixwebsocket
  URL https://github.com/machinezone/IXWebSocket/archive/refs/tags/v11.4.6.tar.gz
  PATCH_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/patch_ixwebsocket.cmake
)
FetchContent_MakeAvailable(ixwebsocket)

# Test framework (MIT).
FetchContent_Declare(doctest
  URL https://github.com/doctest/doctest/archive/refs/tags/v2.4.12.tar.gz
)
FetchContent_MakeAvailable(doctest)
