import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/garage_provider.dart';
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

  runApp(const NexoryGarageApp());
}

class NexoryGarageApp extends StatelessWidget {
  const NexoryGarageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GarageProvider>(
      create: (_) => GarageProvider(),
      child: Selector<GarageProvider, bool>(
        selector: (_, provider) => provider.isDarkMode,
        builder: (context, isDarkMode, child) {
          return MaterialApp(
            title: 'Nexory Garage Management',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const MainNavigationScreen(),
          );
        },
      ),
    );
  }
}
