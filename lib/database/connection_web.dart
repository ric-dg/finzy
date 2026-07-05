import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor createConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'finzy_downloads',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    return result.resolvedExecutor;
  });
}
