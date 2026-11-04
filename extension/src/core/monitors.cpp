#include "core/monitors.h"

#include <set>

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
    for (const std::string_view prefix : kMonitorPrefixes) {
      if (name.substr(0, prefix.size()) != prefix) continue;
      monitors.push_back({track.guid, std::string(trim(name.substr(prefix.size())))});
      break;
    }
  }
  return monitors;
}

std::optional<MonitorState> monitorState(const ReaperProject& project, std::string_view monitorId) {
  std::optional<MonitorState> state;
  for (Monitor& monitor : monitorsOf(project)) {
    if (monitor.id == monitorId) {
      state = MonitorState{std::move(monitor), {}};
      break;
    }
  }
  if (!state) return std::nullopt;

  const std::vector<Track> tracks = project.tracks();
  std::set<std::string> seen;
  for (const Receive& receive : project.receives(state->monitor.id)) {
    if (!seen.insert(receive.sourceGuid).second) continue;
    for (const Track& track : tracks) {
      if (track.guid == receive.sourceGuid) {
        state->sources.push_back({track.guid, track.name, receive.level});
        break;
      }
    }
  }
  return state;
}

}  // namespace rmm
