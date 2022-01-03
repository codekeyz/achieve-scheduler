import 'dart:io';

import 'package:achieve_scheduler/achieve_scheduler.dart';

enum SchedulerState { idle, busy }

typedef SchedulerCallback = Function(
  Scheduler scheduler,
  ScheduledTask task,
);

/// Exception thrown by some operations of [Scheduler]
class SchedulerException implements IOException {
  /// Message describing cause of the exception.
  final String message;

  const SchedulerException(this.message);

  String toString() {
    return "SchedulerException: $message";
  }
}
