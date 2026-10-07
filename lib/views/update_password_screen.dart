import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';
import 'package:sinaliza_app_libras/widgets/custom_snackbar.dart';
import 'package:sinaliza_app_libras/widgets/animations/fade_in_slide.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // O Supabase atualiza a senha do usuário que está logado atualmente
      // (a sessão foi criada automaticamente ao clicar no deep link)
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      
      if (!mounted) return;
      CustomSnackBar.showSuccess(context, 'Senha redefinida com sucesso!');
      
      // Desloga o usuário e redireciona para o login
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<dynamic>(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'Erro ao atualizar a senha.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.darkBG,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            "Redefinir Senha",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
      body: SafeArea(
        child: FadeInSlide(
          duration: const Duration(milliseconds: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.neonBlue,
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Crie uma nova senha",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Obrigatório: \nMin 8 caracteres, 1 maiúscula, 1 minúscula, 1 número e 1 símbolo.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.neonRed,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Campo Senha
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nova Senha',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.neonBlue),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.neonBlue, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.neonRed),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.neonRed, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.cardDark,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'A senha é obrigatória';
                      }
                      if (value.length < 8) {
                        return 'Mínimo de 8 caracteres';
                      }
                      if (!RegExp(r'[A-Z]').hasMatch(value)) {
                        return 'Pelo menos uma letra maiúscula';
                      }
                      if (!RegExp(r'[a-z]').hasMatch(value)) {
                        return 'Pelo menos uma letra minúscula';
                      }
                      if (!RegExp(r'[0-9]').hasMatch(value)) {
                        return 'Pelo menos um número';
                      }
                      if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                        return 'Pelo menos um símbolo especial';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Campo Confirmar Senha
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Confirmar Nova Senha',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.neonBlue),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.neonBlue, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.neonRed),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.neonRed, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.cardDark,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirme a nova senha';
                      }
                      if (value != _passwordController.text) {
                        return 'As senhas não coincidem';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),

                  // Botão Salvar
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonBlue,
                      foregroundColor: AppColors.darkBG,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: AppColors.neonBlue.withValues(alpha: 0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: AppColors.darkBG, strokeWidth: 3),
                          )
                        : const Text(
                            "REDEFINIR SENHA",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  TextButton(
                    onPressed: () {
                       // Volta para o login sem resetar (vai que ele lembrou a senha)
                       Navigator.pushReplacement(
                         context,
                         MaterialPageRoute<dynamic>(builder: (context) => const LoginScreen()),
                       );
                    },
                    child: const Text(
                      "Voltar para o Login",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
