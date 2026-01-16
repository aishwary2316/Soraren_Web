// lib/pages/auth.dart

import 'dart:ui'; // Required for ImageFilter (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart'; // Ensure local_auth: ^3.0.0 is in pubspec.yaml

import '../utils/safe_log.dart';
import '../services/api_service.dart';
import '../utils/validators.dart';
import '../utils/safe_error.dart';
import 'home_page.dart';

class AuthPage extends StatefulWidget {
  final String? sessionExpiredMessage;

  const AuthPage({super.key, this.sessionExpiredMessage});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  Widget build(BuildContext context) {
    return LoginPage(sessionExpiredMessage: widget.sessionExpiredMessage);
  }
}

class LoginPage extends StatefulWidget {
  final String? sessionExpiredMessage;

  const LoginPage({super.key, this.sessionExpiredMessage});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ApiService api = ApiService();
  final LocalAuthentication auth = LocalAuthentication();

  // SECURITY CONTROL: Toggle to 'true' to re-enable Biometrics later
  final bool _isBiometricEnabled = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  // --- SORAREN POLICE THEME COLORS (BLUE & RED) ---
  final Color _policeBlue = const Color(0xFF1E3A8A); // Deep Police Blue
  final Color _policeBlueSecondary = const Color(0xFF1E3A8A).withOpacity(0.25);
  final Color _alertRed = const Color(0xFFDC2626); // Alert Red Accent
  final Color _alertRedSecondary = const Color(0xFFDC2626).withOpacity(0.25);
  final Color _inputFillColor = const Color(0xFF64B5F6).withOpacity(0.15);

  @override
  void initState() {
    super.initState();
    // Handle SessionGuard automatic logouts
    if (widget.sessionExpiredMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.sessionExpiredMessage!,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: _alertRed,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: 'DISMISS',
                textColor: Colors.white,
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ),
          );
        }
      });
    }
  }

  /// Development shortcut for testing UI
  Future<void> _tempSignIn() async {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(
          userName: "Test Officer",
          userEmail: "admin_test",
          role: "superadmin",
          isActive: true,
          loginTime: DateTime.now(),
        ),
      ),
    );
  }

  /// Main Secure Authentication Process
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    // 1. BIOMETRIC INTERLOCK (Fixed for local_auth ^3.0.0)
    if (_isBiometricEnabled) {
      try {
        final bool canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
        if (canCheck) {
          bool authenticated = await auth.authenticate(
            localizedReason: 'Officer identity verification required',

            biometricOnly: true,
            persistAcrossBackgrounding: true,
          );
          if (!authenticated) {
            setState(() {
              _error = 'Biometric authentication failed';
              _loading = false;
            });
            return;
          }
        }
      } catch (e) {
        devLog('Biometric Exception: $e');
        setState(() {
          _error = 'Security hardware unavailable';
          _loading = false;
        });
        return;
      }
    }

    // 2. BACKEND LOGIN (Integrated with new Render backend)
    final userId = _userIdController.text.trim();
    final password = _passwordController.text;

    try {
      final result = await api.login(userId, password);

      if (result['ok'] == true) {
        final data = result['data'] ?? {};
        final prefs = await SharedPreferences.getInstance();

        // PERSIST SESSION LOCALLY
        await prefs.setString('user_id', userId);
        await prefs.setString('user_name', data['name'] ?? 'Officer');
        await prefs.setString('user_role', data['role'] ?? 'user');
        await prefs.setString('user_login_time', DateTime.now().toIso8601String());

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(
              userName: data['name'] ?? 'Officer',
              userEmail: userId,
              role: data['role'] ?? 'user',
              isActive: true,
              loginTime: DateTime.now(),
            ),
          ),
        );
      } else {
        setState(() => _error = result['message'] ?? 'Access Denied');
      }
    } catch (e) {
      setState(() => _error = SafeError.format(e)); // Sanitize errors for production
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // --- TOP DESIGN LAYERS (POLICE BLUE) ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.42,
            child: ClipPath(
              clipper: TopShapeClipperBack(),
              child: Container(color: _policeBlueSecondary),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.40,
            child: ClipPath(
              clipper: TopShapeClipperFront(),
              child: Container(
                color: _policeBlue,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.security, size: 85, color: Colors.white),
                      const SizedBox(height: 10),
                      const Text(
                        'SORAREN',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 4.0,
                        ),
                      ),
                      const Text(
                        'Department of Police',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- BOTTOM DESIGN LAYERS (ALERT RED) ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.24,
            child: ClipPath(
              clipper: BottomTriangleClipper(),
              child: Container(color: _alertRedSecondary),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.20,
            child: ClipPath(
              clipper: BottomTriangleClipper(),
              child: Container(color: _alertRed),
            ),
          ),

          // --- GLASSMORPHISM LAYER (Appears on keyboard focus) ---
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isKeyboardOpen ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !isKeyboardOpen,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(color: Colors.white.withOpacity(0.3)),
                ),
              ),
            ),
          ),

          // --- MAIN CONTENT ---
          Positioned.fill(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: size.height * 0.2),

                      // USER ID INPUT
                      TextFormField(
                        controller: _userIdController,
                        validator: (v) => Validators.validateSafeText(v, fieldName: 'User ID'),
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                        decoration: _inputDecoration('User ID', Icons.badge_outlined),
                      ),

                      const SizedBox(height: 20),

                      // PASSWORD INPUT
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        validator: (v) => (v == null || v.isEmpty) ? 'Password required' : null,
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                        decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off, color: _policeBlue),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 15),
                        Text(_error!, style: TextStyle(color: _alertRed, fontWeight: FontWeight.bold)),
                      ],

                      const SizedBox(height: 40),

                      // AUTHORIZATION BUTTON
                      InkWell(
                        onTap: _loading ? null : _signIn,
                        onLongPress: _tempSignIn, // Dev bypass
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _policeBlue,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(color: _policeBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                            ],
                          ),
                          child: Center(
                            child: _loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                              'AUTHORIZE ACCESS',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _policeBlue, fontWeight: FontWeight.bold),
      prefixIcon: Icon(icon, color: _policeBlue),
      filled: true,
      fillColor: _inputFillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: _policeBlue, width: 2)),
    );
  }
}

// --- CUSTOM CLIPPERS (Tiered Design) ---

class TopShapeClipperFront extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(size.width / 2, size.height + 40, size.width, size.height - 60);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> old) => false;
}

class TopShapeClipperBack extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(size.width / 2, size.height + 60, size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> old) => false;
}

class BottomTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(0, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> old) => false;
}