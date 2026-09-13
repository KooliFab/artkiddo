import '../domain/app_failure.dart';

sealed class AsyncAction {
  const AsyncAction();

  bool get isBusy => this is ActionBusy;
  bool get isIdle => this is ActionIdle;
}

class ActionIdle extends AsyncAction {
  const ActionIdle();
}

class ActionBusy extends AsyncAction {
  final String? progressLabel;
  const ActionBusy([this.progressLabel]);
}

class ActionDone extends AsyncAction {
  const ActionDone();
}

class ActionError extends AsyncAction {
  final AppFailure failure;
  const ActionError(this.failure);
}
