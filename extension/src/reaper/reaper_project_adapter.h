#pragma once

#include "core/reaper_project.h"

namespace rmm {

// Real "REAPER project" port: reads the active project through the REAPER API.
// Thin by design and not covered by automated tests (checked manually in REAPER).
class ReaperProjectAdapter : public ReaperProject {
 public:
  std::vector<Track> tracks() const override;
};

}  // namespace rmm
