#include "reaper/extstate_settings_store.h"

#include <cstdlib>
#include <string>

#include "reaper/reaper_api.h"

namespace rmm {

namespace {

constexpr const char* kSection = "reaper_mobile_mixer";
constexpr const char* kPortKey = "port";
constexpr const char* kPasswordKey = "password";

}  // namespace

Settings ExtStateSettingsStore::load() const {
  Settings settings;
  const char* port = GetExtState(kSection, kPortKey);
  const int parsed = port ? std::atoi(port) : 0;
  if (parsed > 0 && parsed <= 65535) settings.port = parsed;
  const char* password = GetExtState(kSection, kPasswordKey);
  if (password) settings.password = password;
  return settings;
}

void ExtStateSettingsStore::save(const Settings& settings) {
  SetExtState(kSection, kPortKey, std::to_string(settings.port).c_str(), /*persist=*/true);
  SetExtState(kSection, kPasswordKey, settings.password.c_str(), /*persist=*/true);
}

}  // namespace rmm
