#pragma once

#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "core/reaper_project.h"

namespace rmm {

// A track becomes a monitor ("Odsłuch") when its name starts with this prefix.
inline constexpr std::string_view kMonitorPrefix = "Odsłuch:";

struct Monitor {
  std::string id;    // track GUID
  std::string name;  // track name without the prefix, trimmed
};

// A source of a monitor ("Źródło"): the track one of the monitor's receives comes from.
struct Source {
  std::string id;    // source track GUID
  std::string name;  // source track name
  double level;      // receive volume, linear: 1.0 = 0 dB, 0 = -inf
};

struct MonitorState {
  Monitor monitor;
  std::vector<Source> sources;  // in receive order
};

// Monitors of the project, in project order.
std::vector<Monitor> monitorsOf(const ReaperProject& project);

// Full state of the monitor with this GUID, or nothing if no such monitor exists.
// When several receives come from the same source track, only the first one counts.
std::optional<MonitorState> monitorState(const ReaperProject& project, std::string_view monitorId);

}  // namespace rmm
