import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/api_client.dart';
import 'package:garage_manager/data/api/api_exception.dart';
import 'package:garage_manager/data/api/api_garage_repository.dart';
import 'package:garage_manager/data/api/model_json.dart';
import 'package:garage_manager/data/garage_profile.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/models/invoice.dart';
import 'package:garage_manager/models/maintenance_item.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/services/mock_data_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'api/model_json_settings_test.dart' show settingsWire;

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

http.Response _forbidden() => _json({
      'error': {'code': 'forbidden', 'message': 'missing permission'}
    }, 403);

void main() {
  group('ApiGarageRepository', () {
    test('staff login: 403 collections load empty instead of failing', () async {
      final requests = <String>[];
      final client = ApiClient(
        baseUrl: 'https://api.test',
        httpClient: MockClient((req) async {
          requests.add('${req.method} ${req.url.path}');
          switch (req.url.path) {
            case '/api/garages/g-1/settings':
              return _json(settingsWire);
            case '/api/expenses':
            case '/api/staff':
            case '/api/salary-advances':
              return _forbidden();
            default:
              return _json({'items': [], 'total': 0, 'limit': 200, 'offset': 0});
          }
        }),
      )..garageId = 'g-1';
      final garage = GarageProvider(ApiGarageRepository(client));
      await garage.load();

      expect(garage.loadError, isNull);
      expect(garage.expenses, isEmpty);
      expect(garage.staff, isEmpty);
      expect(garage.profile.name, 'NT Garage & Body Shop');
      // Profile + config share a single settings request.
      expect(requests.where((r) => r.endsWith('/settings')), hasLength(1));
    });

    test('non-permission errors still fail the load', () async {
      final client = ApiClient(
        baseUrl: 'https://api.test',
        httpClient: MockClient((req) async => req.url.path.endsWith('settings')
            ? _json(settingsWire)
            : _json({'error': {'code': 'internal', 'message': 'boom'}}, 500)),
      )..garageId = 'g-1';
      final garage = GarageProvider(ApiGarageRepository(client));
      await garage.load();
      expect(garage.loadError, 'boom');
    });

    test('list fetch walks every page', () async {
      final all = MockDataService.getInitialCustomers();
      final client = ApiClient(
        baseUrl: 'https://api.test',
        httpClient: MockClient((req) async {
          final offset = int.parse(req.url.queryParameters['offset']!);
          expect(req.url.queryParameters['limit'], '200');
          // Serve two customers per page to force several round trips.
          final page = all.skip(offset).take(2).map(customerToJson).toList();
          return _json({'items': page, 'total': all.length});
        }),
      )..garageId = 'g-1';
      final customers = await ApiGarageRepository(client).fetchCustomers();
      expect(customers.map((c) => c.id), all.map((c) => c.id));
    });

    test('creates send a blank document number so the server allocates it',
        () async {
      Map<String, dynamic>? sent;
      final invoice = MockDataService.getInitialInvoices().first;
      final client = ApiClient(
        baseUrl: 'https://api.test',
        httpClient: MockClient((req) async {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _json(
              {...invoiceToJson(invoice), 'invoiceNumber': 'INV-2026-0042'},
              201);
        }),
      )..garageId = 'g-1';
      final created = await ApiGarageRepository(client).createInvoice(invoice);
      expect(sent!['invoiceNumber'], '');
      expect(created.invoiceNumber, 'INV-2026-0042');
    });

    test('cancel uses the dedicated endpoint', () async {
      String? hit;
      final invoice = MockDataService.getInitialInvoices().first;
      final client = ApiClient(
        baseUrl: 'https://api.test',
        httpClient: MockClient((req) async {
          hit = '${req.method} ${req.url.path}';
          return _json({
            ...invoiceToJson(invoice),
            'cancelledAt': DateTime.now().toIso8601String(),
          });
        }),
      )..garageId = 'g-1';
      await ApiGarageRepository(client).cancelInvoice(invoice.id);
      expect(hit, 'POST /api/invoices/${invoice.id}/cancel');
    });
  });

  group('ApiClient token refresh', () {
    test('concurrent 401s share one refresh, however slow', () async {
      var refreshes = 0;
      late ApiClient client;
      client = ApiClient(
        baseUrl: 'https://api.test',
        httpClient: MockClient((req) async =>
            req.headers['Authorization'] == 'Bearer fresh'
                ? _json({'ok': true})
                : _json({'error': {'code': 'unauthorized', 'message': ''}}, 401)),
        onUnauthorized: () async {
          refreshes++;
          // Slower than the old 2s polling cap.
          await Future<void>.delayed(const Duration(milliseconds: 2500));
          client.accessToken = 'fresh';
          return true;
        },
      )..accessToken = 'stale';

      final results = await Future.wait([
        for (var i = 0; i < 5; i++) client.get('/api/customers'),
      ]);
      expect(results, everyElement({'ok': true}));
      expect(refreshes, 1);
    });

    test('failed refresh surfaces the 401', () async {
      final client = ApiClient(
        baseUrl: 'https://api.test',
        httpClient: MockClient((_) async =>
            _json({'error': {'code': 'unauthorized', 'message': 'expired'}}, 401)),
        onUnauthorized: () async => false,
      )..accessToken = 'stale';
      expect(
        client.get('/api/customers'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    });
  });

  group('GarageProvider', () {
    late GarageProvider garage;
    setUp(() async {
      garage = GarageProvider(MockGarageRepository());
      await garage.load();
    });

    test('updateSettings replaces profile and config', () async {
      const profile = GarageProfile(
        name: 'Sai Motors',
        tagline: '',
        addressLine: 'Plot 4, MIDC',
        city: 'Nashik',
        phone: '0253-11111',
        email: '',
        gstin: '27ABCDE1234F1Z5',
        upiId: 'sai@okbank',
      );
      final config = garage.config;
      await garage.updateSettings(profile, config);
      expect(garage.profile.name, 'Sai Motors');
      expect(garage.profile.gstin, '27ABCDE1234F1Z5');
    });

    test('catalog add and delete', () async {
      final before = garage.catalog.length;
      final item = await garage.addCatalogItem(MaintenanceItem(
        id: 'cat-new',
        name: 'Wiper blade',
        category: ItemCategory.sparePart,
        unitPrice: 350,
      ));
      expect(garage.catalog, hasLength(before + 1));
      await garage.deleteCatalogItem(item.id);
      expect(garage.catalog, hasLength(before));
    });

    test('cancelInvoice cancels unpaid and refuses paid invoices', () async {
      final unpaid = garage.invoices.firstWhere(
          (i) => i.totalPaidAmount == 0 && i.status != InvoiceStatus.cancelled);
      await garage.cancelInvoice(unpaid.id);
      expect(garage.getInvoiceById(unpaid.id)!.status, InvoiceStatus.cancelled);

      final paid = garage.invoices.firstWhere((i) => i.totalPaidAmount > 0);
      expect(() => garage.cancelInvoice(paid.id), throwsException);
    });

    test('quick service retry reuses the job card when billing failed',
        () async {
      final customer = garage.customers.first;
      final vehicle =
          garage.vehicles.firstWhere((v) => v.customerId == customer.id);
      final items = [
        MaintenanceItem(
            id: 'qs-1',
            name: 'Wash',
            category: ItemCategory.labour,
            unitPrice: 300,
            isLabour: true),
      ];
      final jobsBefore = garage.jobCards.length;
      final first = await garage.quickServiceCheckout(
        customerId: customer.id,
        vehicleId: vehicle.id,
        kmReading: vehicle.currentKm,
        items: items,
      );
      expect(garage.jobCards, hasLength(jobsBefore + 1));

      // Retrying with that job card must not create another one; the
      // provider's duplicate-invoice guard reports it already billed.
      final jc = garage.getJobCardById(first.jobCardId!)!;
      await expectLater(
        garage.quickServiceCheckout(
          customerId: customer.id,
          vehicleId: vehicle.id,
          kmReading: vehicle.currentKm,
          items: items,
          existingJobCard: jc,
        ),
        throwsA(isA<QuickServiceBillingException>()
            .having((e) => e.jobCard.id, 'jobCard', jc.id)),
      );
      expect(garage.jobCards, hasLength(jobsBefore + 1));
    });
  });
}
