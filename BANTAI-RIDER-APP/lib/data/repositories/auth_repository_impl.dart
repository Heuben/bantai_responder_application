import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../data/models/auth_session_model.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      body: {
        'email': email.trim(),
        'password': password,
      },
      parser: (json) => Map<String, dynamic>.from(json as Map),
    );

    if (!response.isSuccess || response.data == null) {
      throw ApiException(response.statusCode, response.message ?? 'Login failed');
    }

    return AuthSessionModel.fromJson(response.data!);
  }

  @override
  Future<bool> checkBackendHealth() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.health,
        parser: (json) => Map<String, dynamic>.from(json as Map),
      );
      return response.isSuccess;
    } on ApiException {
      return false;
    }
  }
}
