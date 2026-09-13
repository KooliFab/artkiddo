import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../async_action.dart';
import '../../local/logging/log.dart';
import '../../domain/action_result.dart';
import 'children_providers.dart';

enum ChildEditorOrigin { galleryEmpty, childrenList, captureDraft }

class ChildEditorArgs {
  final String? childId; // null = create
  final ChildEditorOrigin origin;

  const ChildEditorArgs({this.childId, required this.origin});
}

enum ChildFieldError {
  nameEmpty,
  nameTooLong,
  nameDuplicate,
  birthDateMissing,
  birthDateFuture,
  birthDateTooOld,
}

class ChildEditorState {
  final String name;
  final DateTime? birthDate; // null until chosen — never prefilled on create
  final Set<ChildFieldError> errors;
  final bool isDirty;
  final bool attemptedSubmit;
  final AsyncAction save;
  final bool loading;

  const ChildEditorState({
    this.name = '',
    this.birthDate,
    this.errors = const {},
    this.isDirty = false,
    this.attemptedSubmit = false,
    this.save = const ActionIdle(),
    this.loading = false,
  });

  ChildEditorState copyWith({
    String? name,
    DateTime? birthDate,
    bool clearBirthDate = false,
    Set<ChildFieldError>? errors,
    bool? isDirty,
    bool? attemptedSubmit,
    AsyncAction? save,
    bool? loading,
  }) {
    return ChildEditorState(
      name: name ?? this.name,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      errors: errors ?? this.errors,
      isDirty: isDirty ?? this.isDirty,
      attemptedSubmit: attemptedSubmit ?? this.attemptedSubmit,
      save: save ?? this.save,
      loading: loading ?? this.loading,
    );
  }

  bool get hasBlockingErrors =>
      errors.any((e) => e != ChildFieldError.nameDuplicate);
}

class ChildEditorController extends Notifier<ChildEditorState> {
  ChildEditorController(this.args);

  final ChildEditorArgs args;

  DateTime? _originalBirthDate;
  String _originalName = '';

  @override
  ChildEditorState build() {
    if (args.childId != null) {
      _loadExisting(args.childId!);
      return const ChildEditorState(loading: true);
    }
    return const ChildEditorState();
  }

  Future<void> _loadExisting(String id) async {
    final repo = ref.read(childrenRepositoryProvider);
    final child = await repo.getById(id);
    if (child == null) {
      Log.w('Enfant introuvable lors du chargement ($id)', 'Children');
      return;
    }
    Log.d('Édition de l’enfant chargée ($id)', 'Children');
    _originalName = child.name;
    _originalBirthDate = child.birthDate;
    state = state.copyWith(
      name: child.name,
      birthDate: child.birthDate,
      loading: false,
    );
  }

  void updateName(String name) {
    final isDirty = args.childId == null
        ? name.trim().isNotEmpty
        : name != _originalName;
    state = state.copyWith(
      name: name,
      isDirty: isDirty || _dirtyFromBirthDate(),
      errors: state.attemptedSubmit
          ? _validate(name: name).errors
          : state.errors,
    );
  }

  void updateBirthDate(DateTime date) {
    final isDirty = args.childId == null ? true : date != _originalBirthDate;
    state = state.copyWith(
      birthDate: date,
      isDirty: isDirty || _dirtyFromName(),
      errors: state.attemptedSubmit
          ? _validate(birthDate: date).errors
          : state.errors,
    );
  }

  bool _dirtyFromName() => args.childId == null
      ? state.name.trim().isNotEmpty
      : state.name != _originalName;
  bool _dirtyFromBirthDate() => args.childId == null
      ? state.birthDate != null
      : state.birthDate != _originalBirthDate;

  ({Set<ChildFieldError> errors}) _validate({
    String? name,
    DateTime? birthDate,
  }) {
    final n = (name ?? state.name).trim();
    final bd = birthDate ?? state.birthDate;
    final errors = <ChildFieldError>{};

    if (n.isEmpty) errors.add(ChildFieldError.nameEmpty);
    if (n.length > 40) errors.add(ChildFieldError.nameTooLong);
    if (bd == null) {
      errors.add(ChildFieldError.birthDateMissing);
    } else {
      final now = DateTime.now();
      if (bd.isAfter(now)) errors.add(ChildFieldError.birthDateFuture);
      final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
      if (bd.isBefore(eighteenYearsAgo)) {
        errors.add(ChildFieldError.birthDateTooOld);
      }
    }

    final duplicate = _duplicateName(n);
    if (duplicate) errors.add(ChildFieldError.nameDuplicate);

    return (errors: errors);
  }

  bool _duplicateName(String name) {
    if (name.isEmpty) return false;
    final children = ref.read(allChildrenStreamProvider).value ?? const [];
    final normalized = _normalize(name);
    return children.any(
      (c) => c.id != args.childId && _normalize(c.name) == normalized,
    );
  }

  String _normalize(String s) => s.trim().toLowerCase();

  Future<ActionResult<String>> save() async {
    if (state.save.isBusy) return const ActionCancelled();

    final validated = _validate();
    state = state.copyWith(attemptedSubmit: true, errors: validated.errors);
    if (validated.errors.any((e) => e != ChildFieldError.nameDuplicate)) {
      Log.w('Enregistrement d’enfant bloqué par la validation', 'Children');
      return const ActionCancelled();
    }

    state = state.copyWith(save: const ActionBusy());
    final repo = ref.read(childrenRepositoryProvider);
    final name = state.name.trim();
    final birthDate = state.birthDate!;

    final ActionResult<String> result;
    if (args.childId == null) {
      result = await repo.create(name: name, birthDate: birthDate);
    } else {
      final updateResult = await repo.update(
        id: args.childId!,
        name: name,
        birthDate: birthDate,
      );
      result = switch (updateResult) {
        ActionSuccess() => ActionSuccess(args.childId!),
        ActionCancelled() => const ActionCancelled(),
        ActionFailed(failure: final f) => ActionFailed(f),
      };
    }

    switch (result) {
      case ActionSuccess():
        Log.i(
          '${args.childId == null ? 'Création' : 'Mise à jour'} de l’enfant réussie',
          'Children',
        );
        state = state.copyWith(save: const ActionDone());
        try {
          await HapticFeedback.lightImpact();
        } catch (e, st) {
          Log.w('Retour haptique indisponible : $e', 'Children');
          Log.d(st.toString(), 'Children');
        }
      case ActionFailed(failure: final f):
        Log.w('Enregistrement d’enfant refusé : ${f.runtimeType}', 'Children');
        state = state.copyWith(save: ActionError(f));
      case ActionCancelled():
        state = state.copyWith(save: const ActionIdle());
    }
    return result;
  }
}

final childEditorControllerProvider =
    NotifierProvider.family<
      ChildEditorController,
      ChildEditorState,
      ChildEditorArgs
    >(ChildEditorController.new);
