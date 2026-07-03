import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
  static const String _host = '0f7a55b.netsolhost.com';
  static const String _uploadDirectory = '/data';
  static const _downloadTimeout = Duration(minutes: 2);
  FTPConnect? _ftpConnect;

  /// Connect to the FTP server
  Future<bool> connect(String username, String password) async {
    _ftpConnect = FTPConnect(_host, user: username, pass: password);
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
      await _ftpConnect!.changeDirectory('survey');

      await _ftpConnect!
          .downloadFile(filename, localFile)
          .timeout(_downloadTimeout);
      return localFile;
    } on TimeoutException {
      debugPrint(
          '[FtpService] Download timed out after $_downloadTimeout: $filename');
      return null;
    } catch (e) {
      debugPrint('[FtpService] Download failed: $e');
      return null;
    }
  }

  /// Upload a file to the /data/ directory
  Future<FtpUploadResult> uploadFile(File file, String remoteFilename) async {
    final localBytes = await file.length();
    if (_ftpConnect == null) {
      return FtpUploadResult(
        success: false,
        stage: FtpUploadStage.upload,
        remoteDirectory: _uploadDirectory,
        remoteFilename: remoteFilename,
        localBytes: localBytes,
        remoteBytes: null,
        message: 'Not connected to FTP server.',
      );
    }

    try {
      // Ensure we are in the right directory on server
      final dataChanged = await _ftpConnect!.changeDirectory('data');
      if (!dataChanged) {
        return FtpUploadResult(
          success: false,
          stage: FtpUploadStage.changeDirectory,
          remoteDirectory: _uploadDirectory,
          remoteFilename: remoteFilename,
          localBytes: localBytes,
          remoteBytes: null,
          message: 'Cannot access $_uploadDirectory on the FTP server.',
        );
      }

      final firstAttempt = await _uploadAndVerify(
        file: file,
        remoteFilename: remoteFilename,
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
        localBytes: localBytes,
        supportIPV6: false,
      );
    } catch (e) {
      debugPrint('[FtpService] Upload failed: $e');
      return FtpUploadResult(
        success: false,
        stage: FtpUploadStage.upload,
        remoteDirectory: _uploadDirectory,
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
        remoteDirectory: _uploadDirectory,
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
        remoteDirectory: _uploadDirectory,
        remoteFilename: remoteFilename,
        localBytes: localBytes,
        remoteBytes: null,
        message: '$remoteFilename was not found in $_uploadDirectory.',
      );
    }

    if (remoteBytes != localBytes) {
      return FtpUploadResult(
        success: false,
        stage: FtpUploadStage.verifySize,
        remoteDirectory: _uploadDirectory,
        remoteFilename: remoteFilename,
        localBytes: localBytes,
        remoteBytes: remoteBytes,
        message:
            '$remoteFilename exists in $_uploadDirectory but is $remoteBytes bytes; expected $localBytes bytes.',
      );
    }

    final remotePath = '$_uploadDirectory/$remoteFilename';
    debugPrint(
        '[FtpService] Verified upload: $remotePath ($remoteBytes bytes)');
    return FtpUploadResult(
      success: true,
      stage: FtpUploadStage.verifySize,
      remoteDirectory: _uploadDirectory,
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
