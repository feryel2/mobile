import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../custom/reservations/reservation_vehicle_photo.dart';
import '../../custom/reservations/reservation_verification_dialog.dart';
import '../../database/reservation_draft_database.dart';
import '../../models/reservation_draft.dart';
import '../../models/user_model.dart';
import '../../models/vehicle.dart';
import '../../services/reservation_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/reservation_date_range.dart';
import 'reservation_drafts_screen.dart';

class ReservationSummaryScreen extends StatefulWidget {
  final Vehicle vehicle;
  final DateTime pickupDate;
  final DateTime returnDate;
  final String pickupLocation;
  final String returnLocation;
  final User? client;
  final ReservationDraft? draft;
  final ReservationDraftDatabase draftDatabase;
  final Future<bool> Function()? draftSessionIsCurrent;
  // Widget tests can exercise saving without opening the app's SQLite file.
  final Future<int> Function(User, ReservationDraft)? insertDraft;

  const ReservationSummaryScreen({
    super.key,
    required this.vehicle,
    required this.pickupDate,
    required this.returnDate,
    required this.pickupLocation,
    required this.returnLocation,
    this.client,
    this.draft,
    this.draftDatabase = const ReservationDraftDatabase(),
    this.draftSessionIsCurrent,
    this.insertDraft,
  });

  @override
  State<ReservationSummaryScreen> createState() =>
      _ReservationSummaryScreenState();
}

class _ReservationSummaryScreenState extends State<ReservationSummaryScreen> {
  static const _ink = Color(0xFF102047);
  static const _muted = Color(0xFF5D6678);
  static const _border = Color(0xFFD9DFEA);
  static const _page = Color(0xFFF6F8FC);

  bool _reviewOpen = false;
  bool _isSaving = false;
  bool _isSavingDraft = false;
  bool _draftSaved = false;

  int get _rentalDays =>
      calculateRentalDays(widget.pickupDate, widget.returnDate);

  String get _duration => _rentalDays == 1 ? '1 jour' : '$_rentalDays jours';

  bool get _validTrip =>
      !DateUtils.dateOnly(widget.pickupDate)
          .isBefore(DateUtils.dateOnly(DateTime.now())) &&
      _rentalDays >= 1 &&
      _rentalDays <= maxReservationRentalDays &&
      widget.pickupLocation.trim().isNotEmpty &&
      widget.returnLocation.trim().isNotEmpty;

  String? _draftSaveProblem(User? client) {
    final objectId = RegExp(r'^[0-9a-fA-F]{24}$');
    if (client == null ||
        client.role != 'client' ||
        !objectId.hasMatch(client.id)) {
      return 'Connectez-vous avec un compte client pour enregistrer un brouillon.';
    }
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return 'Les brouillons locaux sont disponibles dans l’application Android ou iOS.';
    }
    return null;
  }

  Future<bool> _checkDraftSession(User? client) async {
    final draft = widget.draft;
    final sessionIsCurrent = widget.draftSessionIsCurrent;
    if (client?.id == draft?.clientId &&
        client?.role == 'client' &&
        sessionIsCurrent != null &&
        await sessionIsCurrent() &&
        mounted) {
      return true;
    }
    if (mounted) {
      _showDraftMessage('Votre session a changé. Rouvrez vos brouillons.');
    }
    return false;
  }

  Future<void> _updateDraft(User client, ReservationDraft original) async {
    if (!await _checkDraftSession(client) || !mounted) return;
    final id = original.id;
    final saved =
        id == null ? null : await widget.draftDatabase.getDraftById(client, id);
    if (!mounted) return;
    const missingMessage = 'Ce brouillon n’est plus sur cet appareil.';
    if (saved == null) {
      _showDraftMessage(missingMessage);
      return;
    }

    final revised = ReservationDraft.fromVehicle(
      id: saved.id,
      createdAt: saved.createdAt,
      client: client,
      vehicle: widget.vehicle,
      pickupDate: widget.pickupDate,
      returnDate: widget.returnDate,
      pickupLocation: widget.pickupLocation,
      returnLocation: widget.returnLocation,
    );
    if (!await _checkDraftSession(client) || !mounted) return;
    final updated = await widget.draftDatabase.updateDraft(client, revised);
    if (!mounted) return;
    if (updated == 0) {
      _showDraftMessage(missingMessage);
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _saveDraft() async {
    final client = widget.client;
    if (_isSavingDraft ||
        _isSaving ||
        _reviewOpen ||
        _draftSaved ||
        client == null ||
        _draftSaveProblem(client) != null) {
      return;
    }

    if (!_validTrip) {
      _showDraftMessage(
          'Vérifiez les dates et les lieux de votre réservation.');
      return;
    }

    setState(() {
      _isSavingDraft = true;
    });
    try {
      final original = widget.draft;
      if (original != null) {
        await _updateDraft(client, original);
        return;
      }

      // The model checks the vehicle ID and daily price before SQLite is called.
      final draft = ReservationDraft.fromVehicle(
        client: client,
        vehicle: widget.vehicle,
        pickupDate: widget.pickupDate,
        returnDate: widget.returnDate,
        pickupLocation: widget.pickupLocation,
        returnLocation: widget.returnLocation,
      );
      await (widget.insertDraft ??
          const ReservationDraftDatabase().insertDraft)(
        client,
        draft,
      );
      if (!mounted) return;
      setState(() {
        _draftSaved = true;
      });
      _showDraftMessage('Brouillon enregistré sur cet appareil.');
    } on ArgumentError {
      if (mounted) {
        _showDraftMessage('Le véhicule ou son tarif est invalide.');
      }
    } catch (_) {
      if (mounted) {
        _showDraftMessage('Impossible d’enregistrer le brouillon. Réessayez.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
        });
      }
    }
  }

  void _showDraftMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _openDrafts() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReservationDraftsScreen(client: widget.client),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _reviewReservation(String estimatedTotal) async {
    if (_reviewOpen || _isSaving || _isSavingDraft) return;
    if (!_validTrip) {
      _showDraftMessage(
          'Vérifiez les dates et les lieux de votre réservation.');
      return;
    }
    final id = widget.vehicle.id;
    if (id == null ||
        !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id) ||
        !(widget.vehicle.prix * 1000).isFinite ||
        widget.vehicle.prix < 0) {
      _showDraftMessage('Le véhicule ou son tarif est invalide.');
      return;
    }

    setState(() {
      _reviewOpen = true;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ReservationVerificationDialog(
          vehicle: widget.vehicle,
          pickupDate: widget.pickupDate,
          returnDate: widget.returnDate,
          pickupLocation: widget.pickupLocation,
          returnLocation: widget.returnLocation,
          duration: _duration,
          estimatedTotal: estimatedTotal,
        ),
      );
      if (confirmed == true && mounted) {
        await _confirmReservation();
      }
    } finally {
      if (mounted) {
        setState(() {
          _reviewOpen = false;
        });
      }
    }
  }

  Future<void> _confirmReservation() async {
    if (_isSaving || _isSavingDraft) return;
    setState(() {
      _isSaving = true;
    });
    try {
      if (widget.draft != null) {
        try {
          if (!await _checkDraftSession(widget.client) || !mounted) return;
        } catch (_) {
          if (mounted) {
            _showDraftMessage(
                'Impossible de vérifier votre session. Réessayez.');
          }
          return;
        }
      }
      final reservation = await ReservationService.create(
        vehicleId: widget.vehicle.id!,
        pickupDate: widget.pickupDate,
        returnDate: widget.returnDate,
        pickupLocation: widget.pickupLocation,
        returnLocation: widget.returnLocation,
      );
      if (!mounted) return;
      final confirmedVehicle = reservation.vehicleName.isEmpty
          ? '${widget.vehicle.marque} ${widget.vehicle.modele}'
          : reservation.vehicleName;
      setState(() {
        _isSaving = false;
      });
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Réservation confirmée'),
          content: Text(
            'Véhicule : $confirmedVehicle\n'
            'Référence : ${reservation.id}\n\n'
            'Prise en charge : ${_formatDate(reservation.pickupDate)}\n'
            '${reservation.pickupLocation}\n'
            'Retour : ${_formatDate(reservation.returnDate)}\n'
            '${reservation.returnLocation}\n\n'
            'Total confirmé : ${ReservationDraft.formatMillimes(reservation.totalPriceMillimes)}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Terminé'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _card(Widget child) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: const Color(0x20102047),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }

  Widget _tripStop(
    MaterialLocalizations dates,
    String label,
    DateTime date,
    String location, {
    bool first = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const SizedBox(height: 5),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: first ? Colors.white : AppTheme.blue,
                  border: Border.all(color: AppTheme.blue, width: 1.5),
                ),
              ),
              if (first)
                const Expanded(
                  child: VerticalDivider(width: 1, color: Color(0xFFB9CFF1)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: first ? 10 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FC),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Text(label,
                          style: const TextStyle(color: _ink, fontSize: 12)),
                    ),
                  ),
                  Text(
                    '${dates.formatDecimal(date.day)} ${dates.formatMonthYear(date)}',
                    style: const TextStyle(
                        color: _ink, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(location, style: const TextStyle(color: _muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool total = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  color: total ? _ink : _muted,
                  fontWeight: total ? FontWeight.w700 : FontWeight.w400,
                )),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: total ? AppTheme.darkBlue : _ink,
                fontSize: total ? 21 : 14,
                fontWeight: total ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final name = '${vehicle.marque} ${vehicle.modele}';
    final editing = widget.draft != null;
    // Use the same millime conversion as the draft model and backend.
    final scaledPrice = vehicle.prix * 1000;
    final dailyMillimes =
        scaledPrice.isFinite && scaledPrice >= 0 ? scaledPrice.round() : null;
    final dailyPrice = dailyMillimes == null
        ? 'Indisponible'
        : ReservationDraft.formatMillimes(dailyMillimes);
    final estimatedTotal = dailyMillimes == null || _rentalDays < 1
        ? 'Indisponible'
        : ReservationDraft.formatMillimes(_rentalDays * dailyMillimes);
    final draftSaveProblem = _draftSaveProblem(widget.client);
    final busy = _isSaving || _isSavingDraft || _reviewOpen;

    return PopScope(
      canPop: !_isSaving && (!editing || !_isSavingDraft),
      child: Scaffold(
        backgroundColor: _page,
        appBar: AppBar(
          toolbarHeight: 48,
          centerTitle: true,
          backgroundColor: AppTheme.darkBlue,
          foregroundColor: Colors.white,
          title: const Text('Votre réservation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Vérifiez votre réservation',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _card(Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ReservationVehiclePhoto(
                          vehicleName: name,
                          image: vehicle.image,
                          height: 132,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(
                                      color: _ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text('$dailyPrice / jour',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                      color: AppTheme.darkBlue,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        Text('${vehicle.carburant} · ${vehicle.annee}',
                            style:
                                const TextStyle(color: _muted, fontSize: 13)),
                      ],
                    )),
                    const SizedBox(height: 14),
                    const Text('Détails de votre trajet',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Localizations.override(
                      context: context,
                      locale: const Locale('fr'),
                      delegates: GlobalMaterialLocalizations.delegates,
                      child: Builder(builder: (context) {
                        final dates = MaterialLocalizations.of(context);
                        return _card(Column(
                          children: [
                            _tripStop(dates, 'Prise en charge',
                                widget.pickupDate, widget.pickupLocation,
                                first: true),
                            _tripStop(dates, 'Retour', widget.returnDate,
                                widget.returnLocation),
                          ],
                        ));
                      }),
                    ),
                    const SizedBox(height: 12),
                    _card(Column(
                      children: [
                        _priceRow('Tarif journalier', dailyPrice),
                        _priceRow('Durée', _duration),
                        _priceRow('Calcul', '$_rentalDays × $dailyPrice'),
                        const Divider(height: 18, color: _border),
                        _priceRow('Total estimé', estimatedTotal, total: true),
                      ],
                    )),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => _reviewReservation(estimatedTotal),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fact_check_outlined, size: 19),
                      label: Text(
                        _isSaving
                            ? 'Enregistrement de la réservation…'
                            : 'Vérifier ma réservation',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _draftButton(busy, editing, draftSaveProblem),
                    if (draftSaveProblem != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(draftSaveProblem,
                            style:
                                const TextStyle(color: _muted, fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _draftButton(bool busy, bool editing, String? problem) {
    return OutlinedButton.icon(
      onPressed: busy || problem != null
          ? null
          : _draftSaved
              ? _openDrafts
              : _saveDraft,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.blue,
        backgroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: _isSavingDraft
          ? const SizedBox.square(
              dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(_draftSaved
              ? Icons.folder_outlined
              : Icons.bookmark_add_outlined),
      label: Text(
        _isSavingDraft
            ? 'Enregistrement du brouillon…'
            : _draftSaved
                ? 'Voir mes brouillons'
                : editing
                    ? 'Mettre à jour le brouillon'
                    : 'Enregistrer comme brouillon',
        textAlign: TextAlign.center,
      ),
    );
  }
}
