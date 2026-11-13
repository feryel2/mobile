import 'package:flutter/material.dart';

import '../../database/reservation_draft_database.dart';
import '../../models/reservation_draft.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/reservation_date_range.dart';
import '../../utils/reservation_locations.dart';
import 'available_cars_screen.dart';
import 'reservation_drafts_screen.dart';

class ReservationSearchScreen extends StatefulWidget {
  final User? client;
  final VoidCallback? onReservationConfirmed;
  final ReservationDraft? draft;
  final ReservationDraftDatabase draftDatabase;
  final Future<bool> Function()? draftSessionIsCurrent;

  const ReservationSearchScreen({
    super.key,
    this.client,
    this.onReservationConfirmed,
    this.draft,
    this.draftDatabase = const ReservationDraftDatabase(),
    this.draftSessionIsCurrent,
  });

  @override
  State<ReservationSearchScreen> createState() =>
      _ReservationSearchScreenState();
}

class _ReservationSearchScreenState extends State<ReservationSearchScreen> {
  static const _pageColor = Color(0xFFF6F8FC);
  static const _textColor = Color(0xFF102047);
  static const _secondaryTextColor = Color(0xFF5D6678);
  static const _fieldRadius = BorderRadius.all(Radius.circular(10));

  final _formKey = GlobalKey<FormState>();
  bool _showErrors = false;
  DateTime? _pickupDate;
  DateTime? _returnDate;
  String? _pickupLocation;
  String? _returnLocation;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft == null) return;

    _pickupDate = DateUtils.dateOnly(draft.pickupDate);
    _returnDate = DateUtils.dateOnly(draft.returnDate);
    _pickupLocation = draft.pickupLocation.trim();
    _returnLocation = draft.returnLocation.trim();
  }

  int? get _rentalDays {
    final pickup = _pickupDate;
    final end = _returnDate;
    if (pickup == null || end == null) return null;

    return calculateRentalDays(pickup, end);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _selectPickupDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(today.year + 5, 12, 31);
    final pickup = _pickupDate;
    final selectedDate = await showDatePicker(
      context: context,
      helpText: 'Date de prise en charge',
      initialDate:
          pickup == null || pickup.isBefore(today) || pickup.isAfter(lastDate)
              ? today
              : pickup,
      firstDate: today,
      lastDate: lastDate,
    );

    if (!mounted || selectedDate == null) return;

    setState(() {
      _pickupDate = selectedDate;
      final days = _rentalDays;
      if (days != null && (days < 1 || days > maxReservationRentalDays)) {
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
    final lastReturnDate = DateTime(
      pickup.year,
      pickup.month,
      pickup.day + maxReservationRentalDays,
    );
    final end = _returnDate;
    final selectedDate = await showDatePicker(
      context: context,
      helpText: 'Date de retour',
      initialDate: end == null ||
              end.isBefore(firstReturnDate) ||
              end.isAfter(lastReturnDate)
          ? firstReturnDate
          : end,
      firstDate: firstReturnDate,
      lastDate: lastReturnDate,
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
    if (days != null && days > maxReservationRentalDays) {
      return 'La location ne peut pas dépasser 30 jours.';
    }
    return null;
  }

  Future<void> _searchCars() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _showErrors = true;
      });
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AvailableCarsScreen(
          client: widget.client,
          onReservationConfirmed: widget.onReservationConfirmed,
          draft: widget.draft,
          draftDatabase: widget.draftDatabase,
          draftSessionIsCurrent: widget.draftSessionIsCurrent,
          pickupDate: _pickupDate!,
          returnDate: _returnDate!,
          pickupLocation: _pickupLocation!,
          returnLocation: _returnLocation!,
        ),
      ),
    );
    if (mounted && updated == true) Navigator.pop(context, true);
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
    required String? initialLocation,
    required ValueChanged<String?> onChanged,
    required String missingMessage,
  }) {
    final draft = widget.draft;
    final locations = {
      ...reservationLocations.keys,
      if (draft != null && draft.pickupLocation.trim().isNotEmpty)
        draft.pickupLocation.trim(),
      if (draft != null && draft.returnLocation.trim().isNotEmpty)
        draft.returnLocation.trim(),
    };
    return DropdownButtonFormField<String>(
      key: key,
      initialValue:
          locations.contains(initialLocation) ? initialLocation : null,
      isExpanded: true,
      isDense: false,
      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
      decoration: _fieldDecoration(
        Icons.location_on_outlined,
        verticalPadding: 3,
      ),
      hint: _fieldText(label, 'Choisir un lieu', hasValue: false),
      items: locations.map((location) {
        return DropdownMenuItem(
          value: location,
          child: Text(location, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      selectedItemBuilder: (context) {
        return locations.map((location) {
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        toolbarHeight: 48,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        title: Text(widget.draft == null
            ? 'Rechercher une voiture'
            : 'Modifier le brouillon'),
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
                              initialLocation: _pickupLocation,
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
                              initialLocation: _returnLocation,
                              missingMessage: 'Choisissez un lieu de retour.',
                              onChanged: (value) {
                                setState(() {
                                  _returnLocation = value;
                                });
                              },
                            ),
                            if (days != null &&
                                days >= 1 &&
                                days <= maxReservationRentalDays) ...[
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
                                textStyle: textTheme.labelLarge?.copyWith(
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
                  if (widget.draft == null && widget.client?.role == 'client')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (context) => ReservationDraftsScreen(
                                  client: widget.client,
                                  onReservationConfirmed:
                                      widget.onReservationConfirmed,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.darkBlue,
                          ),
                          icon: const Icon(Icons.folder_outlined, size: 19),
                          label: const Text('Mes brouillons'),
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
