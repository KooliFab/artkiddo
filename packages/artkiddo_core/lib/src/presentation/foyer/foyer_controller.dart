import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/household.dart';
import '../../domain/app_failure.dart';
import '../../local/logging/log.dart';
import '../async_action.dart';

export '../../contracts/household.dart'
    show
        FamilyInfo,
        FoyerApi,
        FoyerMemberRole,
        FoyerMembership,
        RedeemOutcome,
        RedeemState;

/// Provider for [FoyerApi], defaulting to [NoFoyerApi].
/// Compositions enabling [AppCapabilities.household] must override this provider.
final foyerApiProvider = Provider<FoyerApi>((ref) {
  return const NoFoyerApi();
});

/// Callback executed after a confirmed foyer redeem to converge data.
/// Defaults to a no-op in local compositions; overridden in cloud compositions.
final foyerConvergenceProvider = Provider<Future<void> Function()>((ref) {
  return () async {};
});

class FoyerState {
  final AsyncAction family;
  final FamilyInfo? familyInfo;

  final AsyncAction rename;

  final AsyncAction redeem;
  final RedeemOutcome? redeemOutcome;

  final AsyncAction convergence;

  const FoyerState({
    this.family = const ActionIdle(),
    this.familyInfo,
    this.rename = const ActionIdle(),
    this.redeem = const ActionIdle(),
    this.redeemOutcome,
    this.convergence = const ActionIdle(),
  });

  FoyerState copyWith({
    AsyncAction? family,
    FamilyInfo? familyInfo,
    AsyncAction? rename,
    AsyncAction? redeem,
    RedeemOutcome? redeemOutcome,
    AsyncAction? convergence,
  }) {
    return FoyerState(
      family: family ?? this.family,
      familyInfo: familyInfo ?? this.familyInfo,
      rename: rename ?? this.rename,
      redeem: redeem ?? this.redeem,
      redeemOutcome: redeemOutcome ?? this.redeemOutcome,
      convergence: convergence ?? this.convergence,
    );
  }
}

class FoyerController extends Notifier<FoyerState> {
  @override
  FoyerState build() => const FoyerState();

  Future<void> loadFamilyInfo() async {
    if (state.family.isBusy) return;
    state = state.copyWith(family: const ActionBusy());
    try {
      final info = await ref.read(foyerApiProvider).getFamilyInfo();
      Log.i('Family loaded: ${info.foyerId}', 'Foyer');
      state = state.copyWith(family: const ActionDone(), familyInfo: info);
    } catch (e, st) {
      Log.e('Failed to load family info', e, st, 'Foyer');
      state = state.copyWith(
        family: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }

  Future<void> renameFamily(String name) async {
    if (state.rename.isBusy) return;
    state = state.copyWith(rename: const ActionBusy());
    try {
      await ref.read(foyerApiProvider).renameFamily(name);
      Log.i('Family renamed', 'Foyer');
      final current = state.familyInfo;
      state = state.copyWith(
        rename: const ActionDone(),
        familyInfo: current == null
            ? null
            : FamilyInfo(
                foyerId: current.foyerId,
                name: name,
                code: current.code,
                role: current.role,
              ),
      );
    } catch (e, st) {
      Log.e('Failed to rename family', e, st, 'Foyer');
      state = state.copyWith(
        rename: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }

  Future<void> redeem(String code) async {
    if (state.redeem.isBusy) return;
    state = state.copyWith(
      redeem: const ActionBusy(),
      convergence: const ActionIdle(),
    );
    try {
      final outcome = await ref.read(foyerApiProvider).redeemInvite(code: code);
      Log.i('Invite processed: ${outcome.state.name}', 'Foyer');
      state = state.copyWith(
        redeem: const ActionDone(),
        redeemOutcome: outcome,
      );
      if (outcome.state == RedeemState.ok) {
        await _joinOrRestore();
      }
    } catch (e, st) {
      Log.e('Failed to redeem invite', e, st, 'Foyer');
      state = state.copyWith(
        redeem: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }

  Future<void> _joinOrRestore() async {
    state = state.copyWith(convergence: const ActionBusy());
    try {
      final converge = ref.read(foyerConvergenceProvider);
      await converge();
      Log.i('Foyer convergence completed', 'Foyer');
      state = state.copyWith(convergence: const ActionDone());
      unawaited(loadFamilyInfo());
    } catch (e, st) {
      Log.e('Failed to converge after join', e, st, 'Foyer');
      state = state.copyWith(
        convergence: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }
}

final foyerControllerProvider = NotifierProvider<FoyerController, FoyerState>(
  FoyerController.new,
);
