#pragma once

#include "transport/mixer_service.h"

namespace rmm {

// Asks the user for the port and band password in a REAPER dialog, starting from
// `current`. Returns false if the user cancelled. Repeats the dialog until the port is
// valid. Thin adapter, checked manually in REAPER.
bool askForSettings(const Settings& current, Settings& chosen);

}  // namespace rmm
