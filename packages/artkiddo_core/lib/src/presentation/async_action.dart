import '../domain/app_failure.dart';

/// Presentation-level state machine for a single asynchronous command.
///
/// The transition `idle -> busy` MUST happen synchronously in the
/// controller, before the first `await` — this is the only recognized
/// double-tap guard. A command received while `busy` is ignored silently.
/// [ActionDone] is transitory: consumed once by the UI then the controller
/// resets to [ActionIdle].
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

/// Transitory: signals a just-completed success. The UI consumes it (shows
/// its effect once) then the controller must move back to [ActionIdle].
class ActionDone extends AsyncAction {
  const ActionDone();
}

class ActionError extends AsyncAction {
  final AppFailure failure;
  const ActionError(this.failure);
}
