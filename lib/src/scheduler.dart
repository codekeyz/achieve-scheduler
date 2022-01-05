import 'dart:async';

import 'package:scheduler/src/common.dart';
import 'package:scheduler/src/constraints.dart';

/// A scheduler that runs based on matched constraints.
abstract class Scheduler {
  bool get isBusy;

  void onConstraintStateChanged(Type constraint, dynamic state);

  ScheduledTask scheduleTask(
    String id,
    List<SchedulerConstraint> constraints,
  );

  void taskCompleted(ScheduledTask task);

  void addListener(SchedulerCallback callback);

  void removeListener(SchedulerCallback callback);

  void clear();
}

class SchedulerImpl implements Scheduler {
  SchedulerImpl({
    required this.delayBetweenTasks,
  });

  final Duration delayBetweenTasks;

  ScheduledTask? runningTask;

  Timer? _eventsDelayer, _tasksDelayer;

  bool get isBusy => runningTask != null;

  final List<SchedulerCallback> listeners = [];

  final List<ScheduledTask> taskList = [];
  final _ConstraintStateStore constraintStateStore = _ConstraintStateStore();

  ScheduledTask scheduleTask(
    String id,
    List<SchedulerConstraint> constraints,
  ) {
    final task = _ScheduledTask(
      id,
      constraints,
    );
    removeTask(task);
    addTask(task);
    checkAndDispatchAnyTask();
    return task;
  }

  void addTask(ScheduledTask task) {
    taskList.add(task);
  }

  void removeTask(ScheduledTask task) {
    taskList.removeWhere((_task) => _task.id == task.id);
  }

  /// We use the [_eventsDelayer] in here
  /// so that we can have stable data to work with
  ///
  /// A typical case is Navigation Events.
  /// we want the navigator to settle before we proceed
  /// with [checkAndDispatchAnyTask]
  @override
  void onConstraintStateChanged(Type constraint, dynamic state) async {
    constraintStateStore.setState(constraint, state);

    if (_eventsDelayer?.isActive ?? false) {
      _eventsDelayer!.cancel();
    }

    _eventsDelayer = Timer(
      const Duration(milliseconds: 200),
      () => checkAndDispatchAnyTask(),
    );
  }

  /// This method is called anytime there is a change
  /// in [constraintStateStore] data.
  /// or when [taskCompleted] is called.
  ///
  /// Hence we need a timer, that times for 2 seconds
  /// if this method is called while [isBusy] is false,
  /// it resets the timer.
  ///
  /// That means matching will be done with new data.
  void checkAndDispatchAnyTask() async {
    if (isBusy) return;

    if (_tasksDelayer?.isActive ?? false) {
      _tasksDelayer!.cancel();
    }

    _tasksDelayer = Timer(
      const Duration(seconds: 2),
      () async {
        ScheduledTask? _matchedTask;

        for (final task in taskList) {
          if (!task.isActive) taskList.remove(task);
          if (await task.constraintsMet(constraintStateStore)) {
            _matchedTask = task;
            break;
          }
        }

        if (_matchedTask == null) return;

        runningTask = _matchedTask;

        for (final listener in listeners) {
          listener(this, _matchedTask);
        }
      },
    );
  }

  @override
  void taskCompleted(ScheduledTask task) async {
    removeTask(task);

    if (runningTask?.id == task.id) {
      runningTask = null;

      /// proceed with matching
      checkAndDispatchAnyTask();
    }
  }

  @override
  void addListener(SchedulerCallback callback) {
    removeListener(callback);
    listeners.add(callback);
  }

  @override
  void removeListener(SchedulerCallback callback) {
    listeners.remove(callback);
  }

  @override
  void clear() {
    _tasksDelayer?.cancel();
    _tasksDelayer?.cancel();
    constraintStateStore.flush();
    listeners.clear();
    taskList.clear();
  }
}

class _ConstraintStateStore {
  final Map<Type, dynamic> _store = {};

  void setState(Type constraint, dynamic state) {
    _store[constraint] = state;
  }

  flush() {
    _store.clear();
  }

  T getState<T>(Type type) {
    return _store[type] as T;
  }
}

abstract class ScheduledTask {
  String get id;

  bool get isActive;

  Future<bool> constraintsMet(_ConstraintStateStore constraintStateStore);

  void cancel();
}

class _ScheduledTask implements ScheduledTask {
  _ScheduledTask(
    id,
    this.constraints,
  ) : _id = id;

  late String _id;

  String get id => _id;
  final List<SchedulerConstraint> constraints;

  bool _isActive = true;

  bool get isActive => _isActive;

  void cancel() async {
    _isActive = false;
  }

  Future<bool> constraintsMet(_ConstraintStateStore constraintStateStore) async {
    if (!isActive) return false;

    final tests = await Future.wait(constraints.map(
      (constraint) async {
        final state = constraintStateStore.getState(constraint.storageKey);
        if (state == null) return false;

        return await constraint.isMet(state);
      },
    ));

    return tests.every((test) => test);
  }
}
