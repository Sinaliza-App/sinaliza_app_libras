// models/usuario.dart
class Usuario {
  final int id;
  final String nome;
  final String email;
  final int pontos;

  Usuario({required this.id, required this.nome, required this.email, required this.pontos});

  // Construtor para criar um Usuario a partir de um Map vindo do DB
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'],
      nome: map['nome'],
      email: map['email'],
      pontos: map['pontos'],
    );
  }
}

// models/progresso_licao.dart
class ProgressoLicao {
  final int licaoId;
  final int pontuacao;
  final bool concluida;

  ProgressoLicao({required this.licaoId, required this.pontuacao, required this.concluida});

  factory ProgressoLicao.fromMap(Map<String, dynamic> map) {
    return ProgressoLicao(
      licaoId: map['licao_id'],
      pontuacao: map['pontuacao'],
      concluida: map['concluida'] == 1, // Converte 1/0 para true/false
    );
  }
}