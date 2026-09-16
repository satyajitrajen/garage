import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/api/api_client.dart';
import 'data/api/api_config.dart';
import 'data/api/api_garage_repository.dart';
import 'data/garage_repository.dart';
import 'data/mock/mock_garage_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/garage_provider.dart';
import 'screens/auth/login_screen.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  runApp(const NTGarageApp());
}

class NTGarageApp extends StatelessWidget {
  const NTGarageApp({super.key, this.repository});

  /// When provided (tests), boots the mock-style shell over that repository,
  /// bypassing ApiConfig routing, AuthProvider.init and secure storage.
  final GarageRepository? repository;

  @override
  Widget build(BuildContext context) {
    // Mock mode preserves the old offline behaviour with zero setup. Pass
    // `--dart-define=USE_MOCK=false` (and `--dart-define=API_BASE_URL=...`)
    // to talk to the Go backend. A test-injected [repository] always takes
    // the mock-style shell.
    final GarageRepository? repo =
        repository ?? (ApiConfig.useMock ? MockGarageRepository() : null);
    if (repo != null) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(),
          ),
          ChangeNotifierProvider<GarageProvider>(
            create: (_) => GarageProvider(repo)..load(),
          ),
        ],
        child: MaterialApp(
          title: 'NT Garage',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const MainNavigationScreen(),
        ),
      );
    }

    final apiClient = ApiClient();
    final auth = AuthProvider(client: apiClient)..init();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProxyProvider<AuthProvider, GarageProvider>(
          create: (_) => GarageProvider(ApiGarageRepository(apiClient)),
          update: (_, auth, garage) {
            garage ??= GarageProvider(ApiGarageRepository(apiClient));
            // Keep the repository pointed at the active garage.
            apiClient.garageId = auth.garageId;
            return garage;
          },
        ),
      ],
      child: MaterialApp(
        title: 'NT Garage',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppGate(),
      ),
    );
  }
}

/// Decides between splash → login → garage-gated main UI.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  String? _loadedGarage;
  bool _loadScheduled = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!auth.isAuthenticated) {
      _loadedGarage = null;
      _loadScheduled = false;
      return const LoginScreen();
    }
    if (auth.garageId == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store_outlined, size: 40),
                const SizedBox(height: 12),
                const Text('No active garage on this account.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: auth.logout,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // (Re)load garage data after sign-in or garage switch, exactly once per
    // garage id. Post-frame so we never call load() during build.
    if (_loadedGarage != auth.garageId && !_loadScheduled) {
      _loadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await context.read<GarageProvider>().load();
          _loadedGarage = auth.garageId;
        } catch (_) {
          // loadError is surfaced by MainNavigationScreen with retry.
          _loadedGarage = auth.garageId;
        } finally {
          _loadScheduled = false;
          if (mounted) setState(() {});
        }
      });
    }

    return const MainNavigationScreen();
  }
}
