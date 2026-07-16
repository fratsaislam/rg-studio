import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/utils/constants.dart';

// ── User Model ────────────────────────────────────────────────────
class AppUser {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final int roleId;
  final bool mustChangePassword;

  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roleId,
    this.mustChangePassword = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        email: json['email'],
        firstName: json['firstName'],
        lastName: json['lastName'],
        roleId: json['roleId'],
        mustChangePassword: json['mustChangePassword'] ?? false,
      );

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName[0]}${lastName[0]}'.toUpperCase();
}

// ── Auth Repository ───────────────────────────────────────────────
class AuthRepository {
  final Ref ref;
  AuthRepository(this.ref);

  Future<AppUser> login(String email, String password) async {
    final dio = ref.read(dioProvider);
    final res = await dio
        .post('/auth/login', data: {'email': email, 'password': password});
    final data = res.data['data'];
    final storage = ref.read(secureStorageProvider);
    await storage.write(
        key: AppConstants.accessTokenKey, value: data['accessToken']);
    await storage.write(
        key: AppConstants.refreshTokenKey, value: data['refreshToken']);
    return AppUser.fromJson(data['user']);
  }

  Future<void> logout() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final refreshToken =
          await storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken != null) {
        await ref
            .read(dioProvider)
            .post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } finally {
      await ref.read(secureStorageProvider).deleteAll();
    }
  }

  Future<AppUser?> getMe() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final token = await storage.read(key: AppConstants.accessTokenKey);
      if (token == null) return null;
      final res = await ref.read(dioProvider).get('/auth/me');
      return AppUser.fromJson(res.data['data']);
    } catch (_) {
      return null;
    }
  }

  Future<void> changePassword(String current, String newPass) async {
    await ref.read(dioProvider).put('/auth/change-password', data: {
      'currentPassword': current,
      'newPassword': newPass,
    });
  }
}

final authRepositoryProvider = Provider((ref) => AuthRepository(ref));

// ── Auth State ────────────────────────────────────────────────────
class AuthNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    return ref.read(authRepositoryProvider).getMe();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final user =
          await ref.read(authRepositoryProvider).login(email, password);
      state = AsyncData(user);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  Future<void> changePassword(String current, String newPass) async {
    await ref.read(authRepositoryProvider).changePassword(current, newPass);
  }
}

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AppUser?>(() => AuthNotifier());
