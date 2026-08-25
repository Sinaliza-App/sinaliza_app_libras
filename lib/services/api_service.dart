import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:sinaliza_app_libras/main.dart'; // Precisamos do navigatorKey

class ApiService {
  static const _storage = FlutterSecureStorage();

  static Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    final token = await _storage.read(key: 'jwt_token');
    
    final finalHeaders = headers ?? {};
    if (token != null) {
      finalHeaders['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(Uri.parse(url), headers: finalHeaders);
    _handleAuthErrors(response);
    return response;
  }

  static Future<http.Response> post(String url, {Map<String, String>? headers, Object? body}) async {
    final token = await _storage.read(key: 'jwt_token');
    
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
    final token = await _storage.read(key: 'jwt_token');
    
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
    final token = await _storage.read(key: 'jwt_token');
    
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
    await _storage.delete(key: 'jwt_token');
    
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sua sessão expirou. Por favor, faça login novamente.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
