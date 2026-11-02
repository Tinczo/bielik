# PATCH_COMMAND for IXWebSocket, run in its source directory.
# On Windows, SO_REUSEADDR lets a server bind a port another program already listens on,
# so a taken port would go unnoticed. Use SO_EXCLUSIVEADDRUSE there instead, so listen()
# fails on a taken port and nothing can take ours.
set(file "ixwebsocket/IXSocketServer.cpp")
file(READ "${file}" content)
set(old "setsockopt(_serverFd, SOL_SOCKET, SO_REUSEADDR,")
set(new "setsockopt(_serverFd, SOL_SOCKET, RMM_SERVER_SOCKET_OPTION,")
string(FIND "${content}" "${old}" found)
if(found EQUAL -1)
  string(FIND "${content}" "RMM_SERVER_SOCKET_OPTION" patched)
  if(patched EQUAL -1)
    message(FATAL_ERROR "patch_ixwebsocket: setsockopt(SO_REUSEADDR) not found in ${file}")
  endif()
  return()  # already patched
endif()
string(REPLACE "${old}" "${new}" content "${content}")
set(define "#ifdef _WIN32\n#define RMM_SERVER_SOCKET_OPTION SO_EXCLUSIVEADDRUSE\n#else\n#define RMM_SERVER_SOCKET_OPTION SO_REUSEADDR\n#endif\n")
string(PREPEND content "${define}")
file(WRITE "${file}" "${content}")
