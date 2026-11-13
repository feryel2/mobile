import 'package:flutter/material.dart';

// Matches the team's reservation backend.
const maxReservationRentalDays = 30;

int calculateRentalDays(DateTime pickupDate, DateTime returnDate) {
  // Use the selected calendar days, even if the local clock changes.
  final pickup =
      DateTime.utc(pickupDate.year, pickupDate.month, pickupDate.day);
  final end = DateTime.utc(returnDate.year, returnDate.month, returnDate.day);
  return end.difference(pickup).inDays;
}

String formatReservationDateRange(
  MaterialLocalizations dates,
  DateTime pickupDate,
  DateTime returnDate,
) {
  final start = dates.formatShortMonthDay(pickupDate);
  final end = dates.formatShortMonthDay(returnDate);
  final year = dates.formatYear(returnDate);

  if (pickupDate.year != returnDate.year) {
    return '$start ${dates.formatYear(pickupDate)} – $end $year';
  }
  if (pickupDate.month != returnDate.month) {
    return '$start – $end $year';
  }
  return '${dates.formatDecimal(pickupDate.day)}–$end $year';
}
