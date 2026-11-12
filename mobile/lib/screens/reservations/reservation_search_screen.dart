import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import 'available_cars_screen.dart';

class ReservationSearchScreen extends StatefulWidget {
  const ReservationSearchScreen({super.key});

  @override
  State<ReservationSearchScreen> createState() =>
      _ReservationSearchScreenState();
}

class _ReservationSearchScreenState extends State<ReservationSearchScreen> {
  static const _pageColor = Color(0xFFF6F8FC);
  static const _textColor = Color(0xFF102047);
  static const _secondaryTextColor = Color(0xFF5D6678);
  static const _fieldRadius = BorderRadius.all(Radius.circular(10));
  // Provisional maximum used by the reservation backend.
  static const _maxRentalDays = 30;
  static const _locations = ['Tunis - Aéroport'];

  final _formKey = GlobalKey<FormState>();
  bool _showErrors = false;
  DateTime? _pickupDate;
  DateTime? _returnDate;
  String? _pickupLocation;
  String? _returnLocation;

  int? get _rentalDays {
    final pickup = _pickupDate;
    final end = _returnDate;
    if (pickup == null || end == null) return null;

    final pickupDay = DateTime.utc(pickup.year, pickup.month, pickup.day);
    final returnDay = DateTime.utc(end.year, end.month, end.day);
    return returnDay.difference(pickupDay).inDays;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _selectPickupDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pickup = _pickupDate;
    final selectedDate = await showDatePicker(
      context: context,
      helpText: 'Date de prise en charge',
      initialDate: pickup == null || pickup.isBefore(today) ? today : pickup,
      firstDate: today,
      lastDate: DateTime(today.year + 5, 12, 31),
    );

    if (!mounted || selectedDate == null) return;

    setState(() {
      _pickupDate = selectedDate;
      final days = _rentalDays;
      if (days != null && (days < 1 || days > _maxRentalDays)) {
        _returnDate = null;
      }
    });
  }

  Future<void> _selectReturnDate() async {
    final pickup = _pickupDate;
    if (pickup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisissez d’abord la date de prise en charge.'),
        ),
      );
      return;
    }

    final firstReturnDate = DateTime(pickup.year, pickup.month, pickup.day + 1);
    final selectedDate = await showDatePicker(
      context: context,
      helpText: 'Date de retour',
      initialDate: _returnDate ?? firstReturnDate,
      firstDate: firstReturnDate,
      lastDate: DateTime(
        pickup.year,
        pickup.month,
        pickup.day + _maxRentalDays,
      ),
      errorInvalidText:
          'Choisissez une date de retour entre 1 et 30 jours après le départ.',
    );

    if (!mounted || selectedDate == null) return;

    setState(() {
      _returnDate = selectedDate;
    });
  }

  String? _validatePickupDate() {
    final pickup = _pickupDate;
    if (pickup == null) return 'Choisissez une date de prise en charge.';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (pickup.isBefore(today)) {
      return 'Choisissez aujourd’hui ou une date future.';
    }
    return null;
  }

  String? _validateReturnDate() {
    if (_returnDate == null) return 'Choisissez une date de retour.';

    final days = _rentalDays;
    if (days != null && days < 1) {
      return 'Le retour doit être après la prise en charge.';
    }
    if (days != null && days > _maxRentalDays) {
      return 'La location ne peut pas dépasser 30 jours.';
    }
    return null;
  }

  void _searchCars() {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _showErrors = true;
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvailableCarsScreen(
          pickupDate: _pickupDate!,
          returnDate: _returnDate!,
          pickupLocation: _pickupLocation!,
          returnLocation: _returnLocation!,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    IconData icon, {
    double verticalPadding = 9,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      visualDensity: VisualDensity.standard,
      contentPadding: EdgeInsets.fromLTRB(
        0,
        verticalPadding,
        12,
        verticalPadding,
      ),
      border: const OutlineInputBorder(borderRadius: _fieldRadius),
      enabledBorder: const OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: Color(0xFFB8C0CD)),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 50),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF1FC),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Icon(icon, color: AppTheme.darkBlue, size: 19),
        ),
      ),
    );
  }

  Widget _fieldText(String label, String value, {required bool hasValue}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _secondaryTextColor,
            fontSize: 12,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: hasValue ? _textColor : _secondaryTextColor,
            fontSize: 16,
            fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _dateField({
    required Key key,
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required String? Function() validator,
  }) {
    return FormField<DateTime>(
      key: key,
      validator: (_) => validator(),
      builder: (field) {
        return InkWell(
          onTap: onTap,
          borderRadius: _fieldRadius,
          child: InputDecorator(
            decoration: _fieldDecoration(Icons.calendar_today_outlined)
                .copyWith(errorText: field.errorText),
            child: _fieldText(
              label,
              date == null ? 'JJ/MM/AAAA' : _formatDate(date),
              hasValue: date != null,
            ),
          ),
        );
      },
    );
  }

  Widget _locationField({
    required Key key,
    required String label,
    required ValueChanged<String?> onChanged,
    required String missingMessage,
  }) {
    return DropdownButtonFormField<String>(
      key: key,
      isExpanded: true,
      isDense: false,
      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
      decoration: _fieldDecoration(
        Icons.location_on_outlined,
        verticalPadding: 3,
      ),
      hint: _fieldText(label, 'Choisir un lieu', hasValue: false),
      items: _locations.map((location) {
        return DropdownMenuItem(value: location, child: Text(location));
      }).toList(),
      selectedItemBuilder: (context) {
        return _locations.map((location) {
          return _fieldText(label, location, hasValue: true);
        }).toList();
      },
      onChanged: onChanged,
      validator: (value) {
        if (value == null) return missingMessage;
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _rentalDays;

    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        toolbarHeight: 48,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        title: const Text('Rechercher une voiture'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'CarRent',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.darkBlue,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Votre prochaine voiture vous attend',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Trouvez le véhicule idéal pour votre prochain trajet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _secondaryTextColor,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    margin: EdgeInsets.zero,
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 4,
                    shadowColor: const Color(0x20102047),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _showErrors
                            ? AutovalidateMode.always
                            : AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Organisez votre réservation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _dateField(
                              key: const Key('pickupDate'),
                              label: 'Date de prise en charge',
                              date: _pickupDate,
                              onTap: _selectPickupDate,
                              validator: _validatePickupDate,
                            ),
                            const SizedBox(height: 8),
                            _dateField(
                              key: const Key('returnDate'),
                              label: 'Date de retour',
                              date: _returnDate,
                              onTap: _selectReturnDate,
                              validator: _validateReturnDate,
                            ),
                            const SizedBox(height: 8),
                            _locationField(
                              key: const Key('pickupLocation'),
                              label: 'Lieu de prise en charge',
                              missingMessage: 'Choisissez un lieu de départ.',
                              onChanged: (value) {
                                setState(() {
                                  _pickupLocation = value;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            _locationField(
                              key: const Key('returnLocation'),
                              label: 'Lieu de retour',
                              missingMessage: 'Choisissez un lieu de retour.',
                              onChanged: (value) {
                                setState(() {
                                  _returnLocation = value;
                                });
                              },
                            ),
                            if (days != null &&
                                days >= 1 &&
                                days <= _maxRentalDays) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EFF9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      color: AppTheme.darkBlue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        days == 1
                                            ? '1 jour de location'
                                            : '$days jours de location',
                                        style: const TextStyle(
                                          color: _textColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _searchCars,
                              style: ElevatedButton.styleFrom(
                                visualDensity: VisualDensity.standard,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Rechercher des voitures'),
                            ),
                          ],
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
