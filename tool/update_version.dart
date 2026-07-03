import 'dart:io';

void main() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    print('Error: pubspec.yaml not found.');
    exit(1);
  }

  final lines = file.readAsLinesSync();
  final newLines = <String>[];
  bool versionUpdated = false;
  String? newVersion;

  // Matches e.g. "1.0.3", "1.0.3-bf", "1.0.3+2", "1.0.3-bf+2"
  final versionPattern =
      RegExp(r'^(\d+)\.(\d+)\.(\d+)(-[A-Za-z0-9.]+)?(\+(\d+))?$');

  for (final line in lines) {
    if (line.trim().startsWith('version:') && !versionUpdated) {
      final parts = line.split(':');
      if (parts.length > 1) {
        final versionString = parts[1].trim();
        final match = versionPattern.firstMatch(versionString);

        if (match != null) {
          final major = int.parse(match.group(1)!);
          final minor = int.parse(match.group(2)!);
          final patch = int.parse(match.group(3)!);
          final suffix = match.group(4) ?? ''; // e.g. "-bf"
          final build = match.group(6) != null ? int.parse(match.group(6)!) : 0;

          final newPatch = patch + 1;
          final newBuild = build + 1;

          newVersion = '$major.$minor.$newPatch$suffix+$newBuild';

          newLines.add('version: $newVersion');
          versionUpdated = true;
          print('Version updated to: $newVersion');
          continue;
        }
      }
    }
    newLines.add(line);
  }

  if (versionUpdated) {
    file.writeAsStringSync(newLines.join('\n') + '\n');
  } else {
    print('Error: Could not find a parseable version line in pubspec.yaml');
    exit(1);
  }
}
