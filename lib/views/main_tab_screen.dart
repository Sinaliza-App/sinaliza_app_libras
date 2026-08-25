import 'package:flutter/material.dart';
import 'package:sinaliza_app_libras/views/module_list_screen.dart';
import 'package:sinaliza_app_libras/views/dictionary_screen.dart';
import 'package:sinaliza_app_libras/views/quiz_screen.dart';
import 'package:sinaliza_app_libras/views/ranking_screen.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';

class MainTabScreen extends StatefulWidget {
  final int initialIndex;
  
  const MainTabScreen({super.key, this.initialIndex = 0});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  late int _currentIndex;

  final List<Widget> _screens = [
    const ModuleListScreen(),
    const DictionaryScreen(),
    const QuizScreen(),
    const RankingScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.cardDark,
          selectedItemColor: AppColors.neonGreen,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.school_rounded),
              label: 'Módulos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              label: 'Dicionário',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.quiz_rounded),
              label: 'Quiz',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_rounded),
              label: 'Ranking',
            ),
          ],
        ),
      ),
    );
  }
}
