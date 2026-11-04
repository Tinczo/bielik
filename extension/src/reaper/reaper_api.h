#pragma once

// The REAPER API functions this extension uses. Each one is loaded dynamically at startup
// and REAPERAPI_LoadAPI fails if any is missing (local REAPER may be older than the SDK).
// Add a REAPERAPI_WANT_<name> line here before using a new function.
#define REAPERAPI_MINIMAL
#define REAPERAPI_WANT_CountTracks
#define REAPERAPI_WANT_GetTrack
#define REAPERAPI_WANT_GetTrackGUID
#define REAPERAPI_WANT_guidToString
#define REAPERAPI_WANT_GetTrackName
#define REAPERAPI_WANT_MarkProjectDirty
#define REAPERAPI_WANT_GetTrackNumSends
#define REAPERAPI_WANT_GetSetTrackSendInfo
#define REAPERAPI_WANT_GetTrackSendInfo_Value
#define REAPERAPI_WANT_SetTrackSendUIVol
#define REAPERAPI_WANT_ShowConsoleMsg
#define REAPERAPI_WANT_EnumProjects
#define REAPERAPI_WANT_GetProjectStateChangeCount
#define REAPERAPI_WANT_ShowMessageBox
#define REAPERAPI_WANT_GetUserInputs
#define REAPERAPI_WANT_GetExtState
#define REAPERAPI_WANT_SetExtState

#include <reaper_plugin.h>
#include <reaper_plugin_functions.h>
