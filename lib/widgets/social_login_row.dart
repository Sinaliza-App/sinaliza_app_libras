import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao conectar com $provider. Tente novamente.')),
      );
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
      onTap: isLoading ? null : () => _signInWithOAuth(provider, context),
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
