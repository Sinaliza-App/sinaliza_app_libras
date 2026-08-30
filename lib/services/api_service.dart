import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:sinaliza_app_libras/main.dart'; // Precisamos do navigatorKey
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sinaliza_app_libras/widgets/custom_snackbar.dart';

class ApiService {
  static Future<String?> _getToken() async {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  static Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    final token = await _getToken();
    
    final finalHeaders = headers ?? {};
    if (token != null) {
      finalHeaders['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(Uri.parse(url), headers: finalHeaders);
    _handleAuthErrors(response);
    return response;
  }

  static Future<http.Response> post(String url, {Map<String, String>? headers, Object? body}) async {
    final token = await _getToken();
    
    final finalHeaders = headers ?? {};
    finalHeaders['Content-Type'] = 'application/json';
    if (token != null) {
      finalHeaders['Authorization'] = 'Bearer $token';
    }

    final response = await http.post(Uri.parse(url), headers: finalHeaders, body: body);
    _handleAuthErrors(response);
    return response;
  }

  static Future<http.Response> put(String url, {Map<String, String>? headers, Object? body}) async {
    final token = await _getToken();
    
    final finalHeaders = headers ?? {};
    finalHeaders['Content-Type'] = 'application/json';
    if (token != null) {
      finalHeaders['Authorization'] = 'Bearer $token';
    }

    final response = await http.put(Uri.parse(url), headers: finalHeaders, body: body);
    _handleAuthErrors(response);
    return response;
  }

  static Future<http.Response> delete(String url, {Map<String, String>? headers}) async {
    final token = await _getToken();
    
    final finalHeaders = headers ?? {};
    if (token != null) {
      finalHeaders['Authorization'] = 'Bearer $token';
    }

    final response = await http.delete(Uri.parse(url), headers: finalHeaders);
    _handleAuthErrors(response);
    return response;
  }

  static void _handleAuthErrors(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      _logoutAndRedirect();
    }
  }

  static Future<void> _logoutAndRedirect() async {
    // Se a sessão já estiver nula (usuário clicou em sair manualmente),
    // não precisamos mostrar a mensagem de expiração nem forçar o redirecionamento de novo.
    if (Supabase.instance.client.auth.currentSession == null) {
      return;
    }

    await Supabase.instance.client.auth.signOut();
    
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      CustomSnackBar.showError(
        context,
        'Sua sessão expirou. Por favor, faça login novamente.',
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<dynamic>(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
