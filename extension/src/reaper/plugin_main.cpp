// REAPER entry point: loads the API, starts the server with the stored settings, pumps it
// from a REAPER timer on the main thread (ADR-0001), announces it over mDNS and registers
// the settings action. Not covered by automated tests.
#define REAPERAPI_IMPLEMENT
#include "reaper/reaper_api.h"

#include <ixwebsocket/IXNetSystem.h>

#include <memory>
#include <string>

#include "reaper/extstate_settings_store.h"
#include "reaper/reaper_project_adapter.h"
#include "reaper/settings_dialog.h"
#include "transport/mdns_advertiser.h"
#include "transport/mixer_service.h"

namespace {

reaper_plugin_info_t* g_rec = nullptr;
std::unique_ptr<rmm::ReaperProjectAdapter> g_project;
std::unique_ptr<rmm::ExtStateSettingsStore> g_settingsStore;
std::unique_ptr<rmm::MixerService> g_service;
std::unique_ptr<rmm::MdnsAdvertiser> g_advertiser;

custom_action_register_t g_settingsAction = {0, "REAPER_MOBILE_MIXER_SETTINGS",
                                             "Mobile mixer: Settings (port, band password)...",
                                             nullptr};
int g_settingsCommand = 0;

void onTimer() {
  if (g_service) g_service->pump();
}

void log(const std::string& text) { ShowConsoleMsg(("[reaper_mobile_mixer] " + text + "\n").c_str()); }

void announce(int port) {
  std::string error;
  if (!g_advertiser->announce(port, &error)) {
    log("cannot announce on the network (enter the address in Bielik by hand): " + error);
  }
}

void openSettings() {
  const rmm::Settings current = g_service->settings();
  rmm::Settings chosen;
  if (!rmm::askForSettings(current, chosen)) return;
  std::string error;
  if (!g_service->applySettings(chosen, &error)) {
    const std::string text = "Cannot listen on port " + std::to_string(chosen.port) + ": " + error +
                             "\n\nThe settings were not changed.";
    ShowMessageBox(text.c_str(), "Mobile mixer settings", 0);
    return;
  }
  announce(chosen.port);  // replaces the announcement of the old port
}

bool onAction(KbdSectionInfo*, int command, int, int, int, HWND) {
  if (command == 0 || command != g_settingsCommand) return false;
  openSettings();
  return true;
}

void shutdown() {
  if (g_rec) {
    g_rec->Register("-timer", reinterpret_cast<void*>(&onTimer));
    g_rec->Register("-hookcommand2", reinterpret_cast<void*>(&onAction));
    g_rec->Register("-custom_action", &g_settingsAction);
  }
  g_advertiser.reset();  // withdraws the mDNS announcement
  if (g_service) g_service->stop();
  g_service.reset();
  g_settingsStore.reset();
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
  g_settingsStore = std::make_unique<rmm::ExtStateSettingsStore>();
  g_service = std::make_unique<rmm::MixerService>(*g_project, *g_settingsStore);
  g_advertiser = std::make_unique<rmm::MdnsAdvertiser>();
  std::string error;
  if (g_service->start(&error)) {
    announce(g_service->settings().port);
  } else {
    // Stay loaded: the settings action can pick another port (and announces it).
    log("cannot listen on port " + std::to_string(g_service->settings().port) + ": " + error +
        " (change it with the action \"Mobile mixer: Settings\")");
  }
  g_settingsCommand = rec->Register("custom_action", &g_settingsAction);
  rec->Register("hookcommand2", reinterpret_cast<void*>(&onAction));
  rec->Register("timer", reinterpret_cast<void*>(&onTimer));
  return 1;
}
