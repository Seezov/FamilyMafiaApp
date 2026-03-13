import 'package:family_mafia_app/enums/role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RolePercentilesRepository
    extends StateNotifier<Map<int, Map<Role, double?>>> {
  RolePercentilesRepository() : super(const {});

  void setPercentiles(Map<int, Map<Role, double?>> data) {
    state = data;
  }
}

final rolePercentilesRepositoryProvider = StateNotifierProvider<
    RolePercentilesRepository, Map<int, Map<Role, double?>>>(
  (ref) => RolePercentilesRepository(),
);
