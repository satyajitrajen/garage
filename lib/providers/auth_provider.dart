import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/api/api_config.dart';
import '../data/api/auth_models.dart';
import '../data/api/token_store.dart';

/// Session state: tokens + selected garage + cached identity (TokenStore).
///
/// Owns the [ApiClient] tokens so every repository call is authenticated, and
/// exposes the server permission matrix for UI gating via [can].
class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiClient? client, TokenStore? store})
      : _client = client ?? ApiClient(),
        _store = store ?? TokenStore() {
    _client.onUnauthorized = refresh;
  }

  final ApiClient _client;
  final TokenStore _store;

  ApiClient get client => _client;

  bool _initializing = true;
  bool get isInitializing => _initializing;

  bool _busy = false;
  bool get isBusy => _busy;

  String? _error;
  String? get error => _error;

  AuthUser? _user;
  AuthUser? get user => _user;

  List<Membership> _memberships = [];
  List<Membership> get memberships => List.unmodifiable(_memberships);

  String? _garageId;
  String? get garageId => _garageId;

  bool get isAuthenticated =>
      _user != null && (_client.accessToken?.isNotEmpty ?? false);

  Membership? get currentMembership {
    if (_garageId == null) return null;
    try {
      return _memberships.firstWhere((m) => m.garageId == _garageId);
    } catch (_) {
      return null;
    }
  }

  bool get isOwner => currentMembership?.role == 'owner';

  /// Server permission matrix check. Owners bypass; unknown/empty → deny.
  bool can(String permission) {
    final m = currentMembership;
    if (m == null || !m.isActive) return false;
    if (m.role == 'owner') return true;
    return m.permissions.contains(permission);
  }

  Future<void> init() async {
    _initializing = true;
    notifyListeners();
    try {
      final access = await _store.readAccess();
      final refresh = await _store.readRefresh();
      final garage = await _store.readGarageId();
      final userJson = await _store.readUserJson();
      final memJson = await _store.readMembershipsJson();

      if (access != null && access.isNotEmpty) {
        _client.accessToken = access;
        _client.refreshToken = refresh;
        _client.garageId = garage;
        _garageId = garage;
        if (userJson != null) {
          try {
            _user = AuthUser.fromJson(
                jsonDecode(userJson) as Map<String, dynamic>);
          } catch (_) {
            _user = null;
          }
        }
        if (memJson != null) {
          try {
            final list = jsonDecode(memJson) as List;
            _memberships = [
              for (final m in list)
                Membership.fromJson(m as Map<String, dynamic>)
            ];
          } catch (_) {
            _memberships = [];
          }
        }
        // Opportunistically validate + refresh identity in background.
        if (_user == null) {
          await _fetchMe();
        }
      }
    } catch (_) {
      // Corrupt storage → start signed out.
      await _clearAll();
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    await _store.writeTokens(
      access: _client.accessToken,
      refresh: _client.refreshToken,
    );
    await _store.writeGarageId(_garageId);
    _client.garageId = _garageId;
    if (_user != null) {
      await _store.writeUserJson(jsonEncode(
          {'id': _user!.id, 'email': _user!.email, 'name': _user!.name}));
    } else {
      await _store.writeUserJson(null);
    }
    await _store.writeMembershipsJson(jsonEncode([
      for (final m in _memberships)
        {
          'garage_id': m.garageId,
          'garage_name': m.garageName,
          'role': m.role,
          'permissions': m.permissions,
          'is_active': m.isActive,
        }
    ]));
  }

  Future<void> _clearAll() async {
    _user = null;
    _memberships = [];
    _garageId = null;
    _client.accessToken = null;
    _client.refreshToken = null;
    _client.garageId = null;
    try {
      await _store.clearAll();
    } catch (_) {}
  }

  void _applySession(LoginResponse session) {
    _client.accessToken = session.accessToken;
    _client.refreshToken = session.refreshToken;
    _user = session.user;
    _memberships = session.memberships.where((m) => m.isActive).toList();
    if (_memberships.isEmpty) {
      _memberships = session.memberships;
    }
    // Keep prior garage if still valid, else pick first active.
    final stillValid = _memberships.any((m) => m.garageId == _garageId);
    if (!stillValid) {
      _garageId = _memberships.isEmpty ? null : _memberships.first.garageId;
    }
    _client.garageId = _garageId;
  }

  Future<void> _runBusy(Future<void> Function() fn) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await fn();
      await _persist();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) {
    return _runBusy(() async {
      final raw = ApiClient(baseUrl: _client.baseUrl)
        ..accessToken = null
        ..garageId = null;
      try {
        final json = await raw.postNoGarage('/api/auth/login', {
          'email': email.trim(),
          'password': password,
        });
        final session =
            LoginResponse.fromJson(json as Map<String, dynamic>);
        _client.accessToken = session.accessToken;
        _client.refreshToken = session.refreshToken;
        _applySession(session);
      } finally {
        raw.close();
      }
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String garageName,
  }) {
    return _runBusy(() async {
      final raw = ApiClient(baseUrl: ApiConfig.baseUrl);
      try {
        final json = await raw.postNoGarage('/api/auth/register', {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'garageName': garageName.trim(),
        });
        final session =
            LoginResponse.fromJson(json as Map<String, dynamic>);
        _client.accessToken = session.accessToken;
        _client.refreshToken = session.refreshToken;
        _applySession(session);
      } finally {
        raw.close();
      }
    });
  }

  /// Single-use refresh rotation. Returns `true` when tokens were renewed.
  Future<bool> refresh() async {
    final rt = _client.refreshToken;
    if (rt == null || rt.isEmpty) return false;
    try {
      final raw = ApiClient(baseUrl: _client.baseUrl);
      try {
        final json = await raw.postNoGarage('/api/auth/refresh', {
          'refresh_token': rt,
        });
        final map = json as Map<String, dynamic>;
        _client.accessToken = map['access_token'] as String;
        _client.refreshToken = map['refresh_token'] as String;
        await _persist();
        notifyListeners();
        return true;
      } finally {
        raw.close();
      }
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> _fetchMe() async {
    try {
      final json = await _client.get('/api/me', withGarage: false);
      final map = json as Map<String, dynamic>;
      _user = AuthUser.fromJson(map['user'] as Map<String, dynamic>);
      _memberships = [
        for (final m in (map['memberships'] as List))
          Membership.fromJson(m as Map<String, dynamic>)
      ];
      if (_garageId == null && _memberships.isNotEmpty) {
        _garageId = _memberships.first.garageId;
        _client.garageId = _garageId;
      }
      await _persist();
    } catch (_) {
      // Offline at boot → keep cached identity.
    }
  }

  Future<void> selectGarage(String id) async {
    _garageId = id;
    _client.garageId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> logout() async {
    final rt = _client.refreshToken;
    if (rt != null && rt.isNotEmpty) {
      try {
        await _client.postNoGarage('/api/auth/logout', {
          'refresh_token': rt,
        });
      } catch (_) {
        // Best effort.
      }
    }
    await _clearAll();
    notifyListeners();
  }

  // ---------- SaaS identity (logged-out friendly, no garage header) ----------

  ApiClient _raw() => ApiClient(baseUrl: _client.baseUrl);

  /// Sends (or resends) the verification email. Always succeeds server-side.
  Future<void> requestVerify({required String email}) {
    return _runBusy(() async {
      final raw = _raw();
      try {
        await raw.postNoGarage('/api/auth/verify-request', {'email': email.trim()});
      } finally {
        raw.close();
      }
    });
  }

  Future<void> verify({required String token}) {
    return _runBusy(() async {
      final raw = _raw();
      try {
        await raw.postNoGarage('/api/auth/verify', {'token': token.trim()});
      } finally {
        raw.close();
      }
    });
  }

  Future<void> forgot({required String email}) {
    return _runBusy(() async {
      final raw = _raw();
      try {
        await raw.postNoGarage('/api/auth/forgot', {'email': email.trim()});
      } finally {
        raw.close();
      }
    });
  }

  Future<void> reset({required String token, required String password}) {
    return _runBusy(() async {
      final raw = _raw();
      try {
        await raw.postNoGarage('/api/auth/reset', {
          'token': token.trim(),
          'password': password,
        });
      } finally {
        raw.close();
      }
    });
  }

  /// Accepts an invite token for the signed-in user.
  Future<void> acceptInvite({required String token}) async {
    await _client.post('/api/invites/${token.trim()}/accept');
    await _fetchMe();
    notifyListeners();
  }

  // ---------- SaaS billing ----------

  /// Garage billing status (plan, subscription state, trial window).
  Future<Map<String, dynamic>> fetchBilling() async {
    final gid = _garageId;
    if (gid == null || gid.isEmpty) throw StateError('No active garage');
    final json = await _client.get('/api/garages/$gid/billing');
    return (json as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> startCheckout({required String plan}) async {
    final gid = _garageId;
    if (gid == null || gid.isEmpty) throw StateError('No active garage');
    final json = await _client.post('/api/garages/$gid/billing/checkout', {'plan': plan});
    return (json as Map<String, dynamic>);
  }

  Future<void> cancelBilling() async {
    final gid = _garageId;
    if (gid == null || gid.isEmpty) throw StateError('No active garage');
    await _client.post('/api/garages/$gid/billing/cancel');
  }

  // ---------- SaaS team (login identities, distinct from staff roster) ----------

  Future<List<Map<String, dynamic>>> fetchMembers() async {
    final gid = _garageId;
    if (gid == null || gid.isEmpty) throw StateError('No active garage');
    final json = await _client.get('/api/garages/$gid/members');
    final items = (json as Map<String, dynamic>)['items'] as List? ?? [];
    return [for (final m in items) (m as Map<String, dynamic>)];
  }

  Future<void> inviteMember({
    required String email,
    String role = 'staff',
    List<String>? permissions,
  }) async {
    final gid = _garageId;
    if (gid == null || gid.isEmpty) throw StateError('No active garage');
    await _client.post('/api/garages/$gid/invites', {
      'email': email.trim(),
      'role': role,
      'permissions': ?permissions,
    });
  }

  /// Invites that are neither accepted nor expired.
  Future<List<Map<String, dynamic>>> fetchInvites() async {
    final gid = _garageId;
    if (gid == null || gid.isEmpty) throw StateError('No active garage');
    final json = await _client.get('/api/garages/$gid/invites');
    final items = (json as Map<String, dynamic>)['items'] as List? ?? [];
    return [for (final m in items) (m as Map<String, dynamic>)];
  }

  Future<void> revokeInvite(String inviteId) async {
    final gid = _garageId;
    if (gid == null || gid.isEmpty) throw StateError('No active garage');
    await _client.delete('/api/garages/$gid/invites/$inviteId');
  }

  Future<String> nextDocNumber(String kind) async {
    final gid = _garageId;
    if (gid == null || gid.isEmpty) throw StateError('No active garage');
    final json = await _client.get('/api/garages/$gid/doc-numbers/next?kind=$kind');
    return (json as Map<String, dynamic>)['number'] as String;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
