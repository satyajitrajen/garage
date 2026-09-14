import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/api_exception.dart';
import 'package:garage_manager/data/api/auth_models.dart';

void main() {
  group('Membership', () {
    test('parses snake_case wire format', () {
      final m = Membership.fromJson(const {
        'garage_id': 'g-1',
        'garage_name': 'Nexory Garage',
        'role': 'owner',
        'permissions': ['customers.manage', 'invoices.manage'],
        'is_active': true,
      });
      expect(m.garageId, 'g-1');
      expect(m.garageName, 'Nexory Garage');
      expect(m.role, 'owner');
      expect(m.permissions, ['customers.manage', 'invoices.manage']);
      expect(m.isActive, isTrue);
    });
  });

  group('AuthUser', () {
    test('parses snake_case wire format', () {
      final u = AuthUser.fromJson(const {
        'id': 'u-1',
        'email': 'a@b.c',
        'name': 'Ada',
        'created_at': '2026-09-13T10:00:00Z',
      });
      expect(u.id, 'u-1');
      expect(u.email, 'a@b.c');
      expect(u.name, 'Ada');
    });
  });

  group('LoginResponse', () {
    test('parses snake_case envelope with nested user and memberships', () {
      final r = LoginResponse.fromJson(const {
        'access_token': 'at',
        'refresh_token': 'rt',
        'user': {'id': 'u-1', 'email': 'a@b.c', 'name': 'Ada'},
        'memberships': [
          {
            'garage_id': 'g-1',
            'garage_name': 'Nexory Garage',
            'role': 'owner',
            'permissions': ['customers.manage'],
            'is_active': true,
          }
        ],
      });
      expect(r.accessToken, 'at');
      expect(r.refreshToken, 'rt');
      expect(r.user.name, 'Ada');
      expect(r.memberships.single.garageId, 'g-1');
    });
  });

  group('ApiException', () {
    test('carries status, code and message', () {
      const e = ApiException(409, 'conflict', 'email already registered');
      expect(e.statusCode, 409);
      expect(e.code, 'conflict');
      expect(e.message, 'email already registered');
      expect(e.toString(), contains('409'));
    });
  });
}
