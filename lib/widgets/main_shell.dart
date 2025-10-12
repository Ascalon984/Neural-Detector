import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bottom_nav_bar.dart';
import '../screens/home_screen.dart';
import '../screens/text_editor.dart';
import '../screens/file_upload.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/theme_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize page controller if needed
  }

  void _onTap(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          HomeScreen(onNavTap: _onTap, currentIndex: _currentIndex),
          const TextEditorScreen(),
          const FileUploadScreen(),
          // Camera screen removed
          const HistoryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}