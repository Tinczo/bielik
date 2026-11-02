#include "core/monitors.h"

namespace rmm {

namespace {

std::string_view trim(std::string_view text) {
  constexpr std::string_view kWhitespace = " \t\r\n";
  const auto begin = text.find_first_not_of(kWhitespace);
  if (begin == std::string_view::npos) return {};
  const auto end = text.find_last_not_of(kWhitespace);
  return text.substr(begin, end - begin + 1);
}

}  // namespace

std::vector<Monitor> monitorsOf(const ReaperProject& project) {
  std::vector<Monitor> monitors;
  for (const Track& track : project.tracks()) {
    const std::string_view name = track.name;
    if (name.substr(0, kMonitorPrefix.size()) != kMonitorPrefix) continue;
    monitors.push_back({track.guid, std::string(trim(name.substr(kMonitorPrefix.size())))});
  }
  return monitors;
}

}  // namespace rmm
