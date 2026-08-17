import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/print_history_model.dart';

class HistoryDB {
  HistoryDB._();

  static final HistoryDB instance = HistoryDB._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'print_history.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE print_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            type TEXT NOT NULL,
            file_path TEXT NOT NULL,
            created_at TEXT NOT NULL,
            pages INTEGER
          )
        ''');
      },
    );
  }

  Future<int> insertHistory(PrintHistory history) async {
    final db = await database;
    return db.insert('print_history', history.toMap());
  }

  Future<List<PrintHistory>> getAllHistory() async {
    final db = await database;
    final rows = await db.query(
      'print_history',
      orderBy: 'id DESC',
    );
    return rows.map((row) => PrintHistory.fromMap(row)).toList();
  }

  Future<void> deleteHistory(int id) async {
    final db = await database;
    await db.delete(
      'print_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('print_history');
  }
}
