class ShiftDurationResolver {
  const ShiftDurationResolver._();

  static Duration resolve({
    int selectedHours = 8,
    double customHours = 8,
    bool isCustom = false,
  }) {
    final standardPresetHours = {6, 8, 12};
    final useCustom = isCustom || !standardPresetHours.contains(selectedHours);

    if (useCustom) {
      final clamped = customHours.clamp(1, 12).toDouble();
      final wholeHours = clamped.floor();
      final minutes = ((clamped - wholeHours) * 60).round();
      return Duration(hours: wholeHours, minutes: minutes.clamp(0, 59));
    }

    return Duration(hours: selectedHours.clamp(1, 12));
  }
}
