import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/features/admin/admin_access.dart';

void main() {
  test('only staff roles with usable account states enter administration', () {
    expect(AdminAccess(null).isStaff, isFalse);
    expect(
      AdminAccess({'id': 'a', 'role': 'member', 'state': 'active'}).isStaff,
      isFalse,
    );
    expect(
      AdminAccess({'id': 'a', 'role': 'admin', 'state': 'active'}).isStaff,
      isTrue,
    );
    expect(
      AdminAccess({'id': 'a', 'role': 'owner', 'state': 'banned'}).isStaff,
      isFalse,
    );
    expect(
      AdminAccess({'id': 'a', 'role': 'root', 'state': 'active'}).isStaff,
      isFalse,
    );
  });
  test('an admin may not withdraw somebody else resource', () {
    expect(
      AdminAccess({'id': 'a', 'role': 'admin', 'state': 'active'})
          .canWithdraw('b'),
      isFalse,
    );
    expect(
      AdminAccess({'id': 'a', 'role': 'member', 'state': 'active'})
          .canWithdraw('a'),
      isTrue,
    );
    expect(
      AdminAccess({'id': 'a', 'role': 'owner', 'state': 'active'})
          .canWithdraw('b'),
      isTrue,
    );
    expect(AdminAccess(null).canWithdraw(null), isFalse);
  });
}
