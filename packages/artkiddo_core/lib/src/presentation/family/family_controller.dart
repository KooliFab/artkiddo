import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/household.dart';
import '../../domain/app_failure.dart';
import '../../local/logging/log.dart';
import '../async_action.dart';
import '../children/children_providers.dart';
import '../gallery/gallery_providers.dart';

export '../../contracts/household.dart'
    show
        FamilyInfo,
        FamilyApi,
        FamilyMemberRole,
        FamilyMembership,
        FamilyMember,
        UserProfile,
        RedeemOutcome,
        RedeemState;

/// Provider for [FamilyApi], defaulting to [NoFamilyApi].
/// Compositions enabling [AppCapabilities.household] must override this provider.
final familyApiProvider = Provider<FamilyApi>((ref) {
  return const NoFamilyApi();
});

/// Callback executed after a confirmed family redeem to converge data.
/// Defaults to a no-op in local compositions; overridden in cloud compositions.
final familyConvergenceProvider = Provider<Future<void> Function()>((ref) {
  return () async {};
});

/// Durable marker for a confirmed family switch that may be interrupted
/// before the local vault is erased. Cloud compositions bind this to the
/// sync engine's [VaultMetaRepository]; neutral compositions stay inert.
class FamilyJoinResetStore {
  final Future<void> Function() mark;
  final Future<void> Function() clear;

  const FamilyJoinResetStore({required this.mark, required this.clear});

  const FamilyJoinResetStore.noop() : mark = _noop, clear = _noop;

  static Future<void> _noop() async {}
}

final familyJoinResetStoreProvider = Provider<FamilyJoinResetStore>((ref) {
  return const FamilyJoinResetStore.noop();
});

/// Erases the local vault (database + files) and its family anchor.
/// Called before convergence whenever a redeem actually discarded a
/// previous family ([RedeemOutcome.vaultReset]) — the local vault can only
/// ever be bound to one family at a time, so joining a different one
/// requires starting from an empty vault before the sync engine can
/// re-anchor it. Defaults to a no-op in local compositions; overridden in
/// cloud compositions.
final familyVaultResetProvider = Provider<Future<void> Function()>((ref) {
  return () async {};
});

/// Bilan used by the join-confirmation dialog: how much local content is
/// at stake, and whether the caller is the last active member of their
/// current family (in which case joining elsewhere destroys it server-side
/// too, not just locally).
class JoinImpact {
  final int childCount;
  final int artworkCount;

  /// `true`: sole active member, joining elsewhere purges the family.
  /// `false`: other active members remain, joining elsewhere only leaves it.
  /// `null`: the check itself failed — the caller must not be offered the
  /// destructive path until this resolves, same convention as
  /// [AsyncAction] not distinguishing "false" from "unknown".
  final bool? isAlone;

  const JoinImpact({
    required this.childCount,
    required this.artworkCount,
    required this.isAlone,
  });
}

class FamilyState {
  /// Loads (and, server-side, bootstraps) the caller's family — name,
  /// invite code, own role — in one call.
  final AsyncAction family;
  final FamilyInfo? familyInfo;

  final AsyncAction rename;

  final AsyncAction redeem;
  final RedeemOutcome? redeemOutcome;

  final AsyncAction membersAction;
  final List<FamilyMember> members;

  /// Runs right after a confirmed redemption. Tracked separately from
  /// [redeem] so the screen can show "code accepted, now converging
  /// your family" as a distinct step rather than folding it into the
  /// same spinner.
  final AsyncAction convergence;

  /// Runs between a confirmed redemption and [convergence], only when the
  /// redeem outcome asked for it ([RedeemOutcome.vaultReset]). Tracked
  /// separately so a reset failure can be shown and retried without
  /// implying the join itself, or convergence, failed.
  final AsyncAction joinReset;

  /// Tracks [FamilyController.removeFamilyMember]. Removal is a logical,
  /// server-owned state change (`leftAt`); on success the controller
  /// re-fetches [members] rather than fabricating that timestamp locally.
  final AsyncAction removeMember;

  /// Tracks [FamilyController.updateFamilyMemberRole]. On success the
  /// controller splices the adapter-returned [FamilyMember] back into
  /// [members] in place, since the round trip already returned the
  /// authoritative updated member.
  final AsyncAction updateRole;

  /// Tracks a parent-managed relationship-label edit.
  final AsyncAction updateRelationLabel;

  /// Tracks the signed-in member leaving their family.
  final AsyncAction leaveFamily;

  const FamilyState({
    this.family = const ActionIdle(),
    this.familyInfo,
    this.rename = const ActionIdle(),
    this.redeem = const ActionIdle(),
    this.redeemOutcome,
    this.membersAction = const ActionIdle(),
    this.members = const [],
    this.convergence = const ActionIdle(),
    this.joinReset = const ActionIdle(),
    this.removeMember = const ActionIdle(),
    this.updateRole = const ActionIdle(),
    this.updateRelationLabel = const ActionIdle(),
    this.leaveFamily = const ActionIdle(),
  });

  FamilyState copyWith({
    AsyncAction? family,
    FamilyInfo? familyInfo,
    bool clearFamilyInfo = false,
    AsyncAction? rename,
    AsyncAction? redeem,
    RedeemOutcome? redeemOutcome,
    // A plain `RedeemOutcome?` parameter can only ever mean "keep the
    // current value" (the `?? this.x` idiom below) — it has no way to ask
    // for null. This flag is the escape hatch: a fresh redeem attempt must
    // be able to clear a stale outcome banner from a previous attempt.
    bool clearRedeemOutcome = false,
    AsyncAction? membersAction,
    List<FamilyMember>? members,
    AsyncAction? convergence,
    AsyncAction? joinReset,
    AsyncAction? removeMember,
    AsyncAction? updateRole,
    AsyncAction? updateRelationLabel,
    AsyncAction? leaveFamily,
  }) {
    return FamilyState(
      family: family ?? this.family,
      familyInfo: clearFamilyInfo ? null : (familyInfo ?? this.familyInfo),
      rename: rename ?? this.rename,
      redeem: redeem ?? this.redeem,
      redeemOutcome: clearRedeemOutcome
          ? null
          : (redeemOutcome ?? this.redeemOutcome),
      membersAction: membersAction ?? this.membersAction,
      members: members ?? this.members,
      convergence: convergence ?? this.convergence,
      joinReset: joinReset ?? this.joinReset,
      removeMember: removeMember ?? this.removeMember,
      updateRole: updateRole ?? this.updateRole,
      updateRelationLabel: updateRelationLabel ?? this.updateRelationLabel,
      leaveFamily: leaveFamily ?? this.leaveFamily,
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
class FamilyController extends Notifier<FamilyState> {
  @override
  FamilyState build() => const FamilyState();

  Future<void> loadFamilyInfo() async {
    if (state.family.isBusy) return;
    state = state.copyWith(family: const ActionBusy());
    try {
      final info = await ref.read(familyApiProvider).getFamilyInfo();
      Log.i('Family loaded: ${info.familyId}', 'Family');
      state = state.copyWith(family: const ActionDone(), familyInfo: info);
      unawaited(loadFamilyMembers());
    } catch (e, st) {
      Log.e('Failed to load family info', e, st, 'Family');
      state = state.copyWith(
        family: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }

  Future<void> loadFamilyMembers() async {
    if (state.membersAction.isBusy) return;
    state = state.copyWith(membersAction: const ActionBusy());
    try {
      final members = await ref.read(familyApiProvider).listFamilyMembers();
      Log.i('Family members loaded: ${members.length}', 'Family');
      state = state.copyWith(
        membersAction: const ActionDone(),
        members: members,
      );
    } catch (e, st) {
      Log.e('Failed to load family members', e, st, 'Family');
      state = state.copyWith(
        membersAction: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }

  Future<void> renameFamily(String name) async {
    if (state.rename.isBusy) return;
    state = state.copyWith(rename: const ActionBusy());
    try {
      await ref.read(familyApiProvider).renameFamily(name);
      Log.i('Family renamed', 'Family');
      final current = state.familyInfo;
      state = state.copyWith(
        rename: const ActionDone(),
        familyInfo: current == null
            ? null
            : FamilyInfo(
                familyId: current.familyId,
                name: name,
                code: current.code,
                role: current.role,
              ),
      );
    } catch (e, st) {
      Log.e('Failed to rename family', e, st, 'Family');
      state = state.copyWith(
        rename: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }

  /// Removes [userId] from the caller's own family. Removal itself is a
  /// server-owned state change ([FamilyApi.removeFamilyMember] sets
  /// `leftAt`, never inferred client-side), so on success this reloads
  /// [FamilyState.members] from the server rather than fabricating that
  /// timestamp locally.
  Future<void> removeFamilyMember(String userId) async {
    if (state.removeMember.isBusy) return;
    state = state.copyWith(removeMember: const ActionBusy());
    try {
      await ref.read(familyApiProvider).removeFamilyMember(userId);
      Log.i('Family member removed', 'Family');
      state = state.copyWith(removeMember: const ActionDone());
      await loadFamilyMembers();
    } catch (e, st) {
      Log.e('Failed to remove family member', e, st, 'Family');
      state = state.copyWith(
        removeMember: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }

  /// Changes [userId]'s role within the caller's own family. The adapter
  /// call already returns the updated member, so this splices it back into
  /// [FamilyState.members] in place instead of triggering a second fetch.
  Future<void> updateFamilyMemberRole(
    String userId,
    FamilyMemberRole role,
  ) async {
    if (state.updateRole.isBusy) return;
    state = state.copyWith(updateRole: const ActionBusy());
    try {
      final updated = await ref
          .read(familyApiProvider)
          .updateFamilyMemberRole(userId, role);
      Log.i('Family member role updated', 'Family');
      state = state.copyWith(
        updateRole: const ActionDone(),
        members: [
          for (final member in state.members)
            if (member.userId == userId) updated else member,
        ],
      );
    } catch (e, st) {
      Log.e('Failed to update family member role', e, st, 'Family');
      state = state.copyWith(
        updateRole: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }

  /// Updates the human-friendly family label independently from the member's
  /// access role. The returned server row remains authoritative, so it is
  /// replaced in place just like [updateFamilyMemberRole].
  Future<void> updateFamilyMemberRelationLabel(
    String userId,
    String? relationLabel,
  ) async {
    if (state.updateRelationLabel.isBusy) return;
    state = state.copyWith(updateRelationLabel: const ActionBusy());
    try {
      final updated = await ref
          .read(familyApiProvider)
          .updateFamilyMemberRelationLabel(userId, relationLabel);
      state = state.copyWith(
        updateRelationLabel: const ActionDone(),
        members: [
          for (final member in state.members)
            if (member.userId == userId) updated else member,
        ],
      );
    } catch (e, st) {
      Log.e('Failed to update family member relation label', e, st, 'Family');
      state = state.copyWith(
        updateRelationLabel: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }

  /// Leaves the caller's current family. The server owns the membership
  /// mutation; locally we clear the loaded family state so the hub cannot
  /// continue presenting stale members after the sheet closes.
  Future<void> leaveFamily() async {
    if (state.leaveFamily.isBusy) return;
    state = state.copyWith(leaveFamily: const ActionBusy());
    try {
      await ref.read(familyApiProvider).leaveFamily();
      state = state.copyWith(
        leaveFamily: const ActionDone(),
        members: const [],
        clearFamilyInfo: true,
      );
    } catch (e, st) {
      Log.e('Failed to leave family', e, st, 'Family');
      state = state.copyWith(
        leaveFamily: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }

  /// `true`: the caller is the sole active member of their current family
  /// (joining elsewhere would purge it server-side). `false`: other active
  /// members remain. `null`: the check failed — callers must treat this as
  /// "unknown", never as "false", and keep any destructive action gated.
  ///
  /// Mirrors `AccountController.isLastActiveFamilyMember()` exactly —
  /// both answer the same question ("am I alone here?") for two different
  /// destructive actions (deleting the account, joining elsewhere).
  Future<bool?> isAloneInFamily() async {
    try {
      final api = ref.read(familyApiProvider);
      final membership = await api.currentMembership();
      if (membership == null) return false;
      final count = await api.activeMemberCount(membership.familyId);
      return count <= 1;
    } catch (e, st) {
      Log.e('Failed to check family membership', e, st, 'Family');
      return null;
    }
  }

  /// Bilan for the join-confirmation dialog: local content at stake, plus
  /// [isAloneInFamily]. Read-only — makes no server call that could redeem
  /// anything, so it is safe to show even for a code that turns out to be
  /// invalid.
  Future<JoinImpact> joinImpact() async {
    final children = ref.read(childrenRepositoryProvider).count();
    final artworks = ref.read(artworksRepositoryProvider).count();
    final alone = isAloneInFamily();
    return JoinImpact(
      childCount: await children,
      artworkCount: await artworks,
      isAlone: await alone,
    );
  }

  /// Redeems [code] and, on a confirmed success, immediately triggers
  /// the join-or-restore convergence — redeeming itself never
  /// transfers any data: it's the caller's job to chain convergence
  /// after a confirmed join. [discardPrevious] must only ever be true
  /// after the caller has already shown and confirmed the destructive
  /// warning — this method itself makes no such decision.
  Future<void> redeem(String code, {bool discardPrevious = false}) async {
    if (state.redeem.isBusy) return;
    state = state.copyWith(
      redeem: const ActionBusy(),
      clearRedeemOutcome: true,
      convergence: const ActionIdle(),
      joinReset: const ActionIdle(),
    );
    try {
      if (discardPrevious) {
        await ref.read(familyJoinResetStoreProvider).mark();
      }
      final outcome = await ref
          .read(familyApiProvider)
          .redeemInvite(code: code, discardPrevious: discardPrevious);
      Log.i('Invite processed: ${outcome.state.name}', 'Family');
      state = state.copyWith(
        redeem: const ActionDone(),
        redeemOutcome: outcome,
      );
      if (outcome.state == RedeemState.ok) {
        if (outcome.vaultReset) {
          final reset = await _resetVaultForJoin();
          if (!reset) return; // joinReset already holds the error.
        } else if (discardPrevious && outcome.sameFamily) {
          // The target was already the caller's only active family. No reset
          // remains to recover after a restart.
          await ref.read(familyJoinResetStoreProvider).clear();
        } else if (discardPrevious) {
          // A successful discard that does not explicitly request a reset is
          // an incompatible backend response. Keep the durable marker and
          // reset locally before converging rather than fail-open into a
          // vault still attached to the old family.
          final reset = await _resetVaultForJoin();
          if (!reset) return;
        }
        await _joinOrRestore();
      } else if (discardPrevious) {
        await ref.read(familyJoinResetStoreProvider).clear();
      }
    } catch (e, st) {
      Log.e('Failed to redeem invite', e, st, 'Family');
      state = state.copyWith(
        redeem: ActionError(NetworkFailure(cause: e, stack: st)),
      );
    }
  }

  /// Retries only the local vault reset (and, on success, convergence),
  /// without re-redeeming the code. The server-side join already
  /// committed when [redeem] first got as far as [FamilyState.joinReset]
  /// — redeeming the same code again would now see `sameFamily: true`
  /// and skip the reset entirely, silently leaving the local vault still
  /// pointed at the discarded family.
  Future<void> retryJoinReset() async {
    if (state.joinReset.isBusy) return;
    final reset = await _resetVaultForJoin();
    if (reset) await _joinOrRestore();
  }

  /// Erases the local vault before converging against the newly joined
  /// family. Returns whether it succeeded; a failure is left in
  /// [FamilyState.joinReset] rather than raised, so the caller can retry
  /// this step alone without re-redeeming an already-consumed code.
  Future<bool> _resetVaultForJoin() async {
    state = state.copyWith(joinReset: const ActionBusy());
    try {
      await ref.read(familyVaultResetProvider)();
      await ref.read(familyJoinResetStoreProvider).clear();
      Log.i('Local vault reset before joining new family', 'Family');
      state = state.copyWith(joinReset: const ActionDone());
      return true;
    } catch (e, st) {
      Log.e('Failed to reset local vault before join', e, st, 'Family');
      state = state.copyWith(
        joinReset: ActionError(LocalWriteFailure(cause: e, stack: st)),
      );
      return false;
    }
  }

  Future<void> _joinOrRestore() async {
    state = state.copyWith(convergence: const ActionBusy());
    try {
      final converge = ref.read(familyConvergenceProvider);
      await converge();
      Log.i('Family convergence completed', 'Family');
      state = state.copyWith(convergence: const ActionDone());
      // A successful join changes the caller's active family — refresh
      // name/code/role so the screen reflects the family just joined,
      // not the one that was displayed before redeeming.
      unawaited(loadFamilyInfo());
    } catch (e, st) {
      Log.e('Failed to converge after join', e, st, 'Family');
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

final familyControllerProvider =
    NotifierProvider<FamilyController, FamilyState>(FamilyController.new);

/// Map of userId -> FamilyMember for resolving attributions and member names.
final familyMembersMapProvider = Provider<Map<String, FamilyMember>>((ref) {
  final members = ref.watch(familyControllerProvider.select((s) => s.members));
  return {for (final m in members) m.userId: m};
});
