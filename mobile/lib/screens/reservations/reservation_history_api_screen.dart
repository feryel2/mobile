import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../custom/reservations/reservation_api_card.dart';
import '../../models/reservation.dart';
import '../../models/user_model.dart';
import '../../services/reservation_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_theme.dart';

enum _HistoryFilter { all, upcoming, past, cancelled }

class ReservationHistoryApiScreen extends StatefulWidget {
  final User? client;

  const ReservationHistoryApiScreen({super.key, required this.client});

  @override
  State<ReservationHistoryApiScreen> createState() =>
      _ReservationHistoryApiScreenState();
}

class _ReservationHistoryApiScreenState
    extends State<ReservationHistoryApiScreen> {
  static const _ink = Color(0xFF102047);
  static const _muted = Color(0xFF5D6678);
  static const _border = Color(0xFFD9DFEA);
  static const _sessionMessage =
      'Reconnectez-vous pour accéder à vos réservations.';

  Future<List<Reservation>>? _reservationsFuture;
  _HistoryFilter _filter = _HistoryFilter.all;
  String? _historyToken;
  String? _cancellingId;
  bool _isSubmitting = false;
  int _accountVersion = 0;

  @override
  void initState() {
    super.initState();
    _reservationsFuture = _load();
  }

  @override
  void didUpdateWidget(covariant ReservationHistoryApiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client?.id != widget.client?.id) {
      _accountVersion++;
      _filter = _HistoryFilter.all;
      _cancellingId = null;
      _isSubmitting = false;
      _reservationsFuture = _load();
    }
  }

  Future<List<Reservation>>? _load() {
    _historyToken = null;
    final client = widget.client;
    if (client == null) return null;
    return _fetch(client.id, _accountVersion);
  }

  Future<List<Reservation>> _fetch(String clientId, int accountVersion) async {
    final token = await UserService.getToken();
    if (token == null || token.isEmpty) throw StateError(_sessionMessage);

    final reservations = await ReservationService.getMyReservations();
    final currentToken = await UserService.getToken();
    if (token != currentToken) throw StateError(_sessionMessage);
    if (mounted && accountVersion == _accountVersion) _historyToken = token;
    return reservations.where((item) => item.clientId == clientId).toList();
  }

  Future<void> _reload() async {
    setState(() {
      _reservationsFuture = _load();
    });
    try {
      await _reservationsFuture;
    } catch (_) {
      // FutureBuilder displays the same request's error.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancel(Reservation reservation) async {
    final token = _historyToken;
    if (_cancellingId != null ||
        token == null ||
        reservation.status != 'confirmed' ||
        reservation.clientId != widget.client?.id) {
      return;
    }
    final accountVersion = _accountVersion;
    setState(() {
      _cancellingId = reservation.id;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          scrollable: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Annuler cette réservation ?',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
          content: const Text(
              'Voulez-vous vraiment annuler cette réservation ?',
              style: TextStyle(color: _muted)),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style:
                  OutlinedButton.styleFrom(foregroundColor: AppTheme.darkBlue),
              child: const Text('Retour'),
            ),
            FilledButton(
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent == true) {
                  Navigator.pop(context, true);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.blue),
              child: const Text('Confirmer l’annulation',
                  textAlign: TextAlign.center),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || accountVersion != _accountVersion) {
        return;
      }
      if (!await _checkSession(token, accountVersion)) return;
      if (!mounted || accountVersion != _accountVersion) return;
      setState(() {
        _isSubmitting = true;
      });
      final updated = await ReservationService.cancel(reservation.id);
      if (!await _checkSession(token, accountVersion)) return;
      if (!mounted || accountVersion != _accountVersion) return;
      if (updated.id != reservation.id ||
          updated.status != 'cancelled' ||
          updated.clientId != reservation.clientId) {
        throw const FormatException('L’annulation n’a pas été confirmée.');
      }
      _showMessage('Réservation annulée.');
      await _reload();
    } catch (error) {
      if (await _checkSession(token, accountVersion) &&
          mounted &&
          accountVersion == _accountVersion) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted && accountVersion == _accountVersion) {
        setState(() {
          _cancellingId = null;
          _isSubmitting = false;
        });
      }
    }
  }

  Future<bool> _checkSession(String token, int accountVersion) async {
    if (!mounted || accountVersion != _accountVersion) return false;
    final currentToken = await UserService.getToken();
    if (!mounted || accountVersion != _accountVersion) return false;
    if (token == currentToken) return true;

    setState(() {
      _historyToken = null;
      _reservationsFuture = null;
    });
    return false;
  }

  bool _matches(Reservation reservation, DateTime today) {
    // The API stores UTC calendar dates. Compare their day numbers to the local
    // calendar date without shifting the reservation dates across time zones.
    final returnDay = DateUtils.dateOnly(reservation.returnDate);
    final cancelled = reservation.status == 'cancelled';
    switch (_filter) {
      case _HistoryFilter.all:
        return true;
      case _HistoryFilter.upcoming:
        return !cancelled && returnDay.isAfter(today);
      case _HistoryFilter.past:
        return !cancelled && !returnDay.isAfter(today);
      case _HistoryFilter.cancelled:
        return cancelled;
    }
  }

  Widget _filterButton(String label, _HistoryFilter filter) {
    final selected = _filter == filter;
    final outlined = filter == _HistoryFilter.all;
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: () {
          setState(() {
            _filter = filter;
          });
        },
        style: TextButton.styleFrom(
          foregroundColor: selected || outlined ? AppTheme.darkBlue : _ink,
          backgroundColor:
              selected ? const Color(0xFFEAF1FC) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: outlined ? const BorderSide(color: AppTheme.blue) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mes réservations',
            style: TextStyle(
                color: _ink, fontSize: 27, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        const Text('Retrouvez et suivez vos réservations.',
            style: TextStyle(color: _muted, fontSize: 14)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF0F4),
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                  child: _filterButton('À venir', _HistoryFilter.upcoming)),
              Expanded(child: _filterButton('Passées', _HistoryFilter.past)),
              Expanded(
                  child: _filterButton('Annulées', _HistoryFilter.cancelled)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _filterButton('Tout afficher', _HistoryFilter.all),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _message(IconData icon, String title, String message,
      {bool retry = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.darkBlue, size: 34),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted)),
          if (retry)
            TextButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
        ],
      ),
    );
  }

  Widget? _status(AsyncSnapshot<List<Reservation>> snapshot, bool hasMatches) {
    if (_reservationsFuture == null) {
      return _message(
          Icons.lock_outline, 'Connexion nécessaire', _sessionMessage);
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError) {
      return _message(Icons.info_outline,
          'Impossible de charger les réservations.', snapshot.error.toString(),
          retry: true);
    }
    if (hasMatches) return null;
    return _message(
      Icons.event_busy_outlined,
      'Aucune réservation trouvée',
      snapshot.data?.isEmpty == true
          ? 'Ouvrez l’onglet Réserver pour choisir un véhicule.'
          : 'Aucune réservation ne correspond à ce filtre.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Mes réservations',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        toolbarHeight: 48,
        centerTitle: true,
        backgroundColor: AppTheme.darkBlue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Localizations.override(
              context: context,
              locale: const Locale('fr'),
              delegates: GlobalMaterialLocalizations.delegates,
              child: FutureBuilder<List<Reservation>>(
                key: ValueKey(_accountVersion),
                future: _reservationsFuture,
                builder: (context, snapshot) {
                  final today = DateUtils.dateOnly(DateTime.now());
                  final reservations = (snapshot.data ?? [])
                      .where((reservation) => _matches(reservation, today))
                      .toList();
                  final status = _status(snapshot, reservations.isNotEmpty);

                  return RefreshIndicator(
                    onRefresh: () async {
                      if (_cancellingId == null) await _reload();
                    },
                    child: ListView.builder(
                      key: ValueKey(_filter),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      itemCount: 1 + (status == null ? reservations.length : 1),
                      itemBuilder: (context, index) {
                        if (index == 0) return _header();
                        if (status != null) return status;
                        final reservation = reservations[index - 1];
                        return ReservationApiCard(
                          key: ValueKey(reservation.id),
                          reservation: reservation,
                          isCancelling:
                              _isSubmitting && _cancellingId == reservation.id,
                          onCancel: _cancellingId == null &&
                                  reservation.status == 'confirmed'
                              ? () => _cancel(reservation)
                              : null,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
