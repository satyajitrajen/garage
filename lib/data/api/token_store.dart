import 'package:shared_preferences/shared_preferences.dart';

/// Prefs-backed session persistence.
///
/// Tokens live in [SharedPreferences] (no native plugin, so Windows/macOS/
/// Linux/Web builds work out of the box). Access tokens are short-lived
/// (15 min) and refresh tokens rotate single-use on every refresh, which
/// bounds the impact of plaintext storage. If OS-keychain storage is ever
/// required, reintroduce it behind this same interface — but note its Windows
/// plugin needs the Visual Studio ATL headers (atlstr.h) to compile.
class TokenStore {
  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kGarageId = 'auth_garage_id';
  static const _kUser = 'auth_user_json';
  static const _kMemberships = 'auth_memberships_json';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> readAccess() async => (await _prefs).getString(_kAccess);
  Future<String?> readRefresh() async => (await _prefs).getString(_kRefresh);
  Future<String?> readGarageId() async => (await _prefs).getString(_kGarageId);
  Future<String?> readUserJson() async => (await _prefs).getString(_kUser);
  Future<String?> readMembershipsJson() async =>
      (await _prefs).getString(_kMemberships);

  Future<void> writeTokens({String? access, String? refresh}) async {
    final p = await _prefs;
    if (access != null) await p.setString(_kAccess, access);
    if (refresh != null) await p.setString(_kRefresh, refresh);
  }

  Future<void> writeGarageId(String? garageId) async {
    final p = await _prefs;
    if (garageId != null) {
      await p.setString(_kGarageId, garageId);
    } else {
      await p.remove(_kGarageId);
    }
  }

  Future<void> writeUserJson(String? json) async {
    final p = await _prefs;
    if (json != null) {
      await p.setString(_kUser, json);
    } else {
      await p.remove(_kUser);
    }
  }

  Future<void> writeMembershipsJson(String json) async =>
      (await _prefs).setString(_kMemberships, json);

  Future<void> clearAll() async {
    final p = await _prefs;
    await p.remove(_kAccess);
    await p.remove(_kRefresh);
    await p.remove(_kGarageId);
    await p.remove(_kUser);
    await p.remove(_kMemberships);
  }
}
