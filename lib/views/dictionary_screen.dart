import 'package:flutter/material.dart';
import 'package:sinaliza_app_libras/services/api_service.dart';
import 'package:sinaliza_app_libras/views/lesson_detail_screen.dart';
import 'dart:convert';
import 'package:sinaliza_app_libras/constants.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  // Cores Neon (mesmo padrão)
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color neonBlue = Color(0xFF00D1FF);
  static const Color bgDark = Color(0xFF02040A);
  static const Color cardDark = Color(0xFF07101F);

  List<dynamic> _allSigns = [];
  List<dynamic> _filteredSigns = [];
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDictionary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<void> _fetchDictionary() async {
    try {
      final response = await ApiService.get('$apiBaseUrl/dictionary');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _allSigns = data;
            _filteredSigns = data;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Erro ao carregar dicionário');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro de conexão ao carregar o dicionário.')),
        );
      }
    }
  }

  void _filterSigns(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSigns = _allSigns;
      } else {
        _filteredSigns = _allSigns.where((sign) {
          final title = (sign['title'] ?? '').toString().toLowerCase();
          return title.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _filterSigns("");
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'DICIONÁRIO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Barra de Busca
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSigns,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: cardDark,
                hintText: 'Pesquisar sinal (ex: Bom dia)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.search, color: neonGreen),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: _clearSearch,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: neonGreen.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: neonGreen, width: 2),
                ),
              ),
            ),
          ),
          
          // Lista de Sinais
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: neonGreen))
                : _filteredSigns.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty ? Icons.menu_book_rounded : Icons.search_off_rounded,
                              size: 80,
                              color: neonGreen.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _searchQuery.isEmpty 
                                  ? 'Nenhum sinal encontrado no banco de dados.'
                                  : 'Nenhum sinal para "$_searchQuery"',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: _filteredSigns.length,
                        itemBuilder: (context, index) {
                          final sign = _filteredSigns[index];
                          
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 30 * (1 - value)),
                                child: Opacity(
                                  opacity: value,
                                  child: child,
                                ),
                              );
                            },
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => _DictionaryZoomScreen(sign: sign, index: index),
                                  ),
                                );
                              },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                              color: cardDark,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: neonBlue.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Imagem do Sinal
                                  Hero(
                                    tag: 'sign_image_${sign['id'] ?? index}',
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: neonBlue.withValues(alpha: 0.5)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: _ImageLoader(
                                          url: sign['thumbnail_url'] ?? sign['example_image_url'],
                                          isThumbnail: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  
                                  // Textos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sign['title'] ?? 'Sem Título',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: const [
                                            Icon(
                                              Icons.touch_app_rounded,
                                              color: neonGreen,
                                              size: 16,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Sinal Prático',
                                              style: TextStyle(
                                                color: neonGreen,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                      ),
          ),
        ],
      ),
    );
  }
}

// --- TELA DE DETALHES DO DICIONÁRIO (ZOOM) ---
class _DictionaryZoomScreen extends StatelessWidget {
  final Map<String, dynamic> sign;
  final int index;

  const _DictionaryZoomScreen({required this.sign, required this.index});

  @override
  Widget build(BuildContext context) {
    const Color neonGreen = Color(0xFF00FF9D);
    const Color darkBG = Color(0xFF02040A);
    const Color cardDark = Color(0xFF050C1A);

    final String title = sign['title'] ?? 'Sem Título';
    final String description = sign['description'] ?? 'Sem descrição disponível.';
    final String? imageUrl = sign['example_image_url'];

    return Scaffold(
      backgroundColor: darkBG,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [darkBG, Color.fromARGB(255, 7, 19, 44)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "DICIONÁRIO DE LIBRAS",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: const TextStyle(
                    color: neonGreen,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // CARTÃO DA IMAGEM
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: neonGreen.withValues(alpha: 0.05),
                          blurRadius: 30,
                          spreadRadius: 0,
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 250,
                          width: 250,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(24), 
                          ),
                          child: sign['gif_url'] != null || (imageUrl != null && imageUrl.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Hero(
                                    tag: 'sign_image_${sign['id'] ?? index}',
                                    child: _ImageLoader(
                                      url: sign['gif_url'] ?? imageUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.front_hand, size: 80, color: Colors.white54),
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            description,
                            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Botão Praticar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LessonDetailScreen(lesson: sign),
                                ),
                              );
                            },
                            icon: const Icon(Icons.camera_alt, color: Color(0xFF02040A)), // darkBG
                            label: const Text(
                              'PRATICAR ESTE SINAL',
                              style: TextStyle(
                                color: Color(0xFF02040A), // darkBG
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FF9D), // neonGreen
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 10,
                              shadowColor: const Color(0xFF00FF9D).withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- WIDGET HELPER PARA IMAGENS E GIFS ---
class _ImageLoader extends StatelessWidget {
  final dynamic url;
  final bool isThumbnail;
  final BoxFit fit;

  const _ImageLoader({required this.url, this.isThumbnail = false, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (url == null || url.toString().isEmpty) {
      return const Icon(Icons.image_not_supported, color: Colors.grey);
    }
    
    final String urlStr = url.toString();
    
    if (urlStr.startsWith('http')) {
      return Image.network(
        urlStr,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
      );
    } else {
      return Image.asset(
        urlStr,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
  }
}
