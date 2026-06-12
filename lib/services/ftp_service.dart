import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'settings_service.dart';

enum FtpUploadStage {
  changeDirectory,
  upload,
  verifyFilename,
  verifySize,
}

extension FtpUploadStageLabel on FtpUploadStage {
  String get label {
    switch (this) {
      case FtpUploadStage.changeDirectory:
        return 'changeDirectory';
      case FtpUploadStage.upload:
        return 'upload';
      case FtpUploadStage.verifyFilename:
        return 'verifyFilename';
      case FtpUploadStage.verifySize:
        return 'verifySize';
    }
  }
}

class FtpUploadResult {
  final bool success;
  final FtpUploadStage stage;
  final String remoteDirectory;
  final String remoteFilename;
  final int localBytes;
  final int? remoteBytes;
  final String message;

  const FtpUploadResult({
    required this.success,
    required this.stage,
    required this.remoteDirectory,
    required this.remoteFilename,
    required this.localBytes,
    required this.remoteBytes,
    required this.message,
  });

  String get failureMessage {
    if (success) return message;
    return 'Upload failed during ${stage.label}: $message';
  }
}

class FtpService {
  FTPConnect? _ftpConnect;
  String _pathPrefix = '';

  static ({String host, int port, String pathPrefix}) _countryConfig(
      String country) {
    if (country == 'Burkina Faso') {
      return (host: 'ftp.crundata.net', port: 2220, pathPrefix: 'r21');
    }
    return (host: '0f7a55b.netsolhost.com', port: 21, pathPrefix: '');
  }

  String get _uploadDirectory =>
      _pathPrefix.isEmpty ? '/data' : '/$_pathPrefix/data';

  /// Connect to the FTP server
  Future<bool> connect(String username, String password) async {
    final country = await SettingsService().country;
    final config = _countryConfig(country);
    _pathPrefix = config.pathPrefix;
    _ftpConnect = FTPConnect(config.host,
        user: username, pass: password, port: config.port);
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
      if (_pathPrefix.isNotEmpty)
        await _ftpConnect!.changeDirectory(_pathPrefix);
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
      if (_pathPrefix.isNotEmpty)
        await _ftpConnect!.changeDirectory(_pathPrefix);
      await _ftpConnect!.changeDirectory('survey');

      await _ftpConnect!.downloadFile(filename, localFile);
      return localFile;
    } catch (e) {
      debugPrint('[FtpService] Download failed: $e');
      return null;
    }
  }

  /// Upload a file to the /data/ directory
  Future<FtpUploadResult> uploadFile(File file, String remoteFilename) async {
    final localBytes = await file.length();
    final remoteDirectory = _uploadDirectory;
    if (_ftpConnect == null) {
      return FtpUploadResult(
        success: false,
        stage: FtpUploadStage.upload,
        remoteDirectory: remoteDirectory,
        remoteFilename: remoteFilename,
        localBytes: localBytes,
        remoteBytes: null,
        message: 'Not connected to FTP server.',
      );
    }

    try {
      // Ensure we are in the right directory on server
      if (_pathPrefix.isNotEmpty) {
        final prefixChanged = await _ftpConnect!.changeDirectory(_pathPrefix);
        if (!prefixChanged) {
          return FtpUploadResult(
            success: false,
            stage: FtpUploadStage.changeDirectory,
            remoteDirectory: remoteDirectory,
            remoteFilename: remoteFilename,
            localBytes: localBytes,
            remoteBytes: null,
            message: 'Cannot access /$_pathPrefix on the FTP server.',
          );
        }
      }

      final dataChanged = await _ftpConnect!.changeDirectory('data');
      if (!dataChanged) {
        return FtpUploadResult(
          success: false,
          stage: FtpUploadStage.changeDirectory,
          remoteDirectory: remoteDirectory,
          remoteFilename: remoteFilename,
          localBytes: localBytes,
          remoteBytes: null,
          message: 'Cannot access $remoteDirectory on the FTP server.',
        );
      }

      final firstAttempt = await _uploadAndVerify(
        file: file,
        remoteFilename: remoteFilename,
        remoteDirectory: remoteDirectory,
        localBytes: localBytes,
        supportIPV6: true,
      );
      if (firstAttempt.success ||
          firstAttempt.stage == FtpUploadStage.changeDirectory) {
        return firstAttempt;
      }

      debugPrint(
          '[FtpService] Retrying upload with IPv4 PASV mode: ${firstAttempt.failureMessage}');
      return _uploadAndVerify(
        file: file,
        remoteFilename: remoteFilename,
        remoteDirectory: remoteDirectory,
        localBytes: localBytes,
        supportIPV6: false,
      );
    } catch (e) {
      debugPrint('[FtpService] Upload failed: $e');
      return FtpUploadResult(
        success: false,
        stage: FtpUploadStage.upload,
        remoteDirectory: remoteDirectory,
        remoteFilename: remoteFilename,
        localBytes: localBytes,
        remoteBytes: null,
        message: e.toString(),
      );
    }
  }

  Future<FtpUploadResult> _uploadAndVerify({
    required File file,
    required String remoteFilename,
    required String remoteDirectory,
    required int localBytes,
    required bool supportIPV6,
  }) async {
    try {
      await _ftpConnect!.uploadFile(
        file,
        sRemoteName: remoteFilename,
        supportIPV6: supportIPV6,
      );
    } catch (e) {
      debugPrint('[FtpService] Upload transfer failed: $e');
      return FtpUploadResult(
        success: false,
        stage: FtpUploadStage.upload,
        remoteDirectory: remoteDirectory,
        remoteFilename: remoteFilename,
        localBytes: localBytes,
        remoteBytes: null,
        message: e.toString(),
      );
    }

    final remoteBytes = await _ftpConnect!.sizeFile(remoteFilename);
    if (remoteBytes == -1) {
      return FtpUploadResult(
        success: false,
        stage: FtpUploadStage.verifyFilename,
        remoteDirectory: remoteDirectory,
        remoteFilename: remoteFilename,
        localBytes: localBytes,
        remoteBytes: null,
        message: '$remoteFilename was not found in $remoteDirectory.',
      );
    }

    if (remoteBytes != localBytes) {
      return FtpUploadResult(
        success: false,
        stage: FtpUploadStage.verifySize,
        remoteDirectory: remoteDirectory,
        remoteFilename: remoteFilename,
        localBytes: localBytes,
        remoteBytes: remoteBytes,
        message:
            '$remoteFilename exists in $remoteDirectory but is $remoteBytes bytes; expected $localBytes bytes.',
      );
    }

    final remotePath = '$remoteDirectory/$remoteFilename';
    debugPrint(
        '[FtpService] Verified upload: $remotePath ($remoteBytes bytes)');
    return FtpUploadResult(
      success: true,
      stage: FtpUploadStage.verifySize,
      remoteDirectory: remoteDirectory,
      remoteFilename: remoteFilename,
      localBytes: localBytes,
      remoteBytes: remoteBytes,
      message: 'Verified $remotePath ($remoteBytes bytes).',
    );
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
