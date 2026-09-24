import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/app_providers.dart';

/// Hands a finished export file to the platform share sheet.
///
/// A provider so tests can see the file without opening a real sheet.
/// [origin] anchors the popover on iPad, where a share sheet with no anchor
/// throws.
typedef ShareFile = Future<void> Function(
  File file, {
  required String subject,
  Rect? origin,
});

final shareFileProvider = Provider<ShareFile>(
  (ref) => (file, {required subject, origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
  },
);

/// Where the export file is written before it is shared. The temporary
/// directory, because the share sheet is what puts it somewhere lasting.
final exportDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getTemporaryDirectory,
);

/// Fetches everything the server holds about the user (PRD 6.1) and writes
/// it to a dated JSON file, ready for [ShareFile] - so they can keep it,
/// save it to Files or Drive, or email it, whatever the phone offers.
///
/// Separate from sharing so the caller can take its progress dialog down
/// before the share sheet opens over it.
Future<File> prepareDataExport(WidgetRef ref, {DateTime? now}) async {
  final data = await ref.read(authRepositoryProvider).exportData();

  final stamp = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
  final dir = await ref.read(exportDirectoryProvider)();
  final file = File(p.join(dir.path, 'smart-iq-export-$stamp.json'));
  // Indented: this file is for a person to open, not only for a program.
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(data),
    flush: true,
  );
  return file;
}
