import 'package:flutter/material.dart';
import 'statistics_screen.dart';
import 'alerts_screen.dart';
import 'database_screen.dart';
import 'account_screen.dart';
import 'chat_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;

  // ✅ FIX: remove const from list — screens are not const constructible
  final List<Widget> _screens = [
    const StatisticsScreen(),
    const AlertsScreen(),
    const DatabaseScreen(),
    const AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6F6),
        elevation: 4,
        shadowColor: const Color(0xFFF6F6F6).withValues(alpha: 0.3),
        title: const Text(
          'Administration',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Color(0xFF0A3C6F),
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
      ),
      backgroundColor: const Color(0xFFF6F6F6),
      body: _screens[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
        },
        backgroundColor: const Color(0xFF168D8C),
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0A3C6F),
          unselectedItemColor: const Color(0xFF6EA1D4),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart, size: 24),
              activeIcon: Icon(Icons.bar_chart, size: 26),
              label: 'Statistiques',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications, size: 24),
              activeIcon: Icon(Icons.notifications, size: 26),
              label: 'Alertes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storage, size: 24),
              activeIcon: Icon(Icons.storage, size: 26),
              label: 'Base de données',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 24),
              activeIcon: Icon(Icons.person, size: 26),
              label: 'Compte',
            ),
          ],
        ),
      ),
    );
  }
}