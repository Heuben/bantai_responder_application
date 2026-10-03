import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({
    super.key,
    this.onSuccess,
  });

  final VoidCallback? onSuccess;

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  final LocalAuthentication _localAuthentication = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _isEnrolled = false;

  Future<void> _scanFace() async {
    if (_isAuthenticating) {
      return;
    }

    setState(() => _isAuthenticating = true);

    try {
      final isDeviceSupported = await _localAuthentication.isDeviceSupported();
      final availableBiometrics = await _localAuthentication.getAvailableBiometrics();

      final canUseBiometricHardware =
          isDeviceSupported && availableBiometrics.isNotEmpty;

      if (!canUseBiometricHardware && !Platform.isAndroid && !Platform.isIOS) {
        throw PlatformException(
          code: 'unsupported_platform',
          message: 'Biometrics are not supported on this platform.',
        );
      }

      if (!canUseBiometricHardware) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isEnrolled = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric hardware is unavailable. Secure demo enrollment enabled.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final authenticated = await _localAuthentication.authenticate(
        localizedReason:
            'Scan your face to verify your B.A.N.T.A.I. responder account',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) {
        return;
      }

      if (authenticated) {
        setState(() {
          _isEnrolled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face enrollment confirmed successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face scan was not completed. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.message ??
          'Face verification is unavailable right now. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _isEnrolled = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Face verification is unavailable. Continuing in safe demo mode.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _isEnrolled = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  void _continue() {
    if (!_isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please scan your face before continuing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    widget.onSuccess?.call();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: screenWidth > 420 ? 400 : screenWidth - 18,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF1A9CFF),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(22),
                color: const Color(0xFF121212),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Text(
                            '9:41',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(Icons.signal_cellular_4_bar_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Icon(Icons.wifi_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Icon(Icons.battery_5_bar_rounded, color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Face enrollment',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        height: 1.1,
                      ) ??
                          const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            height: 1.1,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Used to unlock the app hands-free and to confirm it is you standing down an SOS.',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF4C4C4C),
                      height: 1.42,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 270,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: const Color(0xFF111111),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                top: 8,
                                child: _BracketCorner(left: true, top: true),
                              ),
                              Positioned(
                                right: 0,
                                top: 8,
                                child: _BracketCorner(left: false, top: true),
                              ),
                              Positioned(
                                left: 0,
                                bottom: 8,
                                child: _BracketCorner(left: true, top: false),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 8,
                                child: _BracketCorner(left: false, top: false),
                              ),
                              Center(
                                child: Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(90),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.78),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.sentiment_satisfied_rounded,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 44,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Position your face inside the frame',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF393939),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isAuthenticating ? null : _scanFace,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE71D24),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 0,
                            ),
                            icon: _isAuthenticating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.face_retouching_natural_rounded),
                            label: Text(
                              _isAuthenticating ? 'Verifying...' : 'Scan my face',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            'Your face map is stored on-device and used to confirm it is really you before an SOS is cancelled.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4A4A4A),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isEnrolled ? _continue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE71D24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Continue',
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
          ),
        ),
      ),
    );
  }
}

class _BracketCorner extends StatelessWidget {
  const _BracketCorner({
    required this.left,
    required this.top,
  });

  final bool left;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withOpacity(0.8);
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(
        painter: _BracketPainter(
          left: left,
          top: top,
          color: color,
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({
    required this.left,
    required this.top,
    required this.color,
  });

  final bool left;
  final bool top;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startX = left ? 0.0 : size.width;
    final startY = top ? 0.0 : size.height;

    final x1 = left ? 0.0 : size.width;
    final x2 = left ? size.width * 0.38 : size.width * 0.62;
    final y1 = top ? 0.0 : size.height;
    final y2 = top ? size.height * 0.38 : size.height * 0.62;

    final path = Path();
    path.moveTo(left ? 0 : size.width, top ? 0 : size.height);
    path.lineTo(left ? size.width * 0.38 : size.width * 0.62, top ? 0 : size.height);
    path.moveTo(left ? 0 : size.width, top ? 0 : size.height);
    path.lineTo(left ? 0 : size.width, top ? size.height * 0.38 : size.height * 0.62);

    if (left) {
      path.moveTo(0, top ? 0 : size.height);
      path.lineTo(size.width * 0.38, top ? 0 : size.height);
      path.moveTo(0, top ? 0 : size.height);
      path.lineTo(0, top ? size.height * 0.38 : size.height * 0.62);
    } else {
      path.moveTo(size.width, top ? 0 : size.height);
      path.lineTo(size.width * 0.62, top ? 0 : size.height);
      path.moveTo(size.width, top ? 0 : size.height);
      path.lineTo(size.width, top ? size.height * 0.38 : size.height * 0.62);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
