import 'dart:async';

import 'package:flutter/material.dart';

import '../protocol/messages.dart';
import 'level_curve.dart';
import 'level_format.dart';

/// One source of a monitor: its name, level in dB and a slider to set it.
///
/// While the musician drags, the new level is sent live but at most once per
/// [sendInterval]; the final value is always sent on release. A double tap
/// resets the level to 0 dB; a single tap changes nothing. While the slider is
/// held, levels pushed by the server ([source] changes) are not shown, so the
/// slider does not jump under the finger; after release it shows [source]
/// again. A disabled tile (e.g. while disconnected) only shows the level.
class SourceTile extends StatefulWidget {
  const SourceTile({
    super.key,
    required this.source,
    required this.onLevel,
    this.enabled = true,
    this.onGesture,
    this.sliderKey,
    this.highlighted = false,
    this.levelAvailable = true,
  });

  final Source source;

  /// Key of the slider; defaults to `level-<source id>`.
  final Key? sliderKey;

  /// Draws the tile as the Master: set apart from the sources.
  final bool highlighted;

  /// False when there is no level to show or set (the Master of a monitor
  /// without exactly one hardware send): the level reads "—" and the tile is
  /// disabled whatever [enabled] says.
  final bool levelAvailable;

  /// Whether the musician can change the level now.
  final bool enabled;

  /// Called with each level to send to the server.
  final ValueChanged<double> onLevel;

  /// Called once per finished gesture (a drag or a reset to 0 dB) with the
  /// level shown before it and the level it ended at. For a drag cut short by
  /// disabling the tile that is the last level sent.
  final void Function(double before, double after)? onGesture;

  /// About 25 messages per second while dragging.
  static const sendInterval = Duration(milliseconds: 40);

  @override
  State<SourceTile> createState() => _SourceTileState();
}

class _SourceTileState extends State<SourceTile> {
  double? _dragPosition;
  Timer? _throttle;
  double? _unsentLevel;

  /// Level shown when the current drag started.
  double? _levelBefore;

  /// Last level sent during the current drag; null until the slider moves.
  double? _lastSent;

  /// Changing it replaces the slider, see [_reset].
  int _sliderGeneration = 0;

  double get _level => _dragPosition == null
      ? widget.source.level
      : levelFromPosition(_dragPosition!);

  void _send(double level) {
    _lastSent = level;
    widget.onLevel(level);
  }

  void _sendThrottled(double level) {
    if (_throttle != null) {
      _unsentLevel = level;
      return;
    }
    _send(level);
    _throttle = Timer(SourceTile.sendInterval, _sendUnsent);
  }

  void _sendUnsent() {
    _throttle = null;
    final level = _unsentLevel;
    if (level == null) return;
    _unsentLevel = null;
    _sendThrottled(level);
  }

  void _sendFinal(double level) {
    _dropUnsent();
    if (level != _lastSent) widget.onLevel(level);
  }

  void _dropUnsent() {
    _throttle?.cancel();
    _throttle = null;
    _unsentLevel = null;
  }

  void _forgetDrag() {
    _dragPosition = null;
    _levelBefore = null;
    _lastSent = null;
  }

  /// The slider starts an interaction when a press outlasts [kPressTimeout],
  /// and when the double tap then wins it is never told that the interaction
  /// ended: it would stay active and the next drag would continue from the old
  /// value. A new slider starts clean.
  void _reset() {
    final before = widget.source.level;
    setState(() {
      _forgetDrag();
      _sliderGeneration++;
    });
    _sendFinal(1.0);
    widget.onGesture?.call(before, 1.0);
  }

  void _onDragEnd(double position) {
    final before = _levelBefore ?? widget.source.level;
    final after = levelFromPosition(position);
    final moved = _lastSent != null; // otherwise it was only a touch
    if (moved) _sendFinal(after);
    setState(_forgetDrag);
    if (moved) widget.onGesture?.call(before, after);
  }

  /// A drag cut short by a disconnect: nothing more can be sent, but what was
  /// sent has changed the level, so it stays one gesture to undo. Reported
  /// after the frame because this runs during build and the history rebuilds
  /// other widgets.
  void _interruptDrag() {
    final before = _levelBefore;
    final after = _lastSent;
    _dropUnsent();
    _forgetDrag();
    if (before == null || after == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onGesture?.call(before, after);
    });
  }

  @override
  void didUpdateWidget(SourceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || !widget.levelAvailable) _interruptDrag();
  }

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final enabled = widget.enabled && widget.levelAvailable;
    final tile = ListTile(
      enabled: enabled,
      title: Text(
        source.name,
        style: widget.highlighted
            ? const TextStyle(fontWeight: FontWeight.bold)
            : null,
      ),
      trailing: Text(widget.levelAvailable ? formatLevelDb(_level) : '—'),
      subtitle: GestureDetector(
        onDoubleTap: enabled ? _reset : null,
        child: KeyedSubtree(
          key: ValueKey(_sliderGeneration),
          child: Slider(
            key: widget.sliderKey ?? Key('level-${source.id}'),
            // Tapping the track must not jump the level: a press held past
            // kPressTimeout would reach REAPER before a double tap is known.
            allowedInteraction: SliderInteraction.slideOnly,
            value: _dragPosition ?? positionFromLevel(source.level),
            onChangeStart: enabled
                ? (position) {
                    _levelBefore = widget.source.level;
                    setState(() => _dragPosition = position);
                  }
                : null,
            onChanged: enabled
                ? (position) {
                    // A finger still down after a reconnect gets no start.
                    _levelBefore ??= widget.source.level;
                    setState(() => _dragPosition = position);
                    _sendThrottled(levelFromPosition(position));
                  }
                : null,
            onChangeEnd: enabled ? _onDragEnd : null,
          ),
        ),
      ),
    );
    if (!widget.highlighted) return tile;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: tile,
    );
  }
}
