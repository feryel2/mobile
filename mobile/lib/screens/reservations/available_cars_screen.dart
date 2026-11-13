import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../custom/reservations/available_vehicle_card.dart';
import '../../database/reservation_draft_database.dart';
import '../../models/reservation_draft.dart';
import '../../models/user_model.dart';
import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/reservation_date_range.dart';
import 'reservation_summary_screen.dart';

class AvailableCarsScreen extends StatefulWidget {
  final User? client;
  final ReservationDraft? draft;
  final ReservationDraftDatabase draftDatabase;
  final Future<bool> Function()? draftSessionIsCurrent;
  final DateTime pickupDate;
  final DateTime returnDate;
  final String pickupLocation;
  final String returnLocation;
  // Tests can provide a controlled availability response.
  final Future<List<Vehicle>>? vehiclesFuture;

  const AvailableCarsScreen({
    super.key,
    this.client,
    this.draft,
    this.draftDatabase = const ReservationDraftDatabase(),
    this.draftSessionIsCurrent,
    required this.pickupDate,
    required this.returnDate,
    required this.pickupLocation,
    required this.returnLocation,
    this.vehiclesFuture,
  });

  @override
  State<AvailableCarsScreen> createState() => _AvailableCarsScreenState();
}

class _AvailableCarsScreenState extends State<AvailableCarsScreen> {
  static const _ink = Color(0xFF102047);
  static const _muted = Color(0xFF5D6678);
  static const _border = Color(0xFFD9DFEA);

  late Future<List<Vehicle>> _vehicles;

  @override
  void initState() {
    super.initState();
    _vehicles = widget.vehiclesFuture ??
        VehicleService()
            .getAvailableForDates(widget.pickupDate, widget.returnDate);
  }

  Widget _location(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 8),
        Expanded(
            child:
                Text('$label : $value', style: const TextStyle(color: _ink))),
      ],
    );
  }

  Widget _tripSummary(BuildContext context) {
    final days = calculateRentalDays(widget.pickupDate, widget.returnDate);
    final range = formatReservationDateRange(
      MaterialLocalizations.of(context),
      widget.pickupDate,
      widget.returnDate,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x20102047),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: _muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        range,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FC),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          days == 1 ? '1 jour' : '$days jours',
                          style: const TextStyle(color: _ink, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.blue),
                  child: const Text('Modifier'),
                ),
              ],
            ),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 10),
            _location(Icons.location_on_outlined, 'Prise en charge',
                widget.pickupLocation),
            const SizedBox(height: 8),
            _location(Icons.flag_outlined, 'Retour', widget.returnLocation),
          ],
        ),
      ),
    );
  }

  Future<void> _selectVehicle(Vehicle vehicle) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationSummaryScreen(
          client: widget.client,
          draft: widget.draft,
          draftDatabase: widget.draftDatabase,
          draftSessionIsCurrent: widget.draftSessionIsCurrent,
          vehicle: vehicle,
          pickupDate: widget.pickupDate,
          returnDate: widget.returnDate,
          pickupLocation: widget.pickupLocation,
          returnLocation: widget.returnLocation,
        ),
      ),
    );
    if (mounted && updated == true) Navigator.pop(context, true);
  }

  bool _canSelect(Vehicle vehicle) {
    final id = vehicle.id;
    if (id == null || id.isEmpty) return false;
    if (widget.draft == null) return true;
    return RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id) &&
        (vehicle.prix * 1000).isFinite &&
        vehicle.prix >= 0;
  }

  Widget _draftVehicleNotice(ReservationDraft draft, List<Vehicle> vehicles) {
    Vehicle? savedVehicle;
    for (final vehicle in vehicles) {
      if (vehicle.id == draft.vehicleId && _canSelect(vehicle)) {
        savedVehicle = vehicle;
        break;
      }
    }
    if (savedVehicle == null) {
      return _resultMessage(
        'Le véhicule du brouillon (${draft.vehicleName}) est indisponible pour ces dates. '
        'Modifiez les dates ou choisissez un autre véhicule disponible.',
      );
    }
    final currentMillimes = (savedVehicle.prix * 1000).round();
    if (currentMillimes != draft.dailyPriceMillimes) {
      return _resultMessage(
        'Le tarif de ${draft.vehicleName} a changé. '
        'Tarif actuel : ${ReservationDraft.formatMillimes(currentMillimes)} / jour.',
      );
    }
    return _resultMessage('Votre véhicule enregistré : ${draft.vehicleName}.');
  }

  Widget _resultMessage(String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message,
          textAlign: TextAlign.center, style: const TextStyle(color: _ink)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: AppTheme.darkBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Voitures disponibles',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: FutureBuilder<List<Vehicle>>(
              future: _vehicles,
              builder: (context, snapshot) {
                final vehicles = snapshot.data ?? <Vehicle>[];
                Widget? status;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  status = const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  status = _resultMessage(
                    'Impossible de vérifier les disponibilités.\n${snapshot.error}',
                  );
                } else if (vehicles.isEmpty) {
                  status = _resultMessage(
                      'Aucun véhicule disponible sur cette période.');
                }

                final draft = widget.draft;
                final showDraftNotice = draft != null &&
                    snapshot.connectionState == ConnectionState.done &&
                    !snapshot.hasError;
                final headerCount = showDraftNotice ? 2 : 1;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount:
                      headerCount + (status == null ? vehicles.length : 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Localizations.override(
                        context: context,
                        locale: const Locale('fr'),
                        delegates: GlobalMaterialLocalizations.delegates,
                        child: Builder(builder: _tripSummary),
                      );
                    }
                    if (showDraftNotice && index == 1) {
                      return _draftVehicleNotice(draft, vehicles);
                    }
                    if (status != null) return status;

                    final vehicle = vehicles[index - headerCount];
                    return AvailableVehicleCard(
                      vehicle: vehicle,
                      isDraftVehicle:
                          draft != null && vehicle.id == draft.vehicleId,
                      onSelect: _canSelect(vehicle)
                          ? () => _selectVehicle(vehicle)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
