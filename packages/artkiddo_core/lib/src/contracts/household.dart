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

/// Honest default implementation for local or unauthenticated environments.
final class NoFoyerApi implements FoyerApi {
  const NoFoyerApi();

  @override
  Future<FamilyInfo> getFamilyInfo() async {
    return const FamilyInfo(
      foyerId: 'local',
      name: null,
      code: '',
      role: FoyerMemberRole.parent,
    );
  }

  @override
  Future<void> renameFamily(String name) async {}

  @override
  Future<FoyerMembership?> currentMembership() async => null;

  @override
  Future<RedeemOutcome> redeemInvite({required String code}) async {
    return const RedeemOutcome(state: RedeemState.invalidCode);
  }

  @override
  Future<int> activeMemberCount(String foyerId) async => 1;
}

