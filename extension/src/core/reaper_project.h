#pragma once

#include <string>
#include <vector>

namespace rmm {

struct Track {
  std::string guid;  // REAPER track GUID, e.g. "{1B6A2C10-...}"
  std::string name;  // UTF-8, as typed in REAPER
};

// Port "REAPER project": the only way the monitors core sees the active project.
// Implemented by the real REAPER API adapter and by an in-memory fake in tests.
// Called on the main thread only.
class ReaperProject {
 public:
  virtual ~ReaperProject() = default;

  // All tracks of the active project, in project order.
  virtual std::vector<Track> tracks() const = 0;
};

}  // namespace rmm
