import 'package:flutter_test/flutter_test.dart';

import 'package:banta_rider_app/core/utils/shift_duration.dart';

void main() {
  group('ShiftDurationResolver', () {
    test('keeps standard 6, 8, and 12 hour shifts exact', () {
      expect(
        ShiftDurationResolver.resolve(selectedHours: 6),
        const Duration(hours: 6),
      );
      expect(
        ShiftDurationResolver.resolve(selectedHours: 8),
        const Duration(hours: 8),
      );
      expect(
        ShiftDurationResolver.resolve(selectedHours: 12),
        const Duration(hours: 12),
      );
    });

    test('resolves custom shifts using the selected custom duration', () {
      expect(
        ShiftDurationResolver.resolve(selectedHours: 4, customHours: 5.5),
        const Duration(hours: 5, minutes: 30),
      );
    });
  });
}
