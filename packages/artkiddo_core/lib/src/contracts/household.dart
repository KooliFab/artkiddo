library;

/// Thrown by the neutral [NoFamilyApi] when household-scoped work is
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

enum FamilyMemberRole { parent, contributor }

extension FamilyMemberRoleWire on FamilyMemberRole {
  String get wireName =>
      this == FamilyMemberRole.parent ? 'parent' : 'contributor';
}

class FamilyInfo {
  final String familyId;
  final String? name;
  final String code;
  final FamilyMemberRole role;

  const FamilyInfo({
    required this.familyId,
    this.name,
    required this.code,
    required this.role,
  });
}

enum RedeemState { ok, invalidCode }

class RedeemOutcome {
  final RedeemState state;
  final String? familyId;
  final FamilyMemberRole? role;

  const RedeemOutcome({required this.state, this.familyId, this.role});
}

class FamilyMembership {
  final String familyId;
  final FamilyMemberRole role;

  const FamilyMembership({required this.familyId, required this.role});
}

abstract class FamilyApi {
  Future<FamilyInfo> getFamilyInfo();
  Future<void> renameFamily(String name);
  Future<FamilyMembership?> currentMembership();
  Future<RedeemOutcome> redeemInvite({required String code});
  Future<int> activeMemberCount(String familyId);
}

/// Default implementation when no composition has bound a real [FamilyApi].
///
/// It never fabricates a household: every member throws
/// [HouseholdUnavailableException]. `currentMembership()` is the one
/// exception — returning `null` ("no membership") is a truthful answer on
/// its own, not a stand-in for a household that was never bound.
final class NoFamilyApi implements FamilyApi {
  const NoFamilyApi();

  @override
  Future<FamilyInfo> getFamilyInfo() async {
    throw const HouseholdUnavailableException();
  }

  @override
  Future<void> renameFamily(String name) async {
    throw const HouseholdUnavailableException();
  }

  @override
  Future<FamilyMembership?> currentMembership() async => null;

  @override
  Future<RedeemOutcome> redeemInvite({required String code}) async {
    throw const HouseholdUnavailableException();
  }

  @override
  Future<int> activeMemberCount(String familyId) async {
    throw const HouseholdUnavailableException();
  }
}
