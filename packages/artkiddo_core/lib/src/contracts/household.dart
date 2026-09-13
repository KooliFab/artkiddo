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
