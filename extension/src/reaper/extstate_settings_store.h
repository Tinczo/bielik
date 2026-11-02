#pragma once

#include "transport/mixer_service.h"

namespace rmm {

// Settings persisted in REAPER's ExtState (reaper-extstate.ini), section
// "reaper_mobile_mixer". Thin adapter, checked manually in REAPER.
class ExtStateSettingsStore : public SettingsStore {
 public:
  Settings load() const override;
  void save(const Settings& settings) override;
};

}  // namespace rmm
