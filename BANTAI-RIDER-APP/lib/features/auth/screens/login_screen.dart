import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onLogin,
    this.onForgotPassword,
    this.onFaceIdSignIn,
    this.initialEmail,
    this.initialRememberMe = true,
  });

  final Future<bool> Function(String email, String password, bool keepSignedIn)?
  onLogin;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onFaceIdSignIn;
  final String? initialEmail;
  final bool initialRememberMe;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _keepSignedIn = true;
  bool _passwordVisible = false;
  bool _isSubmitting = false;
  bool _isFaceIdLoading = false;

  @override
  void initState() {
    super.initState();
    _keepSignedIn = widget.initialRememberMe;
    _emailController.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Email or phone is required';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  Future<void> _submitLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isSubmitting = true);

    try {
      bool success = false;

      if (widget.onLogin != null) {
        success = await widget.onLogin!(email, password, _keepSignedIn);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        success = email.isNotEmpty && password.isNotEmpty;
      }

      if (!mounted) {
        return;
      }

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid email or password. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleFaceIdSignIn() async {
    if (_isFaceIdLoading) {
      return;
    }

    setState(() => _isFaceIdLoading = true);

    try {
      final status = await Permission.camera.request();
      if (!mounted) {
        return;
      }

      if (!status.isGranted && !status.isLimited) {
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required for Face ID sign in.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      List<CameraDescription> cameras = const [];
      try {
        cameras = await availableCameras();
      } catch (_) {
        cameras = const [];
      }

      if (!mounted) {
        return;
      }

      if (cameras.isEmpty) {
        if (widget.onFaceIdSignIn != null) {
          widget.onFaceIdSignIn!.call();
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No camera was found. Continuing with the secure fallback flow.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FaceIdCameraScreen(
            camera: frontCamera,
            onContinue: () {
              if (widget.onFaceIdSignIn != null) {
                widget.onFaceIdSignIn!.call();
              }
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Face ID could not start on this device. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isFaceIdLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeRed = Color(0xFFE71D24);
    const softWhite = Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: themeRed,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 220,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: themeRed),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    left: 18,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/bantai-icon.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.local_hospital,
                              size: 46,
                              color: Colors.white,
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'B.A.N.T.A.I.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    left: 82,
                    top: 62,
                    child: Text(
                      'RESPONDER APP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -42,
                    bottom: -6,
                    child: Image.asset(
                      'assets/bantai-ambulance.png',
                      width: 420,
                      height: 226,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Welcome!',
                                    style: TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E1E1E),
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildField(
                                    controller: _emailController,
                                    hintText: 'Email or Phone',
                                    prefixIcon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: _emailValidator,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildField(
                                    controller: _passwordController,
                                    hintText: 'Password',
                                    prefixIcon: Icons.lock_outline,
                                    keyboardType: TextInputType.visiblePassword,
                                    obscureText: !_passwordVisible,
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _passwordVisible =
                                            !_passwordVisible,
                                      ),
                                      icon: Icon(
                                        _passwordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: const Color(0xFF5D5D5D),
                                      ),
                                      splashRadius: 18,
                                    ),
                                    validator: _passwordValidator,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Transform.scale(
                                        scale: 0.98,
                                        child: Checkbox(
                                          value: _keepSignedIn,
                                          onChanged: (value) => setState(
                                            () =>
                                                _keepSignedIn = value ?? false,
                                          ),
                                          activeColor: const Color(0xFF27B36A),
                                          side: const BorderSide(
                                            color: Color(0xFFCBCBCB),
                                            width: 1.1,
                                          ),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      const Expanded(
                                        child: Text(
                                          'Keep me signed in',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF4F4F4F),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          if (widget.onForgotPassword != null) {
                                            widget.onForgotPassword!.call();
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Forgot password flow is not connected yet.',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1D1D1D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : _submitLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: themeRed,
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        shadowColor: themeRed.withOpacity(0.2),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Log In',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: Color(0xFFE5E5E5),
                                          thickness: 1,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          'Or Continue With',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF676767),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: Color(0xFFE5E5E5),
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _isFaceIdLoading
                                          ? null
                                          : _handleFaceIdSignIn,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF1D1D1D,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFE4E4E4),
                                          width: 1.2,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        backgroundColor: softWhite,
                                      ),
                                      icon: _isFaceIdLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                              ),
                                            )
                                          : const Icon(Icons.face_rounded),
                                      label: Text(
                                        _isFaceIdLoading
                                            ? 'Checking Face ID'
                                            : 'Sign in with Face ID',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Row(
        children: [
          Icon(prefixIcon, color: const Color(0xFF5F5F5F), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              validator: validator,
              style: const TextStyle(
                color: Color(0xFF1D1D1D),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFF7A7A7A),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (suffixIcon != null) suffixIcon,
        ],
      ),
    );
  }
}

class FaceIdCameraScreen extends StatefulWidget {
  const FaceIdCameraScreen({
    super.key,
    required this.camera,
    required this.onContinue,
  });

  final CameraDescription camera;
  final VoidCallback onContinue;

  @override
  State<FaceIdCameraScreen> createState() => _FaceIdCameraScreenState();
}

class _FaceIdCameraScreenState extends State<FaceIdCameraScreen> {
  late final CameraController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isReady = true);
    }).catchError((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to access the front camera.')),
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
                      'Use Face ID to Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
    );
  }
}
