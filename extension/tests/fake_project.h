#pragma once

#include <vector>

#include "core/reaper_project.h"

namespace rmm::testing {

// In-memory REAPER project. Tests edit `trackList` directly.
class FakeProject : public ReaperProject {
 public:
  std::vector<Track> trackList;

  std::vector<Track> tracks() const override { return trackList; }
};

}  // namespace rmm::testing
