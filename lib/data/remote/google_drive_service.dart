import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  final String backupFileName = 'jadhav_finance_backup.isar';
  
  final List<String> _scopes = [drive.DriveApi.driveAppdataScope];

  GoogleDriveService();

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await GoogleSignIn(scopes: _scopes).signIn();
      await _initDriveApi();
      return _currentUser;
    } catch (e) {
      print('Sign in error: $e');
      throw Exception(e.toString());
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      _currentUser = await GoogleSignIn(scopes: _scopes).signInSilently();
      if (_currentUser != null) {
        await _initDriveApi();
      }
      return _currentUser;
    } catch (e) {
      print('Silent sign in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    _currentUser = null;
    _driveApi = null;
  }

  Future<void> _initDriveApi() async {
    if (_currentUser == null) return;
    
    final headers = await _currentUser!.authHeaders;
    
    if (headers.isNotEmpty) {
      final client = GoogleAuthClient(headers);
      _driveApi = drive.DriveApi(client);
    }
  }

  Future<bool> hasBackup() async {
    if (_driveApi == null) return false;
    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        q: "name = '\$backupFileName'",
      );
      return fileList.files?.isNotEmpty ?? false;
    } catch (e) {
      print('Error checking backup: \$e');
      return false;
    }
  }

  Future<bool> backupDatabase(String localDbPath) async {
    if (_driveApi == null || kIsWeb) return false;
    
    try {
      final file = File(localDbPath);
      if (!await file.exists()) return false;

      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        q: "name = '\$backupFileName'",
      );

      final media = drive.Media(file.openRead(), file.lengthSync());
      final driveFile = drive.File()..name = backupFileName;

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final existingFileId = fileList.files!.first.id!;
        await _driveApi!.files.update(
          driveFile,
          existingFileId,
          uploadMedia: media,
        );
      } else {
        driveFile.parents = ['appDataFolder'];
        await _driveApi!.files.create(
          driveFile,
          uploadMedia: media,
        );
      }
      return true;
    } catch (e) {
      print('Backup error: \$e');
      return false;
    }
  }

  Future<bool> restoreDatabase(String localDbPath) async {
    if (_driveApi == null || kIsWeb) return false;

    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        q: "name = '\$backupFileName'",
      );

      if (fileList.files == null || fileList.files!.isEmpty) return false;

      final fileId = fileList.files!.first.id!;
      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final saveFile = File(localDbPath);
      
      final iosink = saveFile.openWrite();
      await media.stream.pipe(iosink);
      await iosink.close();
      
      return true;
    } catch (e) {
      print('Restore error: \$e');
      return false;
    }
  }
}
