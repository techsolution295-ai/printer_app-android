import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';
import 'package:smart_printer/screens/setting%20screen.dart';
import 'home_screen.dart';
import 'printables_screen.dart';
import 'files_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  Widget _page(int index) {
    switch (index) {
      case 0:
        return const PrinterHomeScreen();
      case 1:
        return const PrintablesScreen();
      case 2:
        return const FilesScreen();
      default:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeKey = context.locale.toString();
    return Scaffold(
      body: KeyedSubtree(
        key: ValueKey(localeKey),
        child: _page(_currentIndex),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),

        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,

        selectedItemColor: AppTheme.actionColor,
        unselectedItemColor: Colors.grey,

        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),

        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/home.png',
              width: 22,
              height: 22,
              color: _currentIndex == 0
                  ? AppTheme.actionColor
                  : Colors.grey,
            ),
            label: 'nav_home'.tr(context: context),
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded, size: 23),
            label: 'nav_printables'.tr(context: context),
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open_rounded, size: 23),
            label: 'nav_files'.tr(context: context),
          ),

          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/setting.png',
              width: 22,
              height: 22,
              color: _currentIndex == 3
                  ? AppTheme.actionColor
                  : Colors.grey,
            ),
            label: 'nav_settings'.tr(context: context),
          ),
        ],
      ),
    );
  }
}
