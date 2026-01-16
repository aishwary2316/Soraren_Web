// lib/pages/drawer.dart
import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String role;
  final int selectedIndex;
  final bool isActive;
  final Function(BuildContext, int, String) onSelect;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.role,
    required this.selectedIndex,
    required this.isActive,
    required this.onSelect,
  });

  static const Color _drawerBlue = Color(0xFF0F172A); // Professional Dark Blue
  static const Color _alertRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final String r = role.toLowerCase().trim();

    // Use fixed indices so parent/state management can keep using same indices
    // 0: Dashboard
    // 1: User Management
    // 2: Alert Logs
    // 3: Blacklist Management
    // 4: Settings

    // Build visible item list according to role
    final List<_MenuEntry> items = [];

    // Dashboard always available to all roles per requirement (but user only sees dashboard)
    if (r == 'user' || r == 'admin' || r == 'superadmin') {
      items.add(_MenuEntry(index: 0, icon: Icons.dashboard_outlined, title: 'Soraren Dashboard'));
    }

    // User management only for superadmin
    if (r == 'superadmin') {
      items.add(_MenuEntry(index: 1, icon: Icons.admin_panel_settings_outlined, title: 'User Management'));
    }

    // Admin and superadmin get Alert Logs and Blacklist
    if (r == 'admin' || r == 'superadmin') {
      items.add(_MenuEntry(index: 2, icon: Icons.history_toggle_off, title: 'Alert Logs'));
      items.add(_MenuEntry(index: 3, icon: Icons.person_off_outlined, title: 'Blacklist Management'));
    }

    // Settings visible only to superadmin in original mapping; change here if you want it available to others
    if (r == 'superadmin') {
      items.add(_MenuEntry(index: 4, icon: Icons.settings_outlined, title: 'Settings'));
    }

    return Drawer(
      backgroundColor: _drawerBlue,
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(color: Colors.white24, indent: 16, endIndent: 16),
          // menu items
          ...items.map((e) => _buildMenuItem(context, e.index, e.icon, e.title)).toList(),
          const Spacer(),
          const Divider(color: Colors.white24, indent: 16, endIndent: 16),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(color: _drawerBlue),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        child: Icon(Icons.local_police, color: _drawerBlue, size: 40),
      ),
      accountName: Text(
        userName,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      accountEmail: Row(
        children: [
          Expanded(
            child: Text(userEmail, style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isActive ? Colors.green : _alertRed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isActive ? "ACTIVE" : "INACTIVE",
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, int index, IconData icon, String title) {
    final bool isSelected = selectedIndex == index;

    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white60),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white60,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.06),
      onTap: () {
        // Close drawer first, then invoke parent navigation callback.
        // Using a microtask ensures the pop starts before the parent navigation runs.
        Navigator.of(context).pop();
        Future.microtask(() => onSelect(context, index, title));
      },
    );
  }
}

// Small internal helper to keep menu definitions clean
class _MenuEntry {
  final int index;
  final IconData icon;
  final String title;
  const _MenuEntry({required this.index, required this.icon, required this.title});
}
