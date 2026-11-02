#include "reaper/settings_dialog.h"

#include <string>

#include "reaper/reaper_api.h"

namespace rmm {

namespace {

constexpr const char* kTitle = "Mobile mixer settings";
// A newline cannot be typed into the fields, so it is a safe separator for the password.
constexpr const char* kCaptions = "Port,Band password (empty = none),extrawidth=120,separator=\n";

bool parsePort(const std::string& text, int& port) {
  if (text.empty() || text.size() > 5) return false;
  for (const char c : text) {
    if (c < '0' || c > '9') return false;
  }
  port = std::stoi(text);
  return port > 0 && port <= 65535;
}

}  // namespace

bool askForSettings(const Settings& current, Settings& chosen) {
  std::string values = std::to_string(current.port) + "\n" + current.password;
  for (;;) {
    char buffer[1024] = {};
    values.copy(buffer, sizeof(buffer) - 1);
    if (!GetUserInputs(kTitle, 2, kCaptions, buffer, sizeof(buffer))) return false;

    values = buffer;
    const auto separator = values.find('\n');
    const std::string portText = values.substr(0, separator);
    chosen.password = separator == std::string::npos ? "" : values.substr(separator + 1);
    if (parsePort(portText, chosen.port)) return true;
    ShowMessageBox("The port must be a number from 1 to 65535.", kTitle, 0);
  }
}

}  // namespace rmm
