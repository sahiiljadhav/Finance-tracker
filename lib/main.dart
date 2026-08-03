import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/local/isar_database.dart';
import 'data/remote/google_drive_service.dart';
import 'data/repositories/finance_repository_impl.dart';
import 'presentation/providers/finance_providers.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_IN', null);

  try {
    final isarDb = IsarDatabase();
    await isarDb.init();

    final driveService = GoogleDriveService();
    
    // Try silent sign-in
    final user = await driveService.signInSilently();
    
    final repo = FinanceRepository(isarDb, driveService);
    if (user != null) {
      repo.setConnected(true);
    }

    runApp(
      ProviderScope(
        overrides: [
          financeRepositoryProvider.overrideWithValue(repo),
        ],
        child: const JadhavFinanceApp(),
      ),
    );
  } catch (e, stack) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Startup Error: \$e\n\n\$stack', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
      ),
    ));
  }
}

class JadhavFinanceApp extends StatelessWidget {
  const JadhavFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Record Book',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SetupScreen(),
    );
  }
}
