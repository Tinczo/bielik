// REAPER entry point: loads the API, starts the server and pumps it from a REAPER timer
// on the main thread (ADR-0001). Not covered by automated tests.
#define REAPERAPI_IMPLEMENT
#include "reaper/reaper_api.h"

#include <ixwebsocket/IXNetSystem.h>

#include <memory>
#include <string>

#include "reaper/reaper_project_adapter.h"
#include "transport/mdns_advertiser.h"
#include "transport/mixer_server.h"

namespace {

reaper_plugin_info_t* g_rec = nullptr;
std::unique_ptr<rmm::ReaperProjectAdapter> g_project;
std::unique_ptr<rmm::MixerServer> g_server;
std::unique_ptr<rmm::MdnsAdvertiser> g_advertiser;

void onTimer() {
  if (g_server) g_server->pump();
}

void log(const std::string& text) { ShowConsoleMsg(("[reaper_mobile_mixer] " + text + "\n").c_str()); }

void shutdown() {
  if (g_rec) g_rec->Register("-timer", reinterpret_cast<void*>(&onTimer));
  g_advertiser.reset();  // withdraws the mDNS announcement
  if (g_server) g_server->stop();
  g_server.reset();
  g_project.reset();
  ix::uninitNetSystem();
  g_rec = nullptr;
}

}  // namespace

extern "C" REAPER_PLUGIN_DLL_EXPORT int REAPER_PLUGIN_ENTRYPOINT(REAPER_PLUGIN_HINSTANCE,
                                                                  reaper_plugin_info_t* rec) {
  if (!rec) {  // unloading
    shutdown();
    return 0;
  }
  if (rec->caller_version != REAPER_PLUGIN_VERSION || !rec->GetFunc) return 0;
  if (REAPERAPI_LoadAPI(rec->GetFunc) != 0) return 0;  // a required API function is missing

  g_rec = rec;
  ix::initNetSystem();
  g_project = std::make_unique<rmm::ReaperProjectAdapter>();
  g_server = std::make_unique<rmm::MixerServer>(*g_project, rmm::kDefaultPort);
  std::string error;
  if (!g_server->start(&error)) {
    log("cannot listen on port " + std::to_string(rmm::kDefaultPort) + ": " + error);
    g_server.reset();
    return 1;  // stay loaded; nothing to serve
  }
  g_advertiser = std::make_unique<rmm::MdnsAdvertiser>();
  if (!g_advertiser->announce(rmm::kDefaultPort, &error)) {
    log("cannot announce on the network (enter the address in Bielik by hand): " + error);
  }
  rec->Register("timer", reinterpret_cast<void*>(&onTimer));
  return 1;
}
