library;

/// Thrown by the neutral [NoFoyerApi] when household-scoped work is
/// attempted in a composition that never enabled the `household` capability.
/// The public core still declares this provider (with this honest default)
/// so widgets never read a capability-owned provider directly; the exception
/// exists only to fail loudly if a caller reaches it despite the capability
/// gate, rather than fabricating a household that does not exist.
class HouseholdUnavailableException implements Exception {
  const HouseholdUnavailableException();

  @override
  String toString() =>
      'HouseholdUnavailableException: no household composition is bound';
}

enum FoyerMemberRole { parent, contributeur }

extension FoyerMemberRoleWire on FoyerMemberRole {
  String get wireName =>
      this == FoyerMemberRole.parent ? 'parent' : 'contributeur';
}

class FamilyInfo {
  final String foyerId;
  final String? name;
  final String code;
  final FoyerMemberRole role;

  const FamilyInfo({
    required this.foyerId,
    this.name,
    required this.code,
    required this.role,
  });
}

enum RedeemState { ok, invalidCode }

class RedeemOutcome {
  final RedeemState state;
  final String? foyerId;
  final FoyerMemberRole? role;

  const RedeemOutcome({required this.state, this.foyerId, this.role});
}

class FoyerMembership {
  final String foyerId;
  final FoyerMemberRole role;

  const FoyerMembership({required this.foyerId, required this.role});
}

abstract class FoyerApi {
  Future<FamilyInfo> getFamilyInfo();
  Future<void> renameFamily(String name);
  Future<FoyerMembership?> currentMembership();
  Future<RedeemOutcome> redeemInvite({required String code});
  Future<int> activeMemberCount(String foyerId);
}

/// Default implementation when no composition has bound a real [FoyerApi].
///
/// It never fabricates a household: every member throws
/// [HouseholdUnavailableException]. `currentMembership()` is the one
/// exception — returning `null` ("no membership") is a truthful answer on
/// its own, not a stand-in for a household that was never bound.
final class NoFoyerApi implements FoyerApi {
  const NoFoyerApi();

  @override
  Future<FamilyInfo> getFamilyInfo() async {
    throw const HouseholdUnavailableException();
  }

  @override
  Future<void> renameFamily(String name) async {
    throw const HouseholdUnavailableException();
  }

  @override
  Future<FoyerMembership?> currentMembership() async => null;

  @override
  Future<RedeemOutcome> redeemInvite({required String code}) async {
    throw const HouseholdUnavailableException();
  }

  @override
  Future<int> activeMemberCount(String foyerId) async {
    throw const HouseholdUnavailableException();
  }
}
