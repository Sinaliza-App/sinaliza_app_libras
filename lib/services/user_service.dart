import '../database/mysql_connection.dart';
import '../models/user.dart';

class UserService {
  final MySQLConnection _db = MySQLConnection.instance;

  /// Get all users
  Future<List<User>> getAllUsers() async {
    try {
      final results = await _db.query('SELECT * FROM users ORDER BY name ASC');

      return results.map((row) => User.fromMap(row.fields)).toList();
    } catch (e) {
      print('❌ Erro ao buscar usuários: $e');
      rethrow;
    }
  }

  /// Get user by ID
  Future<User?> getUserById(int id) async {
    try {
      final results = await _db.prepared('SELECT * FROM users WHERE id = ?', [
        id,
      ]);

      if (results.isNotEmpty) {
        return User.fromMap(results.first.fields);
      }
      return null;
    } catch (e) {
      print('❌ Erro ao buscar usuário por ID: $e');
      rethrow;
    }
  }

  /// Get user by email
  Future<User?> getUserByEmail(String email) async {
    try {
      final results = await _db.prepared(
        'SELECT * FROM users WHERE email = ?',
        [email],
      );

      if (results.isNotEmpty) {
        return User.fromMap(results.first.fields);
      }
      return null;
    } catch (e) {
      print('❌ Erro ao buscar usuário por email: $e');
      rethrow;
    }
  }

  /// Create new user
  Future<User> createUser(User user) async {
    try {
      final now = DateTime.now();
      final results = await _db.prepared(
        '''INSERT INTO users (name, email, phone, profile_image, user_type, is_active, created_at, updated_at) 
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          user.name,
          user.email,
          user.phone,
          user.profileImage,
          user.userType,
          user.isActive ? 1 : 0,
          now.toIso8601String(),
          now.toIso8601String(),
        ],
      );

      return user.copyWith(
        id: results.insertId,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      print('❌ Erro ao criar usuário: $e');
      rethrow;
    }
  }

  /// Update user
  Future<User> updateUser(User user) async {
    try {
      final now = DateTime.now();
      await _db.prepared(
        '''UPDATE users SET name = ?, email = ?, phone = ?, profile_image = ?, 
           user_type = ?, is_active = ?, updated_at = ? WHERE id = ?''',
        [
          user.name,
          user.email,
          user.phone,
          user.profileImage,
          user.userType,
          user.isActive ? 1 : 0,
          now.toIso8601String(),
          user.id,
        ],
      );

      return user.copyWith(updatedAt: now);
    } catch (e) {
      print('❌ Erro ao atualizar usuário: $e');
      rethrow;
    }
  }

  /// Delete user
  Future<bool> deleteUser(int id) async {
    try {
      final results = await _db.prepared('DELETE FROM users WHERE id = ?', [
        id,
      ]);

      return (results.affectedRows ?? 0) > 0;
    } catch (e) {
      print('❌ Erro ao deletar usuário: $e');
      rethrow;
    }
  }

  /// Get users by type
  Future<List<User>> getUsersByType(String userType) async {
    try {
      final results = await _db.prepared(
        'SELECT * FROM users WHERE user_type = ? ORDER BY name ASC',
        [userType],
      );

      return results.map((row) => User.fromMap(row.fields)).toList();
    } catch (e) {
      print('❌ Erro ao buscar usuários por tipo: $e');
      rethrow;
    }
  }

  /// Activate/Deactivate user
  Future<bool> toggleUserStatus(int id, bool isActive) async {
    try {
      final results = await _db.prepared(
        'UPDATE users SET is_active = ?, updated_at = ? WHERE id = ?',
        [isActive ? 1 : 0, DateTime.now().toIso8601String(), id],
      );

      return (results.affectedRows ?? 0) > 0;
    } catch (e) {
      print('❌ Erro ao alterar status do usuário: $e');
      rethrow;
    }
  }
}
