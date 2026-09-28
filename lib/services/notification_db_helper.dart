import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class NotificationDbHelper {
  static final NotificationDbHelper _instance = NotificationDbHelper._internal();
  factory NotificationDbHelper() => _instance;
  NotificationDbHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'workorder_notifications.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            workorder_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            language TEXT NOT NULL,
            created_at TEXT NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0,
            highlight1 TEXT,
            highlight2 TEXT
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_notif_lookup ON notifications(user_id, workorder_id, type)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // ⭐ إضافة أعمدة التمييز اللوني عند الترقية من نسخة قديمة بدون كسر البيانات الحالية
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE notifications ADD COLUMN highlight1 TEXT');
          await db.execute('ALTER TABLE notifications ADD COLUMN highlight2 TEXT');
        }
      },
    );
  }

  Future<bool> hasNotified({
    required int userId,
    required int workorderId,
    required String type,
  }) async {
    final db = await database;
    final result = await db.query(
      'notifications',
      where: 'user_id = ? AND workorder_id = ? AND type = ?',
      whereArgs: [userId, workorderId, type],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// ⭐ حفظ إشعار جديد. [highlight1] و [highlight2] هما النصوص المراد تلوينها
  /// باللون الأحمر عند عرض هذا الإشعار في شاشة السجل (مثلاً اسم الموظف واسم المنتج)
  Future<void> insertNotification({
    required int userId,
    required int workorderId,
    required String type,
    required String title,
    required String body,
    required String language,
    String? highlight1,
    String? highlight2,
  }) async {
    final db = await database;
    await db.insert('notifications', {
      'user_id': userId,
      'workorder_id': workorderId,
      'type': type,
      'title': title,
      'body': body,
      'language': language,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': 0,
      'highlight1': highlight1,
      'highlight2': highlight2,
    });
  }

  Future<List<Map<String, dynamic>>> getNotificationsForUser(int userId) async {
    final db = await database;
    return db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> clearFlag({
    required int userId,
    required int workorderId,
    required String type,
  }) async {
    final db = await database;
    await db.delete(
      'notifications',
      where: 'user_id = ? AND workorder_id = ? AND type = ?',
      whereArgs: [userId, workorderId, type],
    );
  }

  Future<void> markAsRead(int notificationId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  Future<void> deleteById(int id) async {
    final db = await database;
    await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'notifications',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> deleteAllForUser(int userId) async {
    final db = await database;
    await db.delete('notifications', where: 'user_id = ?', whereArgs: [userId]);
  }
}
