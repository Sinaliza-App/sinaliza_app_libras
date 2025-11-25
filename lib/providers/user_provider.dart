import 'package:flutter/material.dart';

// 1. O modelo de dados do nosso usuário
class UserModel {
  final int id;
  final String name;
  final String email;
  final int totalScore; // <--- NOVO CAMPO

  UserModel({
    required this.id, 
    required this.name, 
    required this.email,
    required this.totalScore, // <--- NOVO CAMPO
  });

  // Factory para converter o JSON da API em um objeto UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      // Garante que o score seja lido como int, mesmo se vier null ou string
      totalScore: int.parse(json['total_score']?.toString() ?? '0'),
    );
  }
}

// 2. O "armazém" (Provider) que vai guardar o usuário
class UserProvider with ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;

  void setUser(Map<String, dynamic> userData) {
    _user = UserModel.fromJson(userData);
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }
  
  // Função auxiliar para adicionar pontos localmente (opcional, para feedback instantâneo)
  void addScore(int points) {
    if (_user != null) {
      _user = UserModel(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        totalScore: _user!.totalScore + points,
      );
      notifyListeners();
    }
  }
}