import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'settings_service.dart';

class FtpService {
  FTPConnect? _ftpConnect;
  String _pathPrefix = '';

  static ({String host, int port, String pathPrefix}) _countryConfig(String country) {
    if (country == 'Burkina Faso') {
      return (host: 'ftp.crundata.net', port: 2121, pathPrefix: 'r21');
    }
    return (host: '0f7a55b.netsolhost.com', port: 21, pathPrefix: '');
  }

  /// Connect to the FTP server
  Future<bool> connect(String username, String password) async {
    final country = await SettingsService().country;
    final config = _countryConfig(country);
    _pathPrefix = config.pathPrefix;
    _ftpConnect = FTPConnect(config.host, user: username, pass: password, port: config.port);
    try {
      await _ftpConnect!.connect();
      return true;
    } catch (e) {
      debugPrint('[FtpService] Connection failed: $e');
      return false;
    }
  }

  /// List zip files in the /survey/ directory
  Future<List<String>> listSurveyZips() async {
    if (_ftpConnect == null) return [];
    try {
      if (_pathPrefix.isNotEmpty) await _ftpConnect!.changeDirectory(_pathPrefix);
      await _ftpConnect!.changeDirectory('survey');
      final entries = await _ftpConnect!.listDirectoryContent();

      // Filter for .zip files
      return entries
          .where((entry) =>
              entry.name != null && entry.name!.toLowerCase().endsWith('.zip'))
          .map((entry) => entry.name!)
          .toList();
    } catch (e) {
      debugPrint('[FtpService] List failed: $e');
      return [];
    }
  }

  /// Download a specific zip file to the local zips folder
  Future<File?> downloadSurveyZip(String filename) async {
    if (_ftpConnect == null) return null;
    try {
      // Get local zips directory
      Directory baseDir;
      if (Platform.isAndroid) {
        baseDir = await getExternalStorageDirectory() ??
            await getApplicationSupportDirectory();
      } else if (Platform.isWindows) {
        // Windows: Use LOCALAPPDATA for AppData\Local
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null) {
          baseDir = Directory(localAppData);
        } else {
          baseDir = await getApplicationSupportDirectory();
        }
      } else {
        // Linux/Mac
        baseDir = await getApplicationSupportDirectory();
      }
      final zipsDir = Directory(p.join(baseDir.path, 'GiSTX', 'zips'));
      if (!await zipsDir.exists()) {
        await zipsDir.create(recursive: true);
      }

      final localFile = File(p.join(zipsDir.path, filename));

      // Ensure we are in the right directory on server
      if (_pathPrefix.isNotEmpty) await _ftpConnect!.changeDirectory(_pathPrefix);
      await _ftpConnect!.changeDirectory('survey');

      await _ftpConnect!.downloadFile(filename, localFile);
      return localFile;
    } catch (e) {
      debugPrint('[FtpService] Download failed: $e');
      return null;
    }
  }

  /// Upload a file to the /data/ directory
  Future<bool> uploadFile(File file, String remoteFilename) async {
    if (_ftpConnect == null) return false;
    try {
      // Ensure we are in the right directory on server
      if (_pathPrefix.isNotEmpty) await _ftpConnect!.changeDirectory(_pathPrefix);
      await _ftpConnect!.changeDirectory('data');

      await _ftpConnect!.uploadFile(file, sRemoteName: remoteFilename);
      return true;
    } catch (e) {
      debugPrint('[FtpService] Upload failed: $e');
      return false;
    }
  }

  /// Disconnect from the FTP server
  Future<void> disconnect() async {
    if (_ftpConnect != null) {
      try {
        await _ftpConnect!.disconnect();
      } catch (e) {
        debugPrint('[FtpService] Disconnect failed: $e');
      }
      _ftpConnect = null;
    }
  }
}
