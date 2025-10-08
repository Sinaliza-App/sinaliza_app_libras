import '../database/mysql_connection.dart';
import '../models/sign.dart';

class SignService {
  final MySQLConnection _db = MySQLConnection.instance;

  /// Get all signs
  Future<List<Sign>> getAllSigns() async {
    try {
      final results = await _db.query('SELECT * FROM signs ORDER BY word ASC');

      return results.map((row) => Sign.fromMap(row.fields)).toList();
    } catch (e) {
      print('❌ Erro ao buscar sinais: $e');
      rethrow;
    }
  }

  /// Get sign by ID
  Future<Sign?> getSignById(int id) async {
    try {
      final results = await _db.prepared('SELECT * FROM signs WHERE id = ?', [
        id,
      ]);

      if (results.isNotEmpty) {
        return Sign.fromMap(results.first.fields);
      }
      return null;
    } catch (e) {
      print('❌ Erro ao buscar sinal por ID: $e');
      rethrow;
    }
  }

  /// Search signs by word
  Future<List<Sign>> searchSigns(String searchTerm) async {
    try {
      final results = await _db.prepared(
        'SELECT * FROM signs WHERE word LIKE ? OR description LIKE ? ORDER BY word ASC',
        ['%$searchTerm%', '%$searchTerm%'],
      );

      return results.map((row) => Sign.fromMap(row.fields)).toList();
    } catch (e) {
      print('❌ Erro ao buscar sinais: $e');
      rethrow;
    }
  }

  /// Get signs by category
  Future<List<Sign>> getSignsByCategory(String category) async {
    try {
      final results = await _db.prepared(
        'SELECT * FROM signs WHERE category = ? ORDER BY word ASC',
        [category],
      );

      return results.map((row) => Sign.fromMap(row.fields)).toList();
    } catch (e) {
      print('❌ Erro ao buscar sinais por categoria: $e');
      rethrow;
    }
  }

  /// Create new sign
  Future<Sign> createSign(Sign sign) async {
    try {
      final now = DateTime.now();
      final results = await _db.prepared(
        '''INSERT INTO signs (word, description, video_url, image_url, category, created_at, updated_at) 
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          sign.word,
          sign.description,
          sign.videoUrl,
          sign.imageUrl,
          sign.category,
          now.toIso8601String(),
          now.toIso8601String(),
        ],
      );

      return sign.copyWith(
        id: results.insertId,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      print('❌ Erro ao criar sinal: $e');
      rethrow;
    }
  }

  /// Update sign
  Future<Sign> updateSign(Sign sign) async {
    try {
      final now = DateTime.now();
      await _db.prepared(
        '''UPDATE signs SET word = ?, description = ?, video_url = ?, image_url = ?, 
           category = ?, updated_at = ? WHERE id = ?''',
        [
          sign.word,
          sign.description,
          sign.videoUrl,
          sign.imageUrl,
          sign.category,
          now.toIso8601String(),
          sign.id,
        ],
      );

      return sign.copyWith(updatedAt: now);
    } catch (e) {
      print('❌ Erro ao atualizar sinal: $e');
      rethrow;
    }
  }

  /// Delete sign
  Future<bool> deleteSign(int id) async {
    try {
      final results = await _db.prepared('DELETE FROM signs WHERE id = ?', [
        id,
      ]);

      return (results.affectedRows ?? 0) > 0;
    } catch (e) {
      print('❌ Erro ao deletar sinal: $e');
      rethrow;
    }
  }

  /// Get all categories
  Future<List<String>> getCategories() async {
    try {
      final results = await _db.query(
        'SELECT DISTINCT category FROM signs ORDER BY category ASC',
      );

      return results.map((row) => row.fields['category'] as String).toList();
    } catch (e) {
      print('❌ Erro ao buscar categorias: $e');
      rethrow;
    }
  }
}
