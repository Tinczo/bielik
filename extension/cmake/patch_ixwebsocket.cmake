# PATCH_COMMAND for IXWebSocket, run in its source directory. Safe to run twice.

# Applies one edit to a file; `marker` tells it was already applied.
function(patch_file file old new marker)
  file(READ "${file}" content)
  string(FIND "${content}" "${marker}" patched)
  if(NOT patched EQUAL -1)
    return()
  endif()
  string(FIND "${content}" "${old}" found)
  if(found EQUAL -1)
    message(FATAL_ERROR "patch_ixwebsocket: '${old}' not found in ${file}")
  endif()
  string(REPLACE "${old}" "${new}" content "${content}")
  file(WRITE "${file}" "${content}")
endfunction()

# On Windows, SO_REUSEADDR lets a server bind a port another program already listens on,
# so a taken port would go unnoticed. Use SO_EXCLUSIVEADDRUSE there instead, so listen()
# fails on a taken port and nothing can take ours.
patch_file("ixwebsocket/IXSocketServer.cpp"
  "setsockopt(_serverFd, SOL_SOCKET, SO_REUSEADDR,"
  "setsockopt(_serverFd, SOL_SOCKET, RMM_SERVER_SOCKET_OPTION,"
  "RMM_SERVER_SOCKET_OPTION")
file(READ "ixwebsocket/IXSocketServer.cpp" content)
string(FIND "${content}" "#define RMM_SERVER_SOCKET_OPTION" defined)
if(defined EQUAL -1)
  string(PREPEND content "#ifdef _WIN32\n#define RMM_SERVER_SOCKET_OPTION SO_EXCLUSIVEADDRUSE\n#else\n#define RMM_SERVER_SOCKET_OPTION SO_REUSEADDR\n#endif\n")
  file(WRITE "ixwebsocket/IXSocketServer.cpp" "${content}")
endif()

# poll() closes the socket on a poll error or a close request but leaves the state alone.
# A close that lands around the end of the handshake leaves the state OPEN, so run() then
# polls a closed socket forever on full CPU and WebSocketServer::stop() never returns.
# Report it as an abnormal close, which makes dispatch() switch to CLOSED.
patch_file("ixwebsocket/IXWebSocketTransport.cpp"
  "if (_readyState == ReadyState::CLOSING && closingDelayExceeded())"
  "if (_readyState == ReadyState::OPEN && (pollResult == PollResultType::Error || pollResult == PollResultType::CloseRequest)) return PollResult::AbnormalClose; // RMM_POLL_FIX\n        if (_readyState == ReadyState::CLOSING && closingDelayExceeded())"
  "RMM_POLL_FIX")
