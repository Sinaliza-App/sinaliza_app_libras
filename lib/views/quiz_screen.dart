import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sinaliza_app_libras/constants.dart';
import 'package:sinaliza_app_libras/services/api_service.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';
import 'package:sinaliza_app_libras/widgets/animations/fade_in_slide.dart';
import 'package:confetti/confetti.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  // --- Estado do Quiz ---
  List<Map<String, dynamic>> _allSigns = [];
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  bool _isLoading = true;
  bool _showIntro = true;
  bool _isQuizFinished = false;
  bool _hasAnswered = false;
  int? _selectedAnswerIndex;
  int? _correctAnswerIndex;

  // --- Timer ---
  static const int _timePerQuestion = 12;
  int _secondsRemaining = _timePerQuestion;
  Timer? _timer;

  // --- Animações ---
  late AnimationController _progressController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late ConfettiController _confettiController;

  static const int _totalQuestions = 5;
  static const int _pointsPerCorrect = 5;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _timePerQuestion),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _fetchAndBuildQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    _shakeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // --- Lógica de Dados ---
  Future<void> _fetchAndBuildQuiz() async {
    try {
      final response = await ApiService.get('$apiBaseUrl/dictionary');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final signs = data.cast<Map<String, dynamic>>();

        // Filtra sinais com imagem (thumbnail ou example_image)
        final signsWithImage = signs.where((s) {
          final url = s['thumbnail_url'] ?? s['example_image_url'];
          return url != null && url.toString().isNotEmpty;
        }).toList();

        if (signsWithImage.length < 4) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Poucos sinais com imagem para gerar o quiz.')),
            );
            Navigator.pop(context);
          }
          return;
        }

        _allSigns = signsWithImage;
        _questions = _generateQuestions();
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro de conexão.')),
        );
        Navigator.pop(context);
      }
    }
  }

  List<Map<String, dynamic>> _generateQuestions() {
    final random = Random();
    final List<Map<String, dynamic>> questions = [];
    final List<Map<String, dynamic>> available = List.from(_allSigns);
    available.shuffle(random);

    final int count = min(_totalQuestions, available.length);

    for (int i = 0; i < count; i++) {
      final correctSign = available[i];
      final others = _allSigns.where((s) => s['id'] != correctSign['id']).toList();
      others.shuffle(random);

      final wrongOptions = others.take(3).toList();
      final allOptions = [...wrongOptions, correctSign];
      allOptions.shuffle(random);

      questions.add({
        'sign': correctSign,
        'options': allOptions,
        'correctIndex': allOptions.indexOf(correctSign),
      });
    }
    return questions;
  }

  // --- Timer ---
  void _startTimer() {
    _secondsRemaining = _timePerQuestion;
    _progressController.forward(from: 0);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          timer.cancel();
          _onTimeUp();
        }
      });
    });
  }

  void _onTimeUp() {
    if (_hasAnswered) return;
    setState(() {
      _hasAnswered = true;
      _correctAnswerIndex = _questions[_currentQuestionIndex]['correctIndex'];
    });
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 1500), _goToNext);
  }

  // --- Interação ---
  void _onAnswerSelected(int index) {
    if (_hasAnswered) return;
    _timer?.cancel();
    _progressController.stop();

    final question = _questions[_currentQuestionIndex];
    final bool isCorrect = index == question['correctIndex'];

    setState(() {
      _hasAnswered = true;
      _selectedAnswerIndex = index;
      _correctAnswerIndex = question['correctIndex'];
      if (isCorrect) {
        _score += _pointsPerCorrect;
        _correctAnswers++;
      }
    });

    if (isCorrect) {
      HapticFeedback.mediumImpact();
    } else {
      _shakeController.forward(from: 0);
      HapticFeedback.heavyImpact();
    }

    Future.delayed(const Duration(milliseconds: 1500), _goToNext);
  }

  void _goToNext() {
    if (!mounted) return;
    if (_currentQuestionIndex + 1 >= _questions.length) {
      _finishQuiz();
    } else {
      setState(() {
        _currentQuestionIndex++;
        _hasAnswered = false;
        _selectedAnswerIndex = null;
        _correctAnswerIndex = null;
      });
      _startTimer();
    }
  }

  Future<void> _finishQuiz() async {
    setState(() => _isQuizFinished = true);

    if (_correctAnswers > 0) {
      _confettiController.play();
    }

    try {
      await ApiService.post(
        '$apiBaseUrl/quiz/progress',
        body: json.encode({'score': _score}),
      );
    } catch (_) {}
  }

  void _startQuiz() {
    setState(() {
      _showIntro = false;
    });
    _startTimer();
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _score = 0;
      _correctAnswers = 0;
      _isQuizFinished = false;
      _hasAnswered = false;
      _selectedAnswerIndex = null;
      _correctAnswerIndex = null;
      _questions = _generateQuestions();
    });
    _startTimer();
  }

  // --- Resolve a URL da imagem ---
  String _getImageUrl(Map<String, dynamic> sign) {
    return (sign['thumbnail_url'] ?? sign['example_image_url'] ?? '').toString();
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBG,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.darkBG, AppColors.darkBG2],
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.neonGreen))
                : _showIntro
                    ? _buildIntroScreen()
                    : _isQuizFinished
                        ? _buildResultScreen()
                        : _buildQuestionScreen(),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.neonGreen,
                AppColors.neonBlue,
                AppColors.neonPurple,
                AppColors.neonOrange,
                AppColors.neonGold,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TELA DE INTRODUÇÃO ---
  Widget _buildIntroScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: FadeInSlide(
          duration: const Duration(milliseconds: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.neonPurple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.5), width: 2),
                ),
                child: const Icon(Icons.quiz_rounded, color: AppColors.neonPurple, size: 50),
              ),
              const SizedBox(height: 24),
              const Text(
                'QUIZ RÁPIDO',
                style: TextStyle(
                  color: AppColors.neonPurple,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Teste seus conhecimentos em Libras!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Regras
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    _ruleRow(Icons.help_outline_rounded, AppColors.neonBlue,
                        'Identifique o sinal mostrado na imagem'),
                    const SizedBox(height: 16),
                    _ruleRow(Icons.timer_rounded, AppColors.neonOrange,
                        '$_timePerQuestion segundos por questão'),
                    const SizedBox(height: 16),
                    _ruleRow(Icons.star_rounded, AppColors.neonGold,
                        '$_pointsPerCorrect XP por acerto'),
                    const SizedBox(height: 16),
                    _ruleRow(Icons.format_list_numbered_rounded, AppColors.neonGreen,
                        '$_totalQuestions questões no total'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Botão Iniciar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startQuiz,
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text(
                    'INICIAR QUIZ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 8,
                    shadowColor: AppColors.neonPurple.withValues(alpha: 0.4),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botão Voltar
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Voltar',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15),
          ),
        ),
      ],
    );
  }

  // --- TELA DE QUESTÃO ---
  Widget _buildQuestionScreen() {
    final question = _questions[_currentQuestionIndex];
    final sign = question['sign'] as Map<String, dynamic>;
    final options = question['options'] as List<Map<String, dynamic>>;
    final imageUrl = _getImageUrl(sign);

    return Column(
      children: [
        // --- AppBar Custom ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: 1.0 - _progressController.value,
                        backgroundColor: AppColors.cardDark,
                        color: _secondsRemaining <= 3 ? AppColors.neonRed : AppColors.neonGreen,
                        minHeight: 8,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (_secondsRemaining <= 3 ? AppColors.neonRed : AppColors.neonGreen)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _secondsRemaining <= 3 ? AppColors.neonRed : AppColors.neonGreen,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${_secondsRemaining}s',
                  style: TextStyle(
                    color: _secondsRemaining <= 3 ? AppColors.neonRed : AppColors.neonGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- Questão / Pontuação ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Questão ${_currentQuestionIndex + 1}/$_totalQuestions',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neonPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.neonPurple, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '$_score XP',
                      style: const TextStyle(
                        color: AppColors.neonPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // --- Pergunta ---
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Qual é o nome deste sinal?',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 20),

        // --- Imagem do Sinal ---
        FadeInSlide(
          duration: const Duration(milliseconds: 400),
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _hasAnswered && _selectedAnswerIndex != _correctAnswerIndex
                      ? sin(_shakeAnimation.value * pi * 3) * 8
                      : 0,
                  0,
                ),
                child: child,
              );
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _hasAnswered
                      ? (_selectedAnswerIndex == _correctAnswerIndex
                          ? AppColors.neonGreen
                          : AppColors.neonRed)
                      : AppColors.neonBlue.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_hasAnswered
                            ? (_selectedAnswerIndex == _correctAnswerIndex
                                ? AppColors.neonGreen
                                : AppColors.neonRed)
                            : AppColors.neonBlue)
                        .withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Center(child: Icon(Icons.image_not_supported, color: Colors.white38, size: 50)),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 2),
                          );
                        },
                      )
                    : imageUrl.isNotEmpty
                        ? Image.asset(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Icon(Icons.image_not_supported, color: Colors.white38, size: 50)),
                          )
                        : const Center(child: Icon(Icons.image_not_supported, color: Colors.white38, size: 50)),
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // --- Opções ---
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final bool isSelected = _selectedAnswerIndex == index;
                final bool isCorrect = _correctAnswerIndex == index;

                Color borderColor = AppColors.neonBlue.withValues(alpha: 0.3);
                Color bgColor = AppColors.cardDark;
                Color textColor = Colors.white;
                IconData? trailingIcon;

                if (_hasAnswered) {
                  if (isCorrect) {
                    borderColor = AppColors.neonGreen;
                    bgColor = AppColors.neonGreen.withValues(alpha: 0.1);
                    textColor = AppColors.neonGreen;
                    trailingIcon = Icons.check_circle_rounded;
                  } else if (isSelected && !isCorrect) {
                    borderColor = AppColors.neonRed;
                    bgColor = AppColors.neonRed.withValues(alpha: 0.1);
                    textColor = AppColors.neonRed;
                    trailingIcon = Icons.cancel_rounded;
                  } else {
                    borderColor = Colors.white.withValues(alpha: 0.05);
                    textColor = Colors.white38;
                  }
                }

                return FadeInSlide(
                  duration: Duration(milliseconds: 300 + (index * 80)),
                  yOffset: 15,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _hasAnswered ? null : () => _onAnswerSelected(index),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: borderColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(65 + index),
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  option['title'] ?? '',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (trailingIcon != null) Icon(trailingIcon, color: textColor, size: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- TELA DE RESULTADO ---
  Widget _buildResultScreen() {
    final double percentage = _correctAnswers / _questions.length;
    final String emoji;
    final String title;
    final Color accentColor;

    if (percentage == 1.0) {
      emoji = '🏆';
      title = 'PERFEITO!';
      accentColor = AppColors.neonGold;
    } else if (percentage >= 0.6) {
      emoji = '🔥';
      title = 'MUITO BOM!';
      accentColor = AppColors.neonGreen;
    } else if (percentage >= 0.3) {
      emoji = '💪';
      title = 'CONTINUE PRATICANDO!';
      accentColor = AppColors.neonOrange;
    } else {
      emoji = '📚';
      title = 'ESTUDE MAIS!';
      accentColor = AppColors.neonRed;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: FadeInSlide(
          duration: const Duration(milliseconds: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.1),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '+$_score XP',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _resultRow(
                      icon: Icons.check_circle_rounded,
                      iconColor: AppColors.neonGreen,
                      label: 'Acertos',
                      value: '$_correctAnswers / ${_questions.length}',
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    _resultRow(
                      icon: Icons.percent_rounded,
                      iconColor: AppColors.neonBlue,
                      label: 'Precisão',
                      value: '${(percentage * 100).toInt()}%',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: 'JOGAR NOVAMENTE',
                      color: accentColor,
                      icon: Icons.replay_rounded,
                      onPressed: _restartQuiz,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      label: 'VOLTAR',
                      color: Colors.white24,
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16)),
          ],
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: color == Colors.white24 ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
