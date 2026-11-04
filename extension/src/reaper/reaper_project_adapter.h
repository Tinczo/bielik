#pragma once

#include <memory>

#include "core/reaper_project.h"

class IReaperControlSurface;
class ReaProject;

namespace rmm {

// Real "REAPER project" port: reads the active project through the REAPER API.
// Thin by design and not covered by automated tests (checked manually in REAPER).
//
// Change detection: a hidden control surface marks the project dirty when REAPER reports
// a track list change, a track rename or a send/receive volume change; poll() (REAPER
// timer, main thread) then notifies the change listener once. As a safety net poll() also
// notifies when GetProjectStateChangeCount or the active project differs from last time.
class ReaperProjectAdapter : public ReaperProject {
 public:
  ReaperProjectAdapter();
  ~ReaperProjectAdapter() override;

  std::vector<Track> tracks() const override;
  std::vector<Receive> receives(const std::string& trackGuid) const override;
  bool setReceiveLevel(const std::string& trackGuid, const std::string& sourceGuid,
                       double level) override;

  // Register with rec->Register("csurf_inst", ...) and unregister ("-csurf_inst") before
  // the adapter is destroyed.
  IReaperControlSurface* controlSurface();

  // Main thread, every timer tick: notifies the change listener at most once.
  void poll();

  // Called by the control surface.
  void markDirty() { dirty_ = true; }

 private:
  class ChangeSurface;

  std::unique_ptr<ChangeSurface> surface_;
  bool dirty_ = false;
  ReaProject* lastProject_ = nullptr;
  int lastStateCount_ = -1;
};

}  // namespace rmm
