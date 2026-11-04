import 'package:flutter/widgets.dart';

/// One gesture of the musician on one source: its level before and after.
class LevelStep {
  const LevelStep({
    required this.sourceId,
    required this.before,
    required this.after,
  });

  final String sourceId;
  final double before;
  final double after;
}

/// Undo and redo of the musician's own level changes in one monitor.
///
/// Only gestures made on this phone are recorded; levels pushed by the server
/// never are. Steps for sources the monitor no longer has are skipped (and
/// dropped) by [undo] and [redo].
class LevelHistory extends ChangeNotifier {
  /// Oldest steps are forgotten beyond this.
  static const maxSteps = 50;

  final List<LevelStep> _undo = [];
  final List<LevelStep> _redo = [];

  /// Records a finished gesture; clears the steps to redo.
  void record(LevelStep step) {
    if (step.before == step.after) return;
    _undo.add(step);
    if (_undo.length > maxSteps) _undo.removeAt(0);
    _redo.clear();
    notifyListeners();
  }

  /// Whether [undo] would return a step, given which sources still [exist].
  bool canUndo(bool Function(String sourceId) exist) =>
      _undo.any((step) => exist(step.sourceId));

  /// Whether [redo] would return a step, given which sources still [exist].
  bool canRedo(bool Function(String sourceId) exist) =>
      _redo.any((step) => exist(step.sourceId));

  /// The latest step whose source still [exist]s, moved to the redo stack;
  /// the caller sets its source back to [LevelStep.before].
  LevelStep? undo(bool Function(String sourceId) exist) =>
      _move(_undo, _redo, exist);

  /// The latest undone step whose source still [exist]s, moved back to the
  /// undo stack; the caller sets its source to [LevelStep.after].
  LevelStep? redo(bool Function(String sourceId) exist) =>
      _move(_redo, _undo, exist);

  LevelStep? _move(
    List<LevelStep> from,
    List<LevelStep> to,
    bool Function(String sourceId) exist,
  ) {
    LevelStep? found;
    while (from.isNotEmpty && found == null) {
      final step = from.removeLast();
      if (exist(step.sourceId)) found = step;
    }
    if (found != null) to.add(found);
    notifyListeners();
    return found;
  }
}

/// The [LevelHistory] of every monitor, kept for as long as the app runs:
/// across reconnects and switching between monitors.
class LevelHistories {
  final Map<String, LevelHistory> _byMonitor = {};

  LevelHistory of(String monitorId) =>
      _byMonitor.putIfAbsent(monitorId, LevelHistory.new);
}

/// Makes the app's [LevelHistories] available below it.
class LevelHistoryScope extends InheritedWidget {
  const LevelHistoryScope({
    super.key,
    required this.histories,
    required super.child,
  });

  final LevelHistories histories;

  static LevelHistories of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LevelHistoryScope>()!
      .histories;

  @override
  bool updateShouldNotify(LevelHistoryScope oldWidget) =>
      histories != oldWidget.histories;
}
