// lib/core/enums/user_role.dart

enum UserRole {
  superAdmin,
  admin,
  seller,
  pos;

  static UserRole? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toUpperCase().trim()) {
      'SUPERADMIN' => UserRole.superAdmin,
      'ADMIN'      => UserRole.admin,
      'SELLER'     => UserRole.seller,
      'POS'        => UserRole.pos,
      _            => null,
    };
  }

  String get rawValue => switch (this) {
    UserRole.superAdmin => 'SUPERADMIN',
    UserRole.admin      => 'ADMIN',
    UserRole.seller     => 'SELLER',
    UserRole.pos        => 'POS',
  };
}
