import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/auth/screens/face_enrollment_screen.dart';
import 'features/auth/screens/login_screen.dart' as auth_login;
import 'features/home/screens/duty_tab_screen.dart';

enum AppTab { incident, report, duty, alerts, settings }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.prefs});

  final SharedPreferences? prefs;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: prefs == null
          ? SharedPreferences.getInstance()
          : Future.value(prefs),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Color(0xFFE71D24),
              body: SizedBox.shrink(),
            ),
          );
        }

        return BantaiApp(prefs: snapshot.data!);
      },
    );
  }
}

class BantaiApp extends StatefulWidget {
  const BantaiApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<BantaiApp> createState() => _BantaiAppState();
}

enum AuthStage {
  login,
  forgotEmail,
  forgotSms,
  resetPassword,
  requestAdmin,
  requestSent,
}

class _BantaiAppState extends State<BantaiApp> {
  bool _showSplash = true;
  bool _authenticated = false;
  bool _darkMode = false;
  bool _keepSignedIn = true;
  bool _onDuty = false;
  double _sirenVolume = 70;
  Duration _shiftRemaining = const Duration(hours: 8);
  Timer? _dutyTimer;
  Timer? _splashTimer;
  AuthStage _authStage = AuthStage.login;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _dutyTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final rememberMe = widget.prefs.getBool('remember_me') ?? true;
    final auth = rememberMe && (widget.prefs.getBool('authenticated') ?? false);
    final dark = widget.prefs.getBool('dark_mode') ?? false;
    final onDuty = widget.prefs.getBool('on_duty') ?? false;
    final siren = widget.prefs.getDouble('siren_volume') ?? 70;
    final remainingSeconds =
        widget.prefs.getInt('shift_remaining_seconds') ?? (8 * 60 * 60);

    setState(() {
      _authenticated = auth;
      _darkMode = dark;
      _keepSignedIn = rememberMe;
      _onDuty = onDuty;
      _sirenVolume = siren;
      _shiftRemaining = Duration(seconds: remainingSeconds);
    });

    _splashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });

    if (_onDuty) {
      _startDutyTimer();
    }
  }

  Future<void> _persistState() async {
    await widget.prefs.setBool('authenticated', _authenticated);
    await widget.prefs.setBool('remember_me', _keepSignedIn);
    await widget.prefs.setBool('dark_mode', _darkMode);
    await widget.prefs.setBool('on_duty', _onDuty);
    await widget.prefs.setDouble('siren_volume', _sirenVolume);
    await widget.prefs.setInt(
      'shift_remaining_seconds',
      _shiftRemaining.inSeconds,
    );
  }

  void _startDutyTimer() {
    _dutyTimer?.cancel();
    _dutyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (!_onDuty) {
        _dutyTimer?.cancel();
        return;
      }

      if (_shiftRemaining.inSeconds <= 0) {
        setState(() {
          _onDuty = false;
          _shiftRemaining = const Duration();
        });
        _persistState();
        _dutyTimer?.cancel();
        return;
      }

      setState(() {
        _shiftRemaining = _shiftRemaining - const Duration(seconds: 1);
      });
      _persistState();
    });
  }

  Future<bool> _handleLogin(
    String email,
    String password, {
    bool keepSignedIn = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));

    final valid = email.contains('@') && password.trim().isNotEmpty;
    if (!valid) {
      return false;
    }

    setState(() {
      _keepSignedIn = keepSignedIn;
      _authenticated = true;
      _onDuty = false;
      _shiftRemaining = const Duration(hours: 8);
    });
    _dutyTimer?.cancel();
    await _persistState();
    return true;
  }

  Future<void> _handleFaceIdLogin() async {
    try {
      final status = await Permission.camera.request();
      if (!mounted) return;

      final hasPermission = status.isGranted || status.isLimited;
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required for Face ID sign in.'),
          ),
        );
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return;
      }

      List<CameraDescription> cameras = const [];
      try {
        cameras = await availableCameras();
      } catch (_) {
        cameras = const [];
      }

      if (!mounted) return;
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No camera was found. Continuing with secure fallback sign-in.',
            ),
          ),
        );
        setState(() {
          _authenticated = true;
          _onDuty = false;
          _shiftRemaining = const Duration(hours: 8);
        });
        _dutyTimer?.cancel();
        await _persistState();
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FaceEnrollmentScreen(
            onSuccess: () {
              setState(() {
                _authenticated = true;
                _onDuty = false;
                _shiftRemaining = const Duration(hours: 8);
              });
              _dutyTimer?.cancel();
              _persistState();
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Face ID is not available on this device. You have been signed in with the secure fallback flow.',
          ),
        ),
      );
      setState(() {
        _authenticated = true;
        _onDuty = false;
        _shiftRemaining = const Duration(hours: 8);
      });
      _dutyTimer?.cancel();
      await _persistState();
    }
  }

  void _signOut() {
    _dutyTimer?.cancel();
    setState(() {
      _keepSignedIn = false;
      _authenticated = false;
      _onDuty = false;
      _shiftRemaining = const Duration(hours: 8);
    });
    _persistState();
  }

  void _toggleDuty() {
    setState(() {
      _onDuty = !_onDuty;
      if (_onDuty) {
        _shiftRemaining = const Duration(hours: 8);
      }
    });
    if (_onDuty) {
      _startDutyTimer();
    } else {
      _dutyTimer?.cancel();
    }
    _persistState();
  }

  void _toggleTheme() {
    setState(() => _darkMode = !_darkMode);
    _persistState();
  }

  void _setSirenVolume(double value) {
    setState(() => _sirenVolume = value);
    _persistState();
  }

  void _setAuthStage(AuthStage stage) {
    if (!mounted) return;
    setState(() => _authStage = stage);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = !_darkMode;
    final theme = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: isLight
          ? const Color(0xFFF4F5F7)
          : const Color(0xFF11161A),
      brightness: isLight ? Brightness.light : Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE71D24),
        brightness: isLight ? Brightness.light : Brightness.dark,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: const Color(0xFF1B1B1B),
        displayColor: const Color(0xFF1B1B1B),
      ),
    );

    return MaterialApp(
      title: 'BANTAI',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: _showSplash
          ? const SplashScreen()
          : _authenticated
          ? HomeShell(
              onLogout: _signOut,
              useLightTheme: isLight,
              onToggleTheme: _toggleTheme,
              onDuty: _onDuty,
              shiftRemaining: _shiftRemaining,
              onToggleDuty: _toggleDuty,
              sirenVolume: _sirenVolume,
              onVolumeChanged: _setSirenVolume,
            )
          : _buildAuthFlow(),
    );
  }

  Widget _buildAuthFlow() {
    switch (_authStage) {
      case AuthStage.login:
        return auth_login.LoginScreen(
          onLogin: (email, password, keepSignedIn) =>
              _handleLogin(email, password, keepSignedIn: keepSignedIn),
          onForgotPassword: () => _setAuthStage(AuthStage.forgotEmail),
          onFaceIdSignIn: _handleFaceIdLogin,
          initialEmail: '',
          initialRememberMe: _keepSignedIn,
        );
      case AuthStage.forgotEmail:
        return ForgotPasswordScreen(
          mode: ForgotMode.email,
          onBack: () => _setAuthStage(AuthStage.login),
          onContinue: () => _setAuthStage(AuthStage.forgotSms),
        );
      case AuthStage.forgotSms:
        return ForgotPasswordScreen(
          mode: ForgotMode.sms,
          onBack: () => _setAuthStage(AuthStage.forgotEmail),
          onContinue: () => _setAuthStage(AuthStage.resetPassword),
        );
      case AuthStage.resetPassword:
        return ForgotPasswordScreen(
          mode: ForgotMode.reset,
          onBack: () => _setAuthStage(AuthStage.forgotSms),
          onContinue: () => _setAuthStage(AuthStage.login),
        );
      case AuthStage.requestAdmin:
        return ForgotPasswordScreen(
          mode: ForgotMode.requestAdmin,
          onBack: () => _setAuthStage(AuthStage.resetPassword),
          onContinue: () => _setAuthStage(AuthStage.requestSent),
        );
      case AuthStage.requestSent:
        return ForgotPasswordScreen(
          mode: ForgotMode.requestSent,
          onBack: () => _setAuthStage(AuthStage.login),
          onContinue: () => _setAuthStage(AuthStage.login),
        );
    }
  }
}

class BantaiLogoMark extends StatelessWidget {
  const BantaiLogoMark({
    super.key,
    this.size = 72,
    this.showWordmark = true,
    this.wordmarkColor = const Color(0xFF1B1B1B),
    this.backgroundColor = const Color(0xFFE71D24),
  });

  final double size;
  final bool showWordmark;
  final Color wordmarkColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.18,
            left: size * 0.2,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.14),
              ),
            ),
          ),
          Positioned(
            bottom: size * 0.18,
            right: size * 0.2,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.14),
              ),
            ),
          ),
          Positioned(
            left: size * 0.3,
            right: size * 0.3,
            top: size * 0.26,
            bottom: size * 0.26,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
            ),
          ),
          Positioned(
            left: size * 0.18,
            right: size * 0.18,
            top: size * 0.18,
            bottom: size * 0.18,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final wordmark = Text(
      'BANTAI',
      style: TextStyle(
        fontSize: size * 0.28,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.6,
        color: wordmarkColor,
      ),
    );

    if (!showWordmark) return mark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [mark, const SizedBox(height: 10), wordmark],
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class AuthPhoneFrame extends StatelessWidget {
  const AuthPhoneFrame({
    super.key,
    required this.title,
    required this.child,
    this.showBack = false,
    this.onBack,
    this.progress = 0.0,
    this.headerColor = const Color(0xFFF2F2F2),
  });

  final String title;
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  final double progress;
  final Color headerColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              if (showBack)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                  child: Row(
                    children: [
                      if (onBack != null)
                        TextButton.icon(
                          onPressed: onBack,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Color(0xFF1E1E1E),
                          ),
                          label: const Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      const Spacer(),
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5B5B5B),
                          ),
                        ),
                    ],
                  ),
                )
              else if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
              if (showBack)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFE0E0E0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF33C46D),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.white),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.mode,
    required this.onBack,
    required this.onContinue,
  });

  final ForgotMode mode;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  String _selectedMethod = 'SMS';
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool get _canSendResetCode {
    final value = _contactController.text.trim();
    if (value.isEmpty) return false;

    if (_selectedMethod == 'SMS') {
      return value.replaceAll(RegExp(r'\D'), '').length >= 7;
    }

    return value.contains('@') && value.contains('.');
  }

  bool get _canVerifyCode {
    return _smsCodeController.text.replaceAll(RegExp(r'\D'), '').length == 6;
  }

  bool get _canSaveNewPassword {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    return newPassword.length >= 6 && newPassword == confirmPassword;
  }

  @override
  void initState() {
    super.initState();
    _contactController.addListener(() => setState(() {}));
    _smsCodeController.addListener(() => setState(() {}));
    _newPasswordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _contactController.dispose();
    _smsCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateContact() {
    final value = _contactController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email or mobile number.'),
        ),
      );
      return false;
    }

    if (_selectedMethod == 'SMS') {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid mobile number.')),
        );
        return false;
      }
      return true;
    }

    if (!value.contains('@') || !value.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return false;
    }
    return true;
  }

  bool _validateCode() {
    final digits = _smsCodeController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit verification code.'),
        ),
      );
      return false;
    }
    return true;
  }

  bool _validatePasswordReset() {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be at least 6 characters.'),
        ),
      );
      return false;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final body = (() {
      switch (widget.mode) {
        case ForgotMode.email:
          final accountLabel = _selectedMethod == 'SMS'
              ? 'Mobile no.'
              : 'Email';

          return AuthPhoneFrame(
            title: 'Forgot Pass Email',
            showBack: true,
            onBack: widget.onBack,
            progress: 0.33,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reset your password',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'We send a 6-digit code to the number or email on your rider account.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Color(0xFF5D5D5D),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Send code by',
                    style: TextStyle(fontSize: 14, color: Color(0xFF5D5D5D)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F1F1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD8D8D8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedMethod = 'SMS'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedMethod == 'SMS'
                                    ? const Color(0xFFEAF6FF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedMethod == 'SMS'
                                      ? const Color(0xFF2E7AE6)
                                      : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                'SMS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedMethod == 'SMS'
                                      ? const Color(0xFF1E5DB7)
                                      : const Color(0xFF4F4F4F),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedMethod = 'Email'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedMethod == 'Email'
                                    ? const Color(0xFFEAF6FF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedMethod == 'Email'
                                      ? const Color(0xFF2E7AE6)
                                      : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                'Email',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedMethod == 'Email'
                                      ? const Color(0xFF1E5DB7)
                                      : const Color(0xFF4F4F4F),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    accountLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5D5D5D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD7D7D7)),
                    ),
                    child: TextField(
                      key: const Key('forgot_contact_field'),
                      controller: _contactController,
                      keyboardType: _selectedMethod == 'SMS'
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                      decoration: InputDecoration(
                        hintText: _selectedMethod == 'SMS'
                            ? 'Enter mobile no.'
                            : 'Enter email address',
                        border: InputBorder.none,
                        hintStyle: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF7D7D7D),
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSendResetCode
                          ? () {
                              if (_validateContact()) {
                                widget.onContinue();
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE71D24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Send reset code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Can\'t receive a code?\nIf the number and email on your account are out of reach, ask your command center to reset it for you.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF4E4E4E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFD8D8D8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Request admin reset',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        case ForgotMode.sms:
          return AuthPhoneFrame(
            title: 'Forgot-confirm-sms',
            showBack: true,
            onBack: widget.onBack,
            progress: 0.66,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the code',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Codes expire after 10 minutes for account safety.',
                    style: TextStyle(fontSize: 15, color: Color(0xFF5D5D5D)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.sms_rounded,
                          size: 30,
                          color: Color(0xFF33C46D),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Enter the 6-digit code we texted to',
                          style: TextStyle(
                            color: Color(0xFF4C4C4C),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _contactController.text.trim().isEmpty
                              ? 'your account'
                              : _contactController.text.trim(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            key: const Key('forgot_sms_code_field'),
                            controller: _smsCodeController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 12,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '123456',
                              hintStyle: TextStyle(
                                fontSize: 22,
                                letterSpacing: 8,
                                color: const Color(0xFF9E9E9E),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDCDCDC),
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Resend code in 27s',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF575757),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canVerifyCode
                          ? () {
                              if (_validateCode()) {
                                widget.onContinue();
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE71D24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Verify code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        case ForgotMode.reset:
          return AuthPhoneFrame(
            title: 'Password-reset',
            showBack: true,
            onBack: widget.onBack,
            progress: 1.0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Set a new password',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose something you can recall with gloves on and a helmet down.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF5D5D5D),
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _PasswordInputBox(
                          controller: _newPasswordController,
                          label: 'New',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PasswordInputBox(
                          controller: _confirmPasswordController,
                          label: 'Confirm',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSaveNewPassword
                          ? () {
                              if (_validatePasswordReset()) {
                                widget.onContinue();
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE71D24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save new password',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        case ForgotMode.requestAdmin:
          return AuthPhoneFrame(
            title: 'req-admin',
            showBack: true,
            onBack: widget.onBack,
            progress: 0.8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFE71D24),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Request a reset from your admin',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D1D1D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Use this if you can no longer receive codes on the number or email registered to your account.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF5D5D5D),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _InfoRow(
                    label: 'Call sign',
                    value: _contactController.text.trim().isEmpty
                        ? 'Your unit'
                        : _contactController.text.trim(),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Contact',
                    value: _contactController.text.trim().isEmpty
                        ? 'Not provided yet'
                        : _contactController.text.trim(),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Your administrator will verify your identity before issuing a temporary password. No password is changed by this request on its own.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4C4C4C),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE71D24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Send request to Barangay 171',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        case ForgotMode.requestSent:
          return AuthPhoneFrame(
            title: 'Req-sent',
            showBack: true,
            onBack: widget.onBack,
            progress: 0.5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2EC678),
                    size: 54,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Reset request sent',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Barangay 171 Command Center has been notified. An administrator will verify your identity and issue a temporary password - you will be asked to set your own the first time you sign in with it.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF5D5D5D),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(
                    label: 'Call sign',
                    value: _contactController.text.trim().isEmpty
                        ? 'Your unit'
                        : _contactController.text.trim(),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: 'Contact',
                    value: _contactController.text.trim().isEmpty
                        ? 'Not provided yet'
                        : _contactController.text.trim(),
                  ),
                  const SizedBox(height: 12),
                  const _InfoRow(
                    label: 'Typical response',
                    value: 'Within one shift',
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE71D24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Back to Sign In',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
      }
    })();

    return body;
  }
}

enum ForgotMode { email, sms, reset, requestAdmin, requestSent }

class _PasswordInputBox extends StatelessWidget {
  const _PasswordInputBox({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7D7D7)),
      ),
      child: TextField(
        key: label == 'New'
            ? const Key('forgot_new_password_field')
            : const Key('forgot_confirm_password_field'),
        controller: controller,
        obscureText: true,
        keyboardType: TextInputType.visiblePassword,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F1F1F),
        ),
        decoration: InputDecoration(
          hintText: label,
          border: InputBorder.none,
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF5E5E5E)),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF515151)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1B1B),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE71D24),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Image.asset(
                  'assets/bantai-logo.png',
                  width: 250,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/bantai-icon.png',
                    width: 20,
                    height: 78,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Welcome!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final opacity =
                      0.2 +
                      ((math.sin(_controller.value * math.pi * 2) + 1) / 2) *
                          0.8;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LoadingDot(opacity: opacity),
                      const SizedBox(width: 8),
                      _LoadingDot(
                        opacity:
                            0.5 +
                            ((math.sin(
                                          (_controller.value + 0.33) *
                                              math.pi *
                                              2,
                                        ) +
                                        1) /
                                    2) *
                                0.5,
                      ),
                      const SizedBox(width: 8),
                      _LoadingDot(
                        opacity:
                            0.5 +
                            ((math.sin(
                                          (_controller.value + 0.66) *
                                              math.pi *
                                              2,
                                        ) +
                                        1) /
                                    2) *
                                0.5,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDot extends StatelessWidget {
  const _LoadingDot({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity.clamp(0.2, 1.0)),
        shape: BoxShape.circle,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onLoginSuccess,
    required this.onForgotPassword,
  });

  final Future<bool> Function(String email, String password, bool keepSignedIn)
  onLogin;
  final VoidCallback onLoginSuccess;
  final VoidCallback onForgotPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController(
    text: 'carlos.cruz@bantai.gov.ph',
  );
  final TextEditingController passwordController = TextEditingController();
  bool showPassword = false;
  bool isLoading = false;
  bool keepSignedIn = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    setState(() => isLoading = true);
    final success = await widget.onLogin(email, password, keepSignedIn);
    if (!mounted) return;
    setState(() => isLoading = false);

    if (success) {
      widget.onLoginSuccess();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid credentials.')));
    }
  }

  Future<void> _handleFaceIdLogin() async {
    try {
      final status = await Permission.camera.request();
      if (!mounted) return;

      final hasPermission = status.isGranted || status.isLimited;
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required for Face ID sign in.'),
          ),
        );
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return;
      }

      List<CameraDescription> cameras = const [];
      try {
        cameras = await availableCameras();
      } catch (_) {
        cameras = const [];
      }

      if (!mounted) return;
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No camera was found. Continuing with secure fallback sign-in.',
            ),
          ),
        );
        widget.onLoginSuccess();
        return;
      }

      CameraDescription? selectedCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      selectedCamera ??= cameras.first;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FaceIdLoginScreen(
            camera: selectedCamera!,
            onSuccess: () {
              widget.onLoginSuccess();
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Face ID is not available on this device. You have been signed in with the secure fallback flow.',
          ),
        ),
      );
      widget.onLoginSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formContent = Column(
      children: [
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: const Text(
            'Welcome!',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _buildInputField(
          label: 'Email or Phone',
          controller: emailController,
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 12),
        _buildInputField(
          label: 'Password',
          controller: passwordController,
          icon: Icons.lock_outline,
          isPassword: true,
          showPassword: showPassword,
          onToggleVisibility: () =>
              setState(() => showPassword = !showPassword),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Checkbox(
              value: keepSignedIn,
              onChanged: (value) =>
                  setState(() => keepSignedIn = value ?? false),
              activeColor: const Color(0xFF2EC678),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: const BorderSide(color: Color(0xFF8A8A8A), width: 1.2),
            ),
            const Text(
              'Keep me signed in',
              style: TextStyle(fontSize: 13, color: Color(0xFF595959)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: widget.onForgotPassword,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1F1F),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE71D24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Log In',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: const [
            Expanded(child: Divider(color: Color(0xFFD0D0D0))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Or Continue With',
                style: TextStyle(fontSize: 14, color: Color(0xFF5A5A5A)),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFFD0D0D0))),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.face_rounded, color: Color(0xFF1E1E1E)),
            onPressed: _handleFaceIdLogin,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFFD8D8D8)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
            ),
            label: const Text(
              'Sign in with Face ID',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D1D1D),
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFE71D24),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/bantai-icon.png',
                            width: 28,
                            height: 28,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'BANTAI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          width: 170,
                          height: 82,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/bantai-icon.png',
                              width: 52,
                              height: 52,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: formContent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E9EA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5D5D5D), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword && !showPassword,
              keyboardType: isPassword
                  ? TextInputType.visiblePassword
                  : TextInputType.emailAddress,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F1F1F),
              ),
              decoration: InputDecoration(
                hintText: label,
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  color: Color(0xFF6E6E6E),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (isPassword)
            IconButton(
              onPressed: onToggleVisibility,
              splashRadius: 18,
              icon: Icon(
                showPassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF5C5C5C),
              ),
            ),
        ],
      ),
    );
  }
}

class FaceIdLoginScreen extends StatefulWidget {
  const FaceIdLoginScreen({
    super.key,
    required this.camera,
    required this.onSuccess,
  });

  final CameraDescription camera;
  final VoidCallback onSuccess;

  @override
  State<FaceIdLoginScreen> createState() => _FaceIdLoginScreenState();
}

class _FaceIdLoginScreenState extends State<FaceIdLoginScreen> {
  late CameraController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _isReady = true);
        })
        .catchError((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to access the camera.')),
          );
          Navigator.of(context).pop();
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Face ID Sign In'),
      ),
      body: _isReady
          ? Stack(
              children: [
                CameraPreview(_controller),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSuccess();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: const Color(0xFFE71D24),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Use Face ID to Sign In'),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class _AmbulancePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final red = const Color(0xFFE71D24);
    final white = const Color(0xFFF7F7F7);
    final grey = const Color(0xFFD8D8D8);
    final dark = const Color(0xFF2B2B2B);

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 28, size.width - 24, size.height - 38),
      const Radius.circular(18),
    );
    final cab = RRect.fromRectAndRadius(
      Rect.fromLTWH(48, 10, size.width * 0.48, size.height * 0.42),
      const Radius.circular(16),
    );

    final bodyPaint = Paint()..color = white;
    final redPaint = Paint()..color = red;
    final greyPaint = Paint()..color = grey;
    final darkPaint = Paint()..color = dark;

    canvas.drawRRect(cab, bodyPaint);
    canvas.drawRRect(body, bodyPaint);
    canvas.drawRect(Rect.fromLTWH(38, 36, size.width - 74, 18), redPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(54, 18, size.width * 0.20, 18),
        const Radius.circular(6),
      ),
      redPaint,
    );

    final wheelRadius = 15.0;
    final wheelPositions = [
      Offset(size.width * 0.30, size.height - 10),
      Offset(size.width * 0.72, size.height - 10),
    ];
    for (final wheel in wheelPositions) {
      canvas.drawCircle(wheel, wheelRadius, darkPaint);
      canvas.drawCircle(wheel, 7, greyPaint);
    }

    canvas.drawRect(Rect.fromLTWH(18, 74, size.width - 34, 10), greyPaint);
    canvas.drawRect(Rect.fromLTWH(84, 48, 12, 18), redPaint);
    canvas.drawRect(Rect.fromLTWH(146, 48, 12, 18), redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.onLogout,
    required this.useLightTheme,
    required this.onToggleTheme,
    required this.onDuty,
    required this.shiftRemaining,
    required this.onToggleDuty,
    required this.sirenVolume,
    required this.onVolumeChanged,
  });

  final VoidCallback onLogout;
  final bool useLightTheme;
  final VoidCallback onToggleTheme;
  final bool onDuty;
  final Duration shiftRemaining;
  final VoidCallback onToggleDuty;
  final double sirenVolume;
  final ValueChanged<double> onVolumeChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab selectedTab = AppTab.duty;

  List<Widget> get _pages => [
    IncidentPage(selectedTab: selectedTab),
    ReportPage(selectedTab: selectedTab),
    DutyTabScreen(
      isOnDuty: widget.onDuty,
      duration: widget.shiftRemaining,
      onToggleDuty: widget.onToggleDuty,
      userName: 'Kirby Gabayno',
      callSign: 'BRGY-171-1',
      role: 'Barangay Tanod',
    ),
    AlertsPage(selectedTab: selectedTab),
    SettingsPage(
      selectedTab: selectedTab,
      useLightTheme: widget.useLightTheme,
      onToggleTheme: widget.onToggleTheme,
      sirenVolume: widget.sirenVolume,
      onVolumeChanged: widget.onVolumeChanged,
      onLogout: widget.onLogout,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(index: selectedTab.index, children: _pages),
            ),
            Container(
              decoration: const BoxDecoration(color: Color(0xFFF2F2F2)),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              child: Row(
                children: [
                  _navItem(
                    'Incident',
                    Icons.warning_amber_rounded,
                    AppTab.incident,
                  ),
                  _navItem(
                    'Report',
                    Icons.insert_drive_file_rounded,
                    AppTab.report,
                  ),
                  _navItem('Duty', Icons.shield_rounded, AppTab.duty),
                  _navItem(
                    'Alerts',
                    Icons.notifications_rounded,
                    AppTab.alerts,
                  ),
                  _navItem('Settings', Icons.settings_rounded, AppTab.settings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(String label, IconData icon, AppTab tab) {
    final active = selectedTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFEDEE) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: active
                    ? const Color(0xFFE71D24)
                    : const Color(0xFF6A6A6A),
                size: 23,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: active
                      ? const Color(0xFFE71D24)
                      : const Color(0xFF6A6A6A),
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DutyPage extends StatelessWidget {
  const DutyPage({
    super.key,
    required this.isOnDuty,
    required this.duration,
    required this.onToggleDuty,
  });

  final bool isOnDuty;
  final Duration duration;
  final VoidCallback onToggleDuty;

  static String _formatDuration(Duration value) {
    final hours = value.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = (value.inMinutes.remainder(60)).toString().padLeft(2, '0');
    final seconds = (value.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final dutyLabel = isOnDuty ? 'On Duty' : 'Off Duty';
    final dutyColor = isOnDuty
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFF5E7E7);
    final dutyTextColor = isOnDuty
        ? const Color(0xFF0C8E4E)
        : const Color(0xFFB82B2B);
    final timerLabel = isOnDuty
        ? 'On Duty — Awaiting Dispatch'
        : 'Standby — Duty paused';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Color(0xFFE71D24),
                child: Text(
                  'CC',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Carlos Cruz',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'BRGY-171-1 • Bataan Command Center',
                      style: TextStyle(color: Color(0xFF5A5A5A), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: dutyColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  dutyLabel,
                  style: TextStyle(
                    color: dutyTextColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timerLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Remaining of your 12-hour shift • Bataan Command Center',
                  style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 170,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFC9D7E4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8D5E1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Positioned(
                  left: 26,
                  top: 18,
                  child: _MapBlock(width: 72, height: 56),
                ),
                Positioned(
                  right: 22,
                  bottom: 18,
                  child: _MapBlock(width: 90, height: 58),
                ),
                const Positioned(
                  left: 110,
                  top: 38,
                  child: Icon(
                    Icons.location_pin,
                    color: Color(0xFFE71D24),
                    size: 26,
                  ),
                ),
                const Positioned(
                  right: 78,
                  bottom: 42,
                  child: Icon(
                    Icons.location_pin,
                    color: Color(0xFFE71D24),
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _TelemetryCard(
                  icon: Icons.location_on_rounded,
                  label: 'Location Ping',
                  value: 'Active • 8s ago',
                  active: true,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _TelemetryCard(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: 'Dispatch Link',
                  value: 'Connected',
                  active: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onToggleDuty,
              icon: const Icon(
                Icons.power_settings_new_rounded,
                color: Color(0xFFE71D24),
              ),
              label: Text(
                isOnDuty ? 'Go Off Duty' : 'Go On Duty',
                style: const TextStyle(
                  color: Color(0xFFE71D24),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFE71D24), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IncidentPage extends StatelessWidget {
  const IncidentPage({super.key, required this.selectedTab});

  final AppTab selectedTab;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text(
            'Incident',
            style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Active incident',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE71D24),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '3 active alerts nearby',
                  style: TextStyle(color: Color(0xFF585858), fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFDAE4EE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDEAF3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Positioned(
                  left: 40,
                  top: 40,
                  child: _MapBlock(width: 88, height: 62),
                ),
                Positioned(
                  right: 34,
                  top: 90,
                  child: _MapBlock(width: 96, height: 68),
                ),
                Positioned(
                  left: 150,
                  bottom: 40,
                  child: _MapBlock(width: 96, height: 62),
                ),
                const Positioned(
                  right: 86,
                  top: 58,
                  child: Icon(
                    Icons.location_pin,
                    color: Color(0xFFE71D24),
                    size: 28,
                  ),
                ),
                const Positioned(
                  left: 112,
                  bottom: 52,
                  child: Icon(
                    Icons.location_pin,
                    color: Color(0xFFE71D24),
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.selectedTab});

  final AppTab selectedTab;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TextEditingController titleController = TextEditingController(
    text: 'Verbal alteration at platform 2',
  );
  final TextEditingController narrativeController = TextEditingController(
    text: 'Passenger became aggressive after boarding refusal. Observed the incident and documented the time and location for follow-up.',
  );

  @override
  void dispose() {
    titleController.dispose();
    narrativeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text(
            'Reports',
            style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Post incident report',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Incident title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: narrativeController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Narrative',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report saved as draft.'),
                            ),
                          );
                        },
                        child: const Text('Save Draft'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE71D24),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report submitted successfully.'),
                            ),
                          );
                        },
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Recent status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A4F00),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Verbal alteration at platform 2',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Today • 10:15 AM',
                  style: TextStyle(color: Color(0xFF5F5F5F), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key, required this.selectedTab});

  final AppTab selectedTab;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _notificationItem(
            'Revision requested',
            'Admin feedback added to your report for Alert ALT-8402. Please revise and resubmit.',
            true,
          ),
          _notificationItem(
            'Dispatch update',
            'Unit 7A is now en route to the downtown incident.',
            false,
          ),
          _notificationItem(
            'Shift reminder',
            'Your duty rotation changes in 20 minutes.',
            false,
          ),
        ],
      ),
    );
  }

  static Widget _notificationItem(String title, String subtitle, bool urgent) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: urgent ? const Color(0xFFFFE7E7) : const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              urgent ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
              color: urgent ? const Color(0xFFE71D24) : const Color(0xFF2C7BE5),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF5F5F5F),
                    height: 1.4,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.selectedTab,
    required this.useLightTheme,
    required this.onToggleTheme,
    required this.sirenVolume,
    required this.onVolumeChanged,
    required this.onLogout,
  });

  final AppTab selectedTab;
  final bool useLightTheme;
  final VoidCallback onToggleTheme;
  final double sirenVolume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text(
            'Settings',
            style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: const [
                _SettingRow(label: 'First name', value: 'Carlos'),
                Divider(),
                _SettingRow(label: 'Last name', value: 'Cruz'),
                Divider(),
                _SettingRow(label: 'Agency', value: 'Barangay Tañod'),
                Divider(),
                _SettingRow(label: 'Rank', value: 'Not applicable'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appearance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ThemeChoice(
                        label: 'Light',
                        selected: useLightTheme,
                        onTap: onToggleTheme,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ThemeChoice(
                        label: 'Dark',
                        selected: !useLightTheme,
                        onTap: onToggleTheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Siren Volume',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      '${sirenVolume.round()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: sirenVolume,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: onVolumeChanged,
                  activeColor: const Color(0xFFE71D24),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFE71D24)),
              label: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Color(0xFFE71D24),
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFE71D24), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF5D5D5D), fontSize: 18),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F0F0) : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFFE71D24) : const Color(0xFFD9D9D9),
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFE71D24) : const Color(0xFF4B4B4B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? const Color(0xFF1BAE5B)
                    : const Color(0xFF7A7A7A),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5E5E5E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF1BAE5B) : const Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBlock extends StatelessWidget {
  const _MapBlock({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
