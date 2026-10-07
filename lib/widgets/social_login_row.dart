import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsignin;
import 'package:sinaliza_app_libras/widgets/custom_snackbar.dart';

class SocialLoginRow extends StatelessWidget {
  final bool isLoading;

  const SocialLoginRow({super.key, this.isLoading = false});

  Future<void> _signInWithOAuth(OAuthProvider provider, BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'sinaliza://login-callback',
      );
    } catch (e) {
      if (!context.mounted) return;
      CustomSnackBar.showError(context, 'Erro ao conectar com $provider. Tente novamente.');
    }
  }

  Future<void> _nativeGoogleSignIn(BuildContext context) async {
    try {
      const webClientId = '794114707123-fsq1sm2qkepdfv2f5q4565l23dkil38c.apps.googleusercontent.com';

      final gsignin.GoogleSignIn googleSignIn = gsignin.GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: webClientId,
      );
      
      // Abre o pop-up nativo
      final googleUser = await googleSignIn.authenticate();
      
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Não foi possível obter o ID Token do Google.');
      }

      // Entrega o token pro Supabase em silêncio
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      
    } catch (e) {
      if (!context.mounted) return;
      debugPrint('Erro Google nativo: $e');
      CustomSnackBar.showError(context, 'Erro ao entrar com Google: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton(
          context: context,
          provider: OAuthProvider.google,
          child: const FaIcon(FontAwesomeIcons.google, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        _buildSocialButton(
          context: context,
          provider: OAuthProvider.github,
          child: const FaIcon(FontAwesomeIcons.github, color: Colors.white, size: 26),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required OAuthProvider provider,
    required Widget child,
  }) {
    return InkWell(
      onTap: isLoading 
        ? null 
        : () {
            if (provider == OAuthProvider.google) {
              _nativeGoogleSignIn(context);
            } else {
              _signInWithOAuth(provider, context);
            }
          },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF07101F), // Container Dark
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: child,
        ),
      ),
    );
  }
}
