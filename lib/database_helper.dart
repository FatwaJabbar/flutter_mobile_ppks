import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'riwayat.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE riwayat (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT,
            tanggal TEXT,
            berat REAL,
            harga REAL,
            jenisPupuk TEXT,
            jumlah REAL,
            biaya REAL,
            lainnya REAL,
            createdAt TEXT
          )
        ''');
      },
    );
  }

  static Future<int> insert(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('riwayat', data);
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await database;
    return await db.query(
      'riwayat',
      orderBy: 'createdAt DESC',
    );
  }
}
