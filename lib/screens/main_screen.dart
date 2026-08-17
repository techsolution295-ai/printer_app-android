import 'package:flutter/material.dart';
import 'package:smart_printer/screens/setting%20screen.dart';
import 'home_screen.dart';
import 'files_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    PrinterHomeScreen(),
    FilesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),

        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,

        selectedItemColor: const Color(0xFF2979FF),
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
                  ? const Color(0xFF2979FF)
                  : Colors.grey,
            ),
            label: 'Home',
          ),

          const BottomNavigationBarItem(
            icon: Icon(Icons.folder_open_rounded, size: 23),
            label: 'Files',
          ),

          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/setting.png',
              width: 22,
              height: 22,
              color: _currentIndex == 2
                  ? const Color(0xFF2979FF)
                  : Colors.grey,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
