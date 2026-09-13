import 'app_failure.dart';

sealed class ActionResult<T> {
  const ActionResult();
}

class ActionSuccess<T> extends ActionResult<T> {
  final T value;
  const ActionSuccess(this.value);
}

class ActionCancelled<T> extends ActionResult<T> {
  const ActionCancelled();
}

class ActionFailed<T> extends ActionResult<T> {
  final AppFailure failure;
  const ActionFailed(this.failure);
}
