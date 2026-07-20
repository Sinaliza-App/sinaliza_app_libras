import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:convert';

// Imports do seu projeto
import 'package:sinaliza_app_libras/providers/user_provider.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:sinaliza_app_libras/constants.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;


  // Lista de conquistas
  final List<Map<String, dynamic>> _badges = [
    {
      'title': 'Aprendiz',
      'xpRequired': 10,
      'icon': Icons.star_rounded,
      'color': AppColors.neonBlue,
    },
    {
      'title': 'Curioso',
      'xpRequired': 100,
      'icon': Icons.visibility,
      'color': AppColors.neonGreen,
    },
    {
      'title': 'Dedicado',
      'xpRequired': 300,
      'icon': Icons.local_fire_department_rounded,
      'color': AppColors.neonRed,
    },
    {
      'title': 'Avançado',
      'xpRequired': 600,
      'icon': Icons.workspace_premium_rounded,
      'color': Colors.amber,
    },
    {
      'title': 'Mestre',
      'xpRequired': 1100,
      'icon': Icons.diamond_rounded,
      'color': Colors.purpleAccent,
    },
  ];

  Map<String, dynamic> _calculateLevel(int totalScore) {
    int level = 1;
    int nextLevelScore = 100;
    double progress = 0.0;

    if (totalScore < 100) {
      level = 1;
      nextLevelScore = 100;
      progress = totalScore / 100;
    } else if (totalScore < 300) {
      level = 2;
      nextLevelScore = 300;
      progress = (totalScore - 100) / (300 - 100);
    } else if (totalScore < 600) {
      level = 3;
      nextLevelScore = 600;
      progress = (totalScore - 300) / (600 - 300);
    } else {
      level = 4 + ((totalScore - 600) ~/ 500); // Nível infinito a cada 500xp
      nextLevelScore = (level - 3) * 500 + 600;
      progress = 1.0; // Ou lógica complexa, mas pra MVP tá ótimo
    }

    return {
      'level': level,
      'nextLevelScore': nextLevelScore,
      'progress': progress.clamp(0.0, 1.0), // Garante entre 0 e 1
    };
  } 

  Widget _buildBadgesGrid(int userXp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "MINHAS CONQUISTAS",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _badges.length,
          itemBuilder: (context, index) {
            final badge = _badges[index];
            final bool isUnlocked = userXp >= badge['xpRequired'];
            final Color badgeColor = badge['color'];
            
            return Container(
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUnlocked ? badgeColor.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: badgeColor.withValues(alpha: 0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        badge['icon'],
                        color: isUnlocked ? badgeColor : Colors.grey.withValues(alpha: 0.2),
                        size: 36,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        badge['title'],
                        style: TextStyle(
                          color: isUnlocked ? Colors.white : Colors.grey.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${badge['xpRequired']} XP",
                        style: TextStyle(
                          color: isUnlocked ? badgeColor : Colors.grey.withValues(alpha: 0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (!isUnlocked)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.lock_rounded,
                        color: Colors.grey.withValues(alpha: 0.4),
                        size: 14,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshUserData();
  }

  Future<void> _refreshUserData() async {
    setState(() {
      _isLoading = true;
    });

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final String apiUrl = '$apiBaseUrl/users/me';
    try {
      final response = await ApiService.get(apiUrl);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        // Garante que o total_score seja lido corretamente mesmo se vier null ou string
        if (userData['total_score'] != null) {
             userData['total_score'] = int.tryParse(userData['total_score'].toString()) ?? 0;
        }
        Provider.of<UserProvider>(context, listen: false).setUser(userData);
      }
    } catch (e) {
      debugPrint("Erro ao atualizar perfil: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;
    
    // Recortar imagem (e comprimir)
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Ajuste sua Foto',
          toolbarColor: AppColors.cardDark,
          toolbarWidgetColor: AppColors.neonGreen,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
          activeControlsWidgetColor: AppColors.neonGreen,
          dimmedLayerColor: AppColors.darkBG.withValues(alpha: 0.8),
          backgroundColor: AppColors.darkBG,
          cropFrameColor: AppColors.neonGreen,
          cropGridColor: AppColors.neonGreen.withValues(alpha: 0.5),
        ),
        IOSUiSettings(
          title: 'Recortar Foto',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
      compressQuality: 40,
      maxWidth: 400,
      maxHeight: 400,
    );

    if (croppedFile == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final bytes = await croppedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final response = await ApiService.put(
        '$apiBaseUrl/users/me',
        body: json.encode({'profile_picture': base64Image}),
      );
      
      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto atualizada!"), backgroundColor: AppColors.neonGreen));
          _refreshUserData();
        } else {
          debugPrint("Erro ${response.statusCode}: ${response.body}");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: ${response.statusCode}"), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      debugPrint("Erro ao enviar foto: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NOVA FUNÇÃO: EDITAR NOME (LÁPIS) ---
  Future<void> _editName() async {
    final TextEditingController nameCtrl = TextEditingController();
    
    // Mostra o diálogo para digitar
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text("Alterar Nome", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppColors.neonGreen,
          decoration: const InputDecoration(
            labelText: "Novo Nome",
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.neonGreen)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.neonBlue)),
          ),
        ),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(context), 
             child: const Text("Cancelar", style: TextStyle(color: Colors.white54))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameCtrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonGreen, foregroundColor: Colors.black),
            child: const Text("Salvar"),
          ),
        ],
      ),
    );

    if (newName == null || newName.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.put(
        '$apiBaseUrl/users/me',
        body: json.encode({'name': newName}),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nome atualizado!"), backgroundColor: AppColors.neonGreen));
          _refreshUserData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nome já existente."), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      debugPrint("Erro edit name: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NOVA FUNÇÃO: EXCLUIR CONTA (LIXEIRA) ---
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text("Excluir Conta?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Tem certeza? Todo seu progresso e XP serão perdidos para sempre.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("EXCLUIR", style: TextStyle(color: AppColors.neonRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    
    try {
      await ApiService.delete('$apiBaseUrl/users/me');
      
      if (mounted) _logout(context);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _storage.delete(key: 'jwt_token');
    
    if (!context.mounted) return;
    Provider.of<UserProvider>(context, listen: false).clearUser();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.darkBG, AppColors.darkBG2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- HEADER PERSONALIZADO ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botão Voltar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    
                    // Título
                    const Text(
                      "MEU PERFIL",
                      style: TextStyle(
                        color: AppColors.neonGreen, 
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: 1.5,
                      ),
                    ),
                    
                    // --- AQUI ESTÁ A LIXEIRA (DELETE) ---
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.neonRed.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.neonRed),
                        onPressed: _deleteAccount,
                        tooltip: "Excluir Conta",
                      ),
                    ),
                  ],
                ),
              ),

              // --- CONTEÚDO DA TELA ---
              Expanded(
                child: _isLoading && user == null
                    ? const Center(child: CircularProgressIndicator(color: AppColors.neonGreen))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 40 * (1 - value)),
                              child: Opacity(
                                opacity: value.clamp(0.0, 1.0),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            children: [
                            const SizedBox(height: 10),

                            // 1. AVATAR
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: AppColors.cardDark,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.neonGreen, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.neonGreen.withValues(alpha: 0.4),
                                          blurRadius: 16,
                                        ),
                                      ],
                                      image: () {
                                        if (user?.profilePicture != null && user!.profilePicture!.isNotEmpty) {
                                          try {
                                            String base64Str = user.profilePicture!;
                                            if (base64Str.contains(',')) {
                                              base64Str = base64Str.split(',').last;
                                            }
                                            base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
                                            while (base64Str.length % 4 != 0) {
                                              base64Str += '=';
                                            }
                                            return DecorationImage(
                                              image: MemoryImage(base64Decode(base64Str)),
                                              fit: BoxFit.cover,
                                            );
                                          } catch (e) {
                                            return null;
                                          }
                                        }
                                        return null;
                                      }(),
                                    ),
                                    child: (user?.profilePicture == null || user!.profilePicture!.isEmpty)
                                        ? const Icon(Icons.person, color: Colors.white, size: 60)
                                        : null,
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.neonGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      (user?.profilePicture != null && user!.profilePicture!.isNotEmpty)
                                          ? Icons.edit
                                          : Icons.camera_alt,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            // 2. NOME (COM LÁPIS) E EMAIL
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  user?.name ?? 'Usuário',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                // --- AQUI ESTÁ O LÁPIS (EDITAR) ---
                                IconButton(
                                  icon: const Icon(Icons.edit, color: AppColors.neonBlue, size: 20),
                                  onPressed: _editName,
                                  tooltip: "Editar Nome",
                                )
                              ],
                            ),
                            
                            const SizedBox(height: 0),
                            Text(
                              user?.email ?? 'email@exemplo.com',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 30),

                            // --- NOVO: CARTÃO DE OFENSIVA (FOGUINHO) ---
                            Builder(
                              builder: (context) {
                                final int streak = user?.streakCount ?? 0;
                                final bool isLit = streak > 0;
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isLit 
                                          ? [Colors.deepOrange.withValues(alpha: 0.2), Colors.orange.withValues(alpha: 0.05)]
                                          : [Colors.grey.withValues(alpha: 0.1), AppColors.cardDark],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isLit ? Colors.deepOrange.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
                                      width: 1.5
                                    ),
                                    boxShadow: isLit ? [
                                      BoxShadow(
                                        color: Colors.deepOrange.withValues(alpha: 0.15),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ] : [],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        color: isLit ? Colors.deepOrange : Colors.grey,
                                        size: 50,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isLit ? "$streak DIAS SEGUIDOS!" : "0 DIAS",
                                              style: TextStyle(
                                                color: isLit ? Colors.orange : Colors.grey,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isLit 
                                                ? "Você está pegando fogo! Continue assim." 
                                                : "Faça uma lição hoje para acender sua ofensiva!",
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.7),
                                                fontSize: 13,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            ),

                            const SizedBox(height: 20),

                            // 3. CARD DE NÍVEL E XP (ATUALIZADO)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.neonBlue.withValues(alpha: 0.3),
                                  width: 1.5
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Builder(
                                builder: (context) {
                                  final stats = _calculateLevel(user?.totalScore ?? 0);
                                  final int level = stats['level'];
                                  final double progress = stats['progress'];
                                  final int nextScore = stats['nextLevelScore'];
                                  
                                  return Column(
                                    children: [
                                      // Título do Nível
                                      Text(
                                        "NÍVEL $level",
                                        style: const TextStyle(
                                          color: AppColors.neonBlue,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      
                                      // XP Grande
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            "${user?.totalScore ?? 0}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 42,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "/ $nextScore XP",
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.4),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 16),

                                      // Barra de Progresso do Nível
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 12,
                                          backgroundColor: Colors.black,
                                          color: AppColors.neonGreen,
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 8),
                                      Text(
                                        "Faltam ${nextScore - (user?.totalScore ?? 0)} XP para o próximo nível",
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              ),
                            ),
                            const SizedBox(height: 30),

                            // --- GRID DE CONQUISTAS ---
                            _buildBadgesGrid(user?.totalScore ?? 0),
                            const SizedBox(height: 40),

                            // 4. BOTÃO DE LOGOUT
                            InkWell(
                              onTap: () => _logout(context),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                height: 60,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.neonRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.neonRed.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.logout_rounded, color: AppColors.neonRed),
                                    SizedBox(width: 12),
                                    Text(
                                      "Sair da Conta",
                                      style: TextStyle(
                                        color: AppColors.neonRed,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
            ],
          ),
        ),
      ),
    );
  }
}