import 'package:flutter/material.dart';

// 1. O modelo de dados do nosso usuário
class UserModel {
  final int id;
  final String name;
  final String email;

  UserModel({required this.id, required this.name, required this.email});

  // Factory para converter o JSON da API em um objeto UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}

// 2. O "armazém" (Provider) que vai guardar o usuário
class UserProvider with ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;

  // Função para definir o usuário após o login ou na splash screen
  void setUser(Map<String, dynamic> userData) {
    _user = UserModel.fromJson(userData);
    notifyListeners(); // Avisa a UI que os dados mudaram
  }

  // Função para limpar o usuário (ao fazer logout)
  void clearUser() {
    _user = null;
    notifyListeners();
  }
}