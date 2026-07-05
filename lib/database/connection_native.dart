import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor createConnection() {
  return LazyDatabase(() async {
    Directory dbFolder;
    if (Platform.isAndroid || Platform.isIOS) {
      dbFolder = await getApplicationDocumentsDirectory();
    } else {
      dbFolder = await getApplicationSupportDirectory();
    }

    final file = File(p.join(dbFolder.path, 'finzy_downloads.db'));

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    if (!Platform.isAndroid && !Platform.isIOS && !await file.exists()) {
      final oldFolder = await getApplicationSupportDirectory();
      final oldFile = File(p.join(oldFolder.path, 'finzy_downloads.db'));
      if (await oldFile.exists()) {
        await oldFile.rename(file.path);
      } else {
        final docsFolder = await getApplicationDocumentsDirectory();
        final docsFile = File(p.join(docsFolder.path, 'finzy_downloads.db'));
        if (await docsFile.exists()) {
          await docsFile.rename(file.path);
        }
      }
    }

    return NativeDatabase(file);
  });
}
