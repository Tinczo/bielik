import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the phone's screen from turning off.
abstract interface class ScreenWakeLock {
  Future<void> keepOn(bool on);
}

/// The phone's real wake lock.
class WakelockPlusScreenWakeLock implements ScreenWakeLock {
  const WakelockPlusScreenWakeLock();

  @override
  Future<void> keepOn(bool on) => WakelockPlus.toggle(enable: on);
}

/// Keeps the screen on while [child] is shown, so the musician can fix a
/// level between songs without unlocking the phone.
class KeepScreenOn extends StatefulWidget {
  const KeepScreenOn({super.key, required this.wakeLock, required this.child});

  final ScreenWakeLock wakeLock;
  final Widget child;

  @override
  State<KeepScreenOn> createState() => _KeepScreenOnState();
}

class _KeepScreenOnState extends State<KeepScreenOn> {
  @override
  void initState() {
    super.initState();
    _keepOn(true);
  }

  @override
  void dispose() {
    _keepOn(false);
    super.dispose();
  }

  Future<void> _keepOn(bool on) async {
    try {
      await widget.wakeLock.keepOn(on);
    } catch (_) {
      // The screen may turn off; nothing else breaks.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
