// lib/pages/drawer.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../utils/safe_log.dart';
import 'auth.dart';
import 'home.dart';
import 'settings.dart';

class SorarenMainScaffold extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String role;
  final bool isActive;
  final DateTime loginTime;

  const SorarenMainScaffold({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.role,
    required this.isActive,
    required this.loginTime,
  });

  @override
  State<SorarenMainScaffold> createState() => _SorarenMainScaffoldState();
}

class _SorarenMainScaffoldState extends State<SorarenMainScaffold> {
  // Navigation State - Default to Index 0 (Suspect Identification)
  int _selectedIndex = 0;
  String _currentTitle = "Suspect Identification";

  static const Color _policeBlue = Color(0xFF1E3A8A);
  static const Color _drawerDark = Color(0xFF0F172A);
  static const Color _alertRed = Color(0xFFDC2626);

  final ApiService _api = ApiService();

  // Unified Page Mapping
  // Index 0: Suspect ID (Home), 1: Users, 2: Logs, 3: Blacklist, 4: Settings
  late final List<Widget> _pages = [
    const HomePageContent(),                          // Index 0
    const Center(child: Text("User Management Page")), // Index 1
    const Center(child: Text("Alert Logs Page")),      // Index 2
    const Center(child: Text("Blacklist Page")),       // Index 3
    const SettingsPage(),                             // Index 4
  ];

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('user_id');

    if (userId != null) {
      try { await _api.logoutServer(userId); } catch (e) { devLog('Logout error: $e'); }
    }

    await prefs.clear();
    await _api.localLogout();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _policeBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        title: Text(_currentTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [ IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout) ],
      ),
      drawer: _buildAppDrawer(),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildAppDrawer() {
    // Normalize role string to handle backend variations
    final String r = widget.role.toString().toLowerCase().trim();

    return Drawer(
      backgroundColor: _drawerDark,
      child: Column(
        children: [
          _buildDrawerHeader(),
          const Divider(color: Colors.white24, indent: 16, endIndent: 16),

          // 1. HOME / IDENTIFICATION (Replacing the old "Soraren Dashboard")
          _buildMenuItem(0, Icons.person_search, 'Suspect Identification'),

          // 2. USER MANAGEMENT (Superadmin Only)
          if (r == 'superadmin')
            _buildMenuItem(1, Icons.admin_panel_settings_outlined, 'User Management'),

          // 3. LOGS & BLACKLIST (Admin or Superadmin)
          if (r == 'admin' || r == 'superadmin') ...[
            _buildMenuItem(2, Icons.history_toggle_off, 'Alert Logs'),
            _buildMenuItem(3, Icons.person_off_outlined, 'Blacklist Management'),
          ],

          // 4. SETTINGS (All Users)
          _buildMenuItem(4, Icons.settings_outlined, 'Settings'),

          const Spacer(),
          _buildMenuItem(-1, Icons.logout, 'Logout', isLogout: true),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(color: _drawerDark),
      currentAccountPicture: const CircleAvatar(
        backgroundColor: Colors.white,
        child: Icon(Icons.local_police, color: _drawerDark, size: 40),
      ),
      accountName: Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      accountEmail: Text(widget.userEmail, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title, {bool isLogout = false}) {
    final bool isSelected = _selectedIndex == index;

    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.redAccent : (isSelected ? Colors.white : Colors.white60)),
      title: Text(
        title,
        style: TextStyle(
          color: isLogout ? Colors.redAccent : (isSelected ? Colors.white : Colors.white60),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        if (isLogout) {
          _handleLogout();
        } else {
          setState(() {
            _selectedIndex = index;
            _currentTitle = title;
          });
        }
      },
    );
  }
}