import 'dart:async';

abstract class SchedulerConstraint<T> {
  FutureOr<bool> isMet(T state);
  Type get storageKey => runtimeType;
}

class RouteNameConstraint extends SchedulerConstraint<String> {
  final String path;

  RouteNameConstraint({required this.path});

  @override
  FutureOr<bool> isMet(data) => data == path;
}

class TabRouteConstraint extends SchedulerConstraint {
  final String path;

  TabRouteConstraint({required this.path});

  @override
  FutureOr<bool> isMet(data) => data == path;
}

class ScreenIdleConstraint extends SchedulerConstraint<String> {
  @override
  FutureOr<bool> isMet(data) => data == 'idle';
}
