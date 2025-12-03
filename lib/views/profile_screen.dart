import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sinaliza_app_libras/views/lesson_list_screen.dart';
// import 'package:sinaliza_app_libras/views/login_screen.dart'; // Se precisar voltar

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSaving = false;

  // Função de Cadastro Real
  Future<void> _saveUser() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 1. Validação básica
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos!")),
      );
      return;
    }

    setState(() => _isSaving = true);

    // 2. Configuração da API
    // ATENÇÃO: Use o IP correto (Radmin ou 10.0.2.2)
    const String apiUrl = 'http://26.72.151.39:3000/users/register';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final responseData = json.decode(response.body);

      // 3. Tratamento da Resposta
      if (response.statusCode == 201) {
        // SUCESSO (Criado)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? "Usuário criado com sucesso!"),
            backgroundColor: Colors.green,
          ),
        );

        // Opção A: Ir direto para o Login (para ele logar e pegar o token)
        Navigator.pop(context); 

        // Opção B (Avançada): Se a rota /register já retornasse o token,
        // poderíamos logar direto. Mas como ela só cria, mandamos para o Login.
      
      } else {
        // ERRO (ex: email duplicado)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? "Erro ao criar usuário."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro de conexão: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color neonGreen = Color(0xFF00FF9D);
    const Color darkBackground = Color(0xFF02040A);
    const Color cardDark = Color(0xFF050C1A);
    const Color inputDark = Color(0xFF07101F);

    return Scaffold(
      backgroundColor: darkBackground,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF02040A), Color(0xFF020915)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- Branding ----------
                  Row(
                    children: const [
                      Icon(
                        Icons.pan_tool_alt_outlined,
                        color: neonGreen,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'SINALIZA',
                        style: TextStyle(
                          color: neonGreen,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ---------- Card central ----------
                  Center(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                      decoration: BoxDecoration(
                        // Correção Linter: withValues
                        color: cardDark.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ícone circular
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: neonGreen.withValues(alpha: 0.08),
                              border: Border.all(
                                color: neonGreen.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_outlined, // Ícone de cadastro
                              color: neonGreen,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Criar Conta',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),

                          Text(
                            'Preencha suas informações abaixo',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Campo Nome
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Nome',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              filled: true,
                              fillColor: inputDark,
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Campo Email
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'E-mail',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              filled: true,
                              fillColor: inputDark,
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Campo Senha
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              filled: true,
                              fillColor: inputDark,
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Botão Salvar
                          _isSaving
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(neonGreen),
                                )
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _saveUser,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      backgroundColor: neonGreen,
                                      foregroundColor: darkBackground,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: const Text(
                                      'Criar Conta',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),

                          const SizedBox(height: 16),

                          // Link Voltar
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text.rich(
                              TextSpan(
                                text: 'Já tenho uma conta? ',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'Fazer Login',
                                    style: TextStyle(
                                      color: neonGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}