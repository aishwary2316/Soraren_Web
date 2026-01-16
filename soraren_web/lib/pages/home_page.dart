// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'auth.dart';
import 'drawer.dart';
import 'user_management.dart';
import 'alert_logs.dart';
import 'blacklist_management.dart';
import 'settings.dart';
import 'profile.dart';
import '../utils/safe_log.dart';
import 'home.dart';

class HomePage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String role;
  final bool isActive;
  final DateTime loginTime;

  const HomePage({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.role,
    required this.isActive,
    required this.loginTime,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _headerBlue = Color(0xFF1E3A8A); // Updated to Police Blue
  late bool _isActive;
  int _selectedIndex = 0;

  // State variable to track the current page name in the Action Bar
  String _currentTitle = "Soraren Dashboard";

  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _isActive = widget.isActive;
  }

  /// Secure Logout: Clears server session and all local persistence keys.
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Retrieve the user_id (the key used in auth.dart)
    final String? userId = prefs.getString('user_id');

    if (userId != null && userId.isNotEmpty) {
      try {
        // Notifies the Render backend to terminate the session
        await _api.logoutServer(userId);
      } catch (e) {
        devLog('Server logout failed: $e. Proceeding with local logout.');
      }
    }

    // Comprehensive clear of all session-related keys used in auth.dart
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('user_is_active');
    await prefs.remove('user_login_time');

    // Clears the JWT from secure storage
    await _api.localLogout();

    if (!mounted) return;

    // Redirect to login and clear the navigation stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
          (route) => false,
    );
  }

  // The pages corresponding to the drawer options
  late final List<Widget> _pages = [
    const HomePageContent(),
    //UserManagementPage(role: widget.role),
    //const AlertLogsPage(),
    //BlacklistManagementPage(role: widget.role),
    const SettingsPage(),
  ];

  /// Callback triggered by the Drawer when an item is tapped.
  /// It updates the selected index and the Action Bar title.
  void _onSelect(BuildContext context, int index, String label) {
    setState(() {
      _selectedIndex = index;
      _currentTitle = label; // Dynamic title update
    });
    Navigator.pop(context); // Close the drawer
  }

  /// Profile/Settings menu logic
  Future<void> _showCustomMenu(BuildContext context) async {
    final media = MediaQuery.of(context);
    final double top = media.padding.top + kToolbarHeight;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(media.size.width - 220, top, 12, 0),
      items: <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'profile',
          child: _MenuRow(Icons.person, 'Profile'),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: _MenuRow(Icons.settings, 'Settings'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: _MenuRow(Icons.logout, 'Logout', color: Colors.red),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    if (selected == 'settings') {
      setState(() {
        _selectedIndex = 4;
        _currentTitle = "Settings";
      });
    } else if (selected == 'profile') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    } else if (selected == 'logout') {
      _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    // REFACTOR: Removed MaterialApp to fix "Dual Action Bar" and use global context.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _headerBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        // The title now changes dynamically based on drawer selection
        title: Text(
          _currentTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showCustomMenu(context),
          ),
        ],
      ),
      drawer: AppDrawer(
        userName: widget.userName,
        userEmail: widget.userEmail,
        role: widget.role,
        selectedIndex: _selectedIndex,
        isActive: _isActive,
        onSelect: _onSelect, // Connects the drawer to title management
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),
    );
  }
}

/// Helper widget for the custom popup menu items
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuRow(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? Colors.black87),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(color: color ?? Colors.black87, fontSize: 15)),
      ],
    );
  }
}