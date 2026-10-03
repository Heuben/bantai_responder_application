import 'package:flutter/material.dart';

class DutyTabScreen extends StatefulWidget {
  const DutyTabScreen({
    super.key,
    required this.isOnDuty,
    required this.duration,
    required this.onToggleDuty,
    this.userName = 'Kirby Gabayno',
    this.callSign = 'BRGY-171-1',
    this.role = 'Barangay Tanod',
  });

  final bool isOnDuty;
  final Duration duration;
  final VoidCallback onToggleDuty;
  final String userName;
  final String callSign;
  final String role;

  @override
  State<DutyTabScreen> createState() => _DutyTabScreenState();
}

class _DutyTabScreenState extends State<DutyTabScreen> {
  static const Color _red = Color(0xFFE71D24);
  static const Color _redSoft = Color(0xFFFDECEC);
  static const Color _green = Color(0xFF1FAF65);
  static const Color _greenSoft = Color(0xFFEAF9F0);
  static const Color _text = Color(0xFF1D1D1D);
  static const Color _muted = Color(0xFF5C5C5C);

  String _formatDuration(Duration value) {
    final hours = value.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = (value.inMinutes.remainder(60)).toString().padLeft(2, '0');
    final seconds = (value.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _showActivationWizard() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DutyActivationWizard(
        onConfirm: () {
          widget.onToggleDuty();
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileCard(
                userName: widget.userName,
                callSign: widget.callSign,
                role: widget.role,
                isOnDuty: widget.isOnDuty,
              ),
              const SizedBox(height: 18),
              widget.isOnDuty ? _ActiveDutyCard(duration: widget.duration, onToggleDuty: widget.onToggleDuty) : _OffDutyCard(onStartDuty: _showActivationWizard),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.userName,
    required this.callSign,
    required this.role,
    required this.isOnDuty,
  });

  final String userName;
  final String callSign;
  final String role;
  final bool isOnDuty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Color(0xFFE71D24),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Color(0xFF1D1D1D),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$callSign · $role',
                  style: const TextStyle(
                    color: Color(0xFF5C5C5C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isOnDuty ? const Color(0xFFEAF9F0) : const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isOnDuty ? 'On Duty' : 'Off Duty',
              style: TextStyle(
                color: isOnDuty ? const Color(0xFF1FAF65) : const Color(0xFFE71D24),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OffDutyCard extends StatelessWidget {
  const _OffDutyCard({required this.onStartDuty});

  final VoidCallback onStartDuty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFFE71D24), size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Off Duty',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D1D1D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'You are not dispatchable. Start a shift to begin receiving alerts in Barangay 171 Command Center.',
                style: TextStyle(
                  color: Color(0xFF5C5C5C),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              const _MapPausedCard(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onStartDuty,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE71D24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Go On Duty',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapPausedCard extends StatelessWidget {
  const _MapPausedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Map paused while off duty',
            style: TextStyle(
              color: Color(0xFF1D1D1D),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFE5EDF8), Color(0xFFF0F3F7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Barangay 171 · your position',
                      style: TextStyle(
                        color: Color(0xFF2B2B2B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 148,
                  top: 48,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE71D24),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 40,
                  bottom: 26,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE71D24),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _StatusPill(
                  label: 'Location Ping',
                  value: 'Paused',
                  active: false,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatusPill(
                  label: 'Dispatch Link',
                  value: 'Standby',
                  active: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveDutyCard extends StatelessWidget {
  const _ActiveDutyCard({
    required this.duration,
    required this.onToggleDuty,
  });

  final Duration duration;
  final VoidCallback onToggleDuty;

  String _formatDuration(Duration value) {
    final hours = value.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = (value.inMinutes.remainder(60)).toString().padLeft(2, '0');
    final seconds = (value.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF9F0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'On Duty — Awaiting Dispatch',
              style: TextStyle(
                color: Color(0xFF1FAF65),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _formatDuration(duration),
            style: const TextStyle(
              color: Color(0xFF1D1D1D),
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Remaining of your 8-hour shift',
            style: TextStyle(
              color: Color(0xFF5C5C5C),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _LiveMapCard(),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _StatusPill(
                  label: 'Location Ping',
                  value: 'Active',
                  active: true,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatusPill(
                  label: 'Dispatch Link',
                  value: 'Connected',
                  active: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onToggleDuty,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE71D24),
                side: const BorderSide(color: Color(0xFFE71D24), width: 1.4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Go Off Duty',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMapCard extends StatelessWidget {
  const _LiveMapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 170,
      decoration: BoxDecoration(
        color: const Color(0xFFE7EEF6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6E0EC)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFFD9E4F2), Color(0xFFEBF1F8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.72),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Barangay 171 · your position',
                style: TextStyle(
                  color: Color(0xFF2D2D2D),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            left: 140,
            top: 55,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFFE71D24),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 44,
            top: 76,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFFE71D24),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 82,
            bottom: 30,
            child: Container(
              width: 120,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.6)),
              ),
            ),
          ),
          Positioned(
            right: 22,
            bottom: 20,
            child: Container(
              width: 90,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.24),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '3 nearby incidents',
                style: TextStyle(
                  color: Color(0xFF1F1F1F),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    required this.active,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFEAF9F0) : const Color(0xFFF4F4F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              active ? Icons.location_on_rounded : Icons.pause_circle_filled_rounded,
              size: 16,
              color: active ? const Color(0xFF1FAF65) : const Color(0xFF707070),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5E5E5E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D1D1D),
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

class _DutyActivationWizard extends StatefulWidget {
  const _DutyActivationWizard({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  State<_DutyActivationWizard> createState() => _DutyActivationWizardState();
}

class _DutyActivationWizardState extends State<_DutyActivationWizard> {
  static const Color _red = Color(0xFFE71D24);
  static const Color _green = Color(0xFF22A75A);

  int _step = 0;
  int _selectedHours = 8;
  double _customHours = 6;
  bool _onDuty = true;

  String _formatEndTime() {
    final hours = _selectedHours == 1 ? 1 : _selectedHours;
    final end = DateTime.now().add(Duration(hours: hours));
    final suffix = end.hour >= 12 ? 'PM' : 'AM';
    return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')} $suffix';
  }

  bool get _canContinueFromStepOne => _onDuty;

  @override
  Widget build(BuildContext context) {
    final progress = ((_step + 1) / 3);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_step > 0) {
                        setState(() => _step--);
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Spacer(),
                  Text(
                    'Step ${_step + 1} of 3',
                    style: const TextStyle(
                      color: Color(0xFF606060),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFEFEFEF),
                  valueColor: const AlwaysStoppedAnimation<Color>(_green),
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: _buildStepContent(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_step == 0 && !_canContinueFromStepOne)
                      ? null
                      : () {
                          if (_step < 2) {
                            setState(() => _step++);
                            return;
                          }
                          widget.onConfirm();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _step == 2 ? _green : _red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _step == 2 ? 'Confirm & Go On Duty' : 'Continue',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ready to start your tour of duty?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You are about to activate your shift and begin receiving dispatch notifications. Keep your location and status updated while on duty.',
              style: TextStyle(
                color: Color(0xFF5D5D5D),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _onDuty ? const Color(0xFFEAF9F0) : const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _onDuty ? 'Ready to receive dispatch' : 'On Duty',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _onDuty ? const Color(0xFF1FAF65) : const Color(0xFF1D1D1D),
                      ),
                    ),
                  ),
                  Switch(
                    value: _onDuty,
                    activeColor: const Color(0xFF1FAF65),
                    onChanged: (value) => setState(() => _onDuty = value),
                  ),
                ],
              ),
            ),
          ],
        );
      case 1:
        final customHours = _customHours.round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How long is your shift?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose a standard or custom duration, then confirm when you are ready to receive dispatches.',
              style: TextStyle(
                color: Color(0xFF5D5D5D),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            _ShiftChoice(
              title: '8 hours',
              subtitle: 'Standard tour of duty',
              selected: _selectedHours == 8 && _customHours == 6,
              onTap: () => setState(() {
                _selectedHours = 8;
                _customHours = 6;
              }),
            ),
            const SizedBox(height: 12),
            _ShiftChoice(
              title: '12 hours',
              subtitle: 'Extended tour',
              selected: _selectedHours == 12,
              onTap: () => setState(() {
                _selectedHours = 12;
                _customHours = 12;
              }),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6E6E6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Custom duration',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D1D1D),
                        ),
                      ),
                      Text(
                        '$customHours hours',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE71D24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFE71D24),
                      thumbColor: const Color(0xFFE71D24),
                      inactiveTrackColor: const Color(0xFFE8E8E8),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: _customHours,
                      min: 1,
                      max: 12,
                      divisions: 11,
                      onChanged: (value) {
                        setState(() {
                          _customHours = value;
                          _selectedHours = value.round();
                        });
                      },
                    ),
                  ),
                  const Text(
                    'Choose a custom shift length between 1 and 12 hours.',
                    style: TextStyle(
                      color: Color(0xFF5D5D5D),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm your shift',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  _SummaryRow(label: 'Starts', value: 'Now'),
                  const Divider(height: 22),
                  _SummaryRow(label: 'Ends at', value: _formatEndTime()),
                  const Divider(height: 22),
                  _SummaryRow(label: 'Call sign', value: 'BRGY-171-1'),
                  const Divider(height: 22),
                  _SummaryRow(label: 'Command center', value: 'Barangay 171'),
                ],
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ShiftChoice extends StatelessWidget {
  const _ShiftChoice({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFDECEC) : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFE71D24) : const Color(0xFFE4E4E4),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1D1D1D),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF5E5E5E),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFFE71D24), size: 24)
            else
              const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFF7A7A7A), size: 22),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5A5A5A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1D1D1D),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
