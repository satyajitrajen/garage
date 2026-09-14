/// Auth-session wire types. These come from the Phase 1 endpoints and use
/// snake_case keys (unlike the camelCase domain objects in model_json.dart).
class AuthUser {
  const AuthUser({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
      );
}

/// One garage the user belongs to. [permissions] is the server's source of
/// truth for UI gating; owners carry all 11 keys.
class Membership {
  const Membership({
    required this.garageId,
    required this.garageName,
    required this.role,
    required this.permissions,
    required this.isActive,
  });

  final String garageId;
  final String garageName;
  final String role;
  final List<String> permissions;
  final bool isActive;

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        garageId: json['garage_id'] as String,
        garageName: json['garage_name'] as String,
        role: json['role'] as String,
        permissions: [for (final p in (json['permissions'] as List)) p as String],
        isActive: json['is_active'] as bool,
      );
}

/// Body of POST /api/auth/login and /api/auth/register.
class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.memberships,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final List<Membership> memberships;

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
        memberships: [
          for (final m in (json['memberships'] as List))
            Membership.fromJson(m as Map<String, dynamic>)
        ],
      );
}
