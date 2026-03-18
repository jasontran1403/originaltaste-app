// lib/services/auth_service.dart

import '../core/constants/api_constants.dart';
import '../core/enums/user_role.dart';
import '../data/models/general/auth_model.dart';
import '../data/network/dio_client.dart';
import '../data/network/error_handler.dart';
import '../data/storage/session_storage.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // ── State (in-memory, không rebuild widget) ───────────────────
  bool      isLoggedIn  = false;
  UserRole? currentRole;
  String?   currentFullName;
  int?      currentUserId;

  // ── Restore session khi mở app ────────────────────────────────
  Future<bool> restoreSession() async {
    final loggedIn = await SessionStorage.isLoggedIn();
    if (!loggedIn) return false;

    final roleStr = await SessionStorage.getRole();
    final role    = UserRole.fromString(roleStr);
    if (role == null) return false;

    isLoggedIn     = true;
    currentRole    = role;
    currentFullName = await SessionStorage.getFullName();
    currentUserId  = await SessionStorage.getUserId();
    return true;
  }

  // ── Login ─────────────────────────────────────────────────────
  /// Returns null nếu thành công, error message nếu thất bại
  Future<String?> login({
    required String username,
    required String password,
    required bool   rememberMe,
  }) async {
    final result = await DioClient.instance.post<AuthModel>(
      ApiConstants.login,
      body: {'username': username, 'password': password},
      requireAuth: false,
      fromData: (data) => data != null
          ? AuthModel.fromJson(data as Map<String, dynamic>)
          : null,
    );

    if (!result.isSuccess) {
      return ErrorHandler.message(result.code, result.message);
    }

    final auth = result.data;
    if (auth == null) return 'Tài khoản không hợp lệ';

    final role = UserRole.fromString(auth.role);
    if (role == null) {
      return 'Role "${auth.role}" chưa được hỗ trợ, vui lòng liên hệ quản trị viên';
    }

    // Lưu session
    await SessionStorage.saveSession(
      accessToken: auth.accessToken,
      role:        auth.role,
      fullName:    auth.fullName,
      userId:      auth.userId,
      isLock:      auth.isLock,
      rememberMe:  rememberMe,
    );

    isLoggedIn     = true;
    currentRole    = role;
    currentFullName = auth.fullName;
    currentUserId  = auth.userId;

    return null; // success
  }

  // ── Logout ────────────────────────────────────────────────────
  Future<void> logout() async {
    // Fire & forget — không block UI
    DioClient.instance.post(ApiConstants.logout, body: {}).ignore();

    await SessionStorage.clearSession();
    isLoggedIn      = false;
    currentRole     = null;
    currentFullName = null;
    currentUserId   = null;
  }
}
