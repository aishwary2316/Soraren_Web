import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:safe_device/safe_device.dart'; // Security Package
import 'pages/auth.dart'; // Your Auth Page
import 'utils/session_guard.dart'; // Session Management
import 'utils/safe_log.dart'; // Logging utility

void main() async {
  // 1. Ensure bindings are initialized for async security checks
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Default to "Secure"
  bool isDeviceSecure = true;

  // 3. PERFORM SECURITY CHECKS (Enforced in Release Mode)
  if (kReleaseMode) {
    try {
      // Check for Root (Android) or Jailbreak (iOS)
      bool isJailBroken = await SafeDevice.isJailBroken;

      // Check for Developer Options (Android Only)
      bool isDevMode = false;
      if (!kIsWeb && Platform.isAndroid) {
        isDevMode = await SafeDevice.isDevelopmentModeEnable;
      }

      // Lock app if security violations are found
      if (isJailBroken || isDevMode) {
        isDeviceSecure = false;
      }
    } catch (e) {
      devLog("Security check error: $e");
      // Fail closed for high-security environments
      isDeviceSecure = false;
    }
  }

  // 4. Run the App with Security Interlock
  runApp(isDeviceSecure ? const SorarenApp() : const SecurityViolationApp());
}

class SorarenApp extends StatelessWidget {
  const SorarenApp({super.key});

  // Global Navigator Key for SessionGuard to perform forced logouts
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Soraren', // Updated app name
      debugShowCheckedModeBanner: false,

      // Defining your "Blue and Red" Police Theme
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1E3A8A), // Deep Police Blue
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFFDC2626), // Alert Red
          error: const Color(0xFFB71C1C),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      builder: (context, child) {
        // Wrap Navigator in SessionGuard for inactivity tracking
        return SessionGuard(
          navigatorKey: navigatorKey,
          child: child!,
        );
      },

      home: const AuthPage(), // Initial Login Screen
    );
  }
}

// --- SECURITY VIOLATION SCREEN ---
// Blocks access if device is compromised
class SecurityViolationApp extends StatelessWidget {
  const SecurityViolationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFB71C1C), // Solid Red for Warning
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.gpp_bad_rounded, size: 100, color: Colors.white),
                SizedBox(height: 24),
                Text(
                  "ACCESS DENIED",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "Security Violation Detected",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                SizedBox(height: 30),
                Text(
                  "This device violates the security protocols required for the Soraren app.\n\n"
                      "• Root/Jailbreak detected\n"
                      "• Developer Options enabled",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}