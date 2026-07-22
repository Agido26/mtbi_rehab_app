import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/game_result.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mtbi_rehab.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE game_results(
            id TEXT PRIMARY KEY,
            patientId TEXT NOT NULL,
            gameType TEXT NOT NULL,
            score INTEGER NOT NULL,
            totalAttempts INTEGER NOT NULL,
            correctAttempts INTEGER NOT NULL,
            durationSeconds INTEGER NOT NULL,
            playedAt TEXT NOT NULL,
            metadata TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_patient ON game_results(patientId)');
        await db.execute('CREATE INDEX idx_game ON game_results(gameType)');
        await db.execute('CREATE INDEX idx_date ON game_results(playedAt)');
      },
    );
  }

  Future<void> saveGameResult(GameResult result) async {
    final db = await database;
    await db.insert(
      'game_results',
      {
        ...result.toJson(),
        'metadata': result.metadata != null ? result.metadata.toString() : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<GameResult>> getResultsForPatient(String patientId) async {
    final db = await database;
    final maps = await db.query(
      'game_results',
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'playedAt DESC',
    );
    return maps.map((m) => GameResult.fromJson(m)).toList();
  }

  Future<List<GameResult>> getResultsForGame(
    String patientId,
    GameType gameType,
  ) async {
    final db = await database;
    final maps = await db.query(
      'game_results',
      where: 'patientId = ? AND gameType = ?',
      whereArgs: [patientId, gameType.name],
      orderBy: 'playedAt DESC',
    );
    return maps.map((m) => GameResult.fromJson(m)).toList();
  }

  Future<Map<GameType, List<GameResult>>> getAllResultsByGame(
    String patientId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'game_results',
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'playedAt DESC',
    );

    final results = maps.map((m) => GameResult.fromJson(m)).toList();
    final grouped = <GameType, List<GameResult>>{};

    for (final result in results) {
      grouped.putIfAbsent(result.gameType, () => []).add(result);
    }

    return grouped;
  }
}
