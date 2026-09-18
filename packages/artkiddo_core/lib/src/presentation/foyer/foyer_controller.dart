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
  /// Loads (and, server-side, bootstraps) the caller's family — name,
  /// invite code, own role — in one call.
  final AsyncAction family;
  final FamilyInfo? familyInfo;

  final AsyncAction rename;

  final AsyncAction redeem;
  final RedeemOutcome? redeemOutcome;

  /// Runs right after a confirmed redemption. Tracked separately from
  /// [redeem] so the screen can show "code accepted, now converging
  /// your foyer" as a distinct step rather than folding it into the
  /// same spinner.
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

/// Client-side controller for the unified household screen:
/// loading/naming the family, sharing its fixed invite code, redeeming
/// someone else's code, and the join-or-restore handoff to the sync
/// engine. Deliberately does not decide whether to merge local
/// artworks into the joined household itself — this controller only
/// ever calls the convergence hook after a confirmed redemption, and
/// lets whatever that hook already does happen as-is.
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

  /// Redeems [code] and, on a confirmed success, immediately triggers
  /// the join-or-restore convergence — redeeming itself never
  /// transfers any data: it's the caller's job to chain convergence
  /// after a confirmed join.
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
      // A successful join changes the caller's active foyer — refresh
      // name/code/role so the screen reflects the family just joined,
      // not the one that was displayed before redeeming.
      unawaited(loadFamilyInfo());
    } catch (e, st) {
      Log.e('Failed to converge after join', e, st, 'Foyer');
      // The membership itself is already durably created server-side at
      // this point — a convergence failure here is retryable (the
      // existing "sync now" path already drains the same outbox/pull
      // cycle), never a reason to report the join itself as failed.
      state = state.copyWith(
        convergence: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }
}

final foyerControllerProvider = NotifierProvider<FoyerController, FoyerState>(
  FoyerController.new,
);
