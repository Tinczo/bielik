#pragma once

#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "core/reaper_project.h"

namespace rmm {

// A track becomes a monitor ("Odsłuch") when its name starts with one of these prefixes.
// The one without the Polish letter exists because typing "ł" can trigger a REAPER shortcut.
inline constexpr std::string_view kMonitorPrefixes[] = {"Odsłuch:", "Odsluch:"};

struct Monitor {
  std::string id;    // track GUID
  std::string name;  // track name without the prefix, trimmed

  friend bool operator==(const Monitor& a, const Monitor& b) {
    return a.id == b.id && a.name == b.name;
  }
  friend bool operator!=(const Monitor& a, const Monitor& b) { return !(a == b); }
};

// A source of a monitor ("Źródło"): the track one of the monitor's receives comes from.
struct Source {
  std::string id;    // source track GUID
  std::string name;  // source track name
  double level;      // receive volume, linear: 1.0 = 0 dB, 0 = -inf
};

// A monitor's master ("Master"): the volume of its hardware send. Properly set up monitors
// have exactly one hardware send.
struct Output {
  enum class Status { Ok, Missing, Multiple };
  Status status = Status::Missing;
  double level = 1.0;  // only meaningful when status is Ok; linear: 1.0 = 0 dB, 0 = -inf
};

struct MonitorState {
  Monitor monitor;
  Output output;
  std::vector<Source> sources;  // in receive order
};

// The master of the monitor with this GUID, from its hardware sends.
Output outputOf(const ReaperProject& project, std::string_view monitorId);

// Monitors of the project, in project order.
std::vector<Monitor> monitorsOf(const ReaperProject& project);

// Full state of the monitor with this GUID, or nothing if no such monitor exists.
// When several receives come from the same source track, only the first one counts.
std::optional<MonitorState> monitorState(const ReaperProject& project, std::string_view monitorId);

}  // namespace rmm
