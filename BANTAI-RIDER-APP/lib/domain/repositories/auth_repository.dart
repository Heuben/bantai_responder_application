import '../../data/models/auth_session_model.dart';

abstract interface class AuthRepository {
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  });

  Future<bool> checkBackendHealth();
}
