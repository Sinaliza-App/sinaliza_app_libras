import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sinaliza_app_libras/widgets/social_login_row.dart';
import 'package:sinaliza_app_libras/widgets/custom_snackbar.dart';

// import 'package:sinaliza_app_libras/views/login_screen.dart'; // Se precisar voltar

bool _isEmailValid(String email) {
    // Regex padrão para e-mail
    final RegExp regex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    return regex.hasMatch(email);
  }

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
  bool _obscurePassword = true;

  // --- NOVA FUNÇÃO DE VALIDAÇÃO DETALHADA ---
  // Retorna null se a senha for válida, ou a mensagem de erro específica.
  String? _getPasswordError(String password) {
    if (password.length < 8) {
      return 'A senha deve ter pelo menos 8 caracteres.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'A senha deve conter pelo menos uma letra MAIÚSCULA.';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'A senha deve conter pelo menos uma letra minúscula.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'A senha deve conter pelo menos um número.';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'A senha deve conter um caractere especial (ex: @, #, \$).';
    }
    return null; // Senha válida!
  }
  // -------------------------------------------

  Future<void> _saveUser() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 1. Validação básica de campos vazios
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      CustomSnackBar.showWarning(context, "Preencha todos os campos!");
      return;
    }

    // 2. Validação de Senha Específica (MUDANÇA AQUI)
    final String? passwordError = _getPasswordError(password);
    
    if (passwordError != null) {
      // Se houver erro, mostra a mensagem específica
      if (!mounted) return;
      CustomSnackBar.showWarning(context, passwordError);
      return; // Para a execução aqui
    }
    if (!_isEmailValid(email)) {
      CustomSnackBar.showError(context, 'E-mail inválido. Verifique se tem @ e .com');
      return; // Para tudo aqui e não envia pro servidor
    }

    setState(() => _isSaving = true);

    try {
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (!mounted) return;

      if (res.user != null) {
        // SUCESSO
        CustomSnackBar.showSuccess(context, "Usuário criado com sucesso! Verifique seu e-mail.");
        Navigator.pop(context); 
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, "Erro de conexão: $e");
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
    const Color cardDark = Color.fromARGB(255, 1, 6, 14);
    const Color inputDark = Color(0xFF07101F);

    return Scaffold(
      backgroundColor: darkBackground,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF02040A), Color.fromARGB(255, 7, 19, 44)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.waving_hand_outlined,
                        color: neonGreen,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'SINALIZA',
                        style: TextStyle(
                          color: neonGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  Center(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                      decoration: BoxDecoration(
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
                              Icons.person_add_alt_1_outlined,
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

                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
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
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
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

                          const SizedBox(height: 24),
                          
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Ou continue com',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          SocialLoginRow(isLoading: _isSaving),
                          
                          const SizedBox(height: 24),

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