import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/remote/google_drive_service.dart';
import '../../data/local/isar_database.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../providers/finance_providers.dart';
import 'home_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingSession();
    });
  }

  Future<void> _checkExistingSession() async {
    final status = ref.read(syncStatusProvider).value;
    // If we're already connected (silent sign in succeeded in main)
    if (status != SyncStatus.disconnected) {
      _navigateToHome();
    }
  }

  Future<void> _handleConnect() async {
    setState(() => _isLoading = true);
    try {
      final driveService = ref.read(financeRepositoryProvider).driveService;
      final user = await driveService.signIn();

      if (user != null) {
        final hasBackup = await driveService.hasBackup();
        if (hasBackup) {
          if (!mounted) return;
          final restore = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Backup Found'),
              content: const Text('Do you want to restore your previous data? This will replace any existing local data.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Restore'),
                ),
              ],
            ),
          );

          if (restore == true) {
            final isarDb = ref.read(financeRepositoryProvider).localDb;
            final dbPath = await isarDb.getDatabasePath();
            
            // Close the database to unlock the file
            await isarDb.isar.close();
            
            // Download and overwrite the database file
            await driveService.restoreDatabase(dbPath);
            
            // Re-initialize the database so it loads the newly downloaded data
            await isarDb.init();
          }
        }
        
        ref.read(financeRepositoryProvider).setConnected(true);
        _navigateToHome();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: \$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                size: 80,
                color: Color(0xFF0D47A1),
              ),
              const SizedBox(height: 32),
              Text(
                'Connect Google Drive',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D47A1),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your data will be safely stored in your Google Drive so it remains secure even if you change your phone.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton.icon(
                  onPressed: _handleConnect,
                  icon: const Icon(Icons.cloud_sync_rounded),
                  label: const Text('Connect Google Account'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _navigateToHome,
                  child: const Text('Continue Offline (No Backup)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
