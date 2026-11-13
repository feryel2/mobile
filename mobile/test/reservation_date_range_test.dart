import 'package:carrent_client/utils/reservation_date_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('13 to 21 November is eight calendar days', () async {
    final pickup = DateTime(2026, 11, 13, 18);
    final end = DateTime(2026, 11, 21, 8);
    final dates = await GlobalMaterialLocalizations.delegate.load(
      const Locale('fr'),
    );

    expect(calculateRentalDays(pickup, end), 8);
    expect(formatReservationDateRange(dates, pickup, end), '13–21 nov. 2026');
  });

  test('date range keeps both months and both years when needed', () async {
    final dates = await GlobalMaterialLocalizations.delegate.load(
      const Locale('fr'),
    );

    expect(
      formatReservationDateRange(
        dates,
        DateTime.utc(2026, 11, 30),
        DateTime.utc(2026, 12, 2),
      ),
      '30 nov. – 2 déc. 2026',
    );
    expect(
      formatReservationDateRange(
        dates,
        DateTime.utc(2026, 12, 31),
        DateTime.utc(2027, 1, 2),
      ),
      '31 déc. 2026 – 2 janv. 2027',
    );
  });
}
