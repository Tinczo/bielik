#pragma once

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

// Monitors of the project, in project order.
std::vector<Monitor> monitorsOf(const ReaperProject& project);

}  // namespace rmm
