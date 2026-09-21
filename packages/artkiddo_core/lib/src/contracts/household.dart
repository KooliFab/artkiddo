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

  /// The redeemed code belonged to the caller's own current family: no
  /// membership change happened, and [vaultReset] is always false.
  final bool sameFamily;

  /// True only when a previous family was actually discarded as part of
  /// this redemption ([FamilyApi.redeemInvite]'s `discardPrevious`, honored
  /// and non-trivial). The local vault can only ever be bound to one
  /// family at a time (see `VaultMetaRepository.attachFamily`), so a true
  /// value means the caller must erase its local vault before converging
  /// against the newly joined family.
  final bool vaultReset;

  const RedeemOutcome({
    required this.state,
    this.familyId,
    this.role,
    this.sameFamily = false,
    this.vaultReset = false,
  });
}

class FamilyMembership {
  final String familyId;
  final FamilyMemberRole role;

  const FamilyMembership({required this.familyId, required this.role});
}

class UserProfile {
  final String userId;
  final String email;
  final String? firstName;
  final String? lastName;
  final DateTime? updatedAt;

  const UserProfile({
    required this.userId,
    required this.email,
    this.firstName,
    this.lastName,
    this.updatedAt,
  });

  String get displayName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) return '$first $last';
    if (first.isNotEmpty) return first;
    if (last.isNotEmpty) return last;
    return email;
  }
}

class FamilyMember {
  final String userId;
  final FamilyMemberRole role;
  final String email;
  final String? firstName;
  final String? lastName;
  final DateTime joinedAt;
  final DateTime? leftAt;

  const FamilyMember({
    required this.userId,
    required this.role,
    required this.email,
    this.firstName,
    this.lastName,
    required this.joinedAt,
    this.leftAt,
  });

  bool get isActive => leftAt == null;

  String get displayName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) return '$first $last';
    if (first.isNotEmpty) return first;
    if (last.isNotEmpty) return last;
    return email;
  }
}

abstract class FamilyApi {
  Future<FamilyInfo> getFamilyInfo();
  Future<void> renameFamily(String name);
  Future<FamilyMembership?> currentMembership();

  /// Redeems [code]. When [discardPrevious] is true and the caller was an
  /// active member of a different family, that family is left in the same
  /// server transaction as the join, and purged — content and remote
  /// storage — if the departure leaves it with zero active members. See
  /// [RedeemOutcome.vaultReset] for what this implies locally.
  Future<RedeemOutcome> redeemInvite({
    required String code,
    bool discardPrevious = false,
  });
  Future<int> activeMemberCount(String familyId);

  Future<UserProfile> getMyProfile();
  Future<UserProfile> updateMyProfile({String? firstName, String? lastName});
  Future<List<FamilyMember>> listFamilyMembers();
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
  Future<RedeemOutcome> redeemInvite({
    required String code,
    bool discardPrevious = false,
  }) async {
    throw const HouseholdUnavailableException();
  }

  @override
  Future<int> activeMemberCount(String familyId) async {
    throw const HouseholdUnavailableException();
  }

  @override
  Future<UserProfile> getMyProfile() async {
    throw const HouseholdUnavailableException();
  }

  @override
  Future<UserProfile> updateMyProfile({String? firstName, String? lastName}) async {
    throw const HouseholdUnavailableException();
  }

  @override
  Future<List<FamilyMember>> listFamilyMembers() async {
    throw const HouseholdUnavailableException();
  }
}
