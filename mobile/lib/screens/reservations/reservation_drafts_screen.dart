import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../custom/reservations/reservation_draft_card.dart';
import '../../custom/reservations/reservation_draft_resume_dialog.dart';
import '../../database/reservation_draft_database.dart';
import '../../models/reservation_draft.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../utils/app_theme.dart';
import 'reservation_search_screen.dart';

class ReservationDraftsScreen extends StatefulWidget {
  final User? client;
  final Future<List<ReservationDraft>> Function(User)? loadDrafts;
  final Future<int> Function(User, int)? deleteDraft;
  final ReservationDraftDatabase draftDatabase;

  const ReservationDraftsScreen({
    super.key,
    required this.client,
    this.loadDrafts,
    this.deleteDraft,
    this.draftDatabase = const ReservationDraftDatabase(),
  });

  @override
  State<ReservationDraftsScreen> createState() =>
      _ReservationDraftsScreenState();
}

class _ReservationDraftsScreenState extends State<ReservationDraftsScreen> {
  static const _ink = Color(0xFF102047);
  static const _muted = Color(0xFF5D6678);
  static const _red = Color(0xFF9D3333);
  Future<List<ReservationDraft>>? _drafts;
  Future<String?>? _sessionToken;
  bool _deleting = false;
  bool _resuming = false;
  int _accountVersion = 0;

  String? _clientId(User? user) => user?.role == 'client' ? user?.id : null;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _drafts = _load();
    _sessionToken = _loadSessionToken();
  }

  @override
  void didUpdateWidget(covariant ReservationDraftsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_clientId(oldWidget.client) != _clientId(widget.client)) {
      _accountVersion++;
      _deleting = false;
      _resuming = false;
      _drafts = _load();
      _sessionToken = _loadSessionToken();
    }
  }

  Future<List<ReservationDraft>>? _load() {
    final client = widget.client;
    if (!_isMobile || client == null || _clientId(client) == null) return null;
    return (widget.loadDrafts ?? widget.draftDatabase.getAllDrafts)(client);
  }

  Future<String?>? _loadSessionToken() {
    if (!_isMobile || _clientId(widget.client) == null) return null;
    return UserService.getToken().catchError((Object _) => null);
  }

  void _refresh() {
    setState(() {
      _drafts = _load();
    });
  }

  Future<void> _resumeDraft(ReservationDraft draft) async {
    final client = widget.client;
    if (_resuming ||
        _deleting ||
        client == null ||
        _clientId(client) != draft.clientId ||
        draft.id == null) {
      return;
    }
    final accountVersion = _accountVersion;
    setState(() {
      _resuming = true;
    });
    try {
      final token = await _sessionToken;
      if (!mounted || accountVersion != _accountVersion) return;
      if (token == null || token.isEmpty) {
        _message('Reconnectez-vous pour reprendre ce brouillon.');
        return;
      }
      Future<bool> sessionIsCurrent() async {
        final currentToken = await UserService.getToken();
        return mounted &&
            _accountVersion == accountVersion &&
            currentToken == token;
      }

      if (!await sessionIsCurrent()) {
        if (mounted && accountVersion == _accountVersion) {
          _message('Votre session a changé. Rouvrez vos brouillons.');
        }
        return;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => Localizations.override(
          context: context,
          locale: const Locale('fr'),
          delegates: GlobalMaterialLocalizations.delegates,
          child: ReservationDraftResumeDialog(draft: draft),
        ),
      );
      if (confirmed != true || !mounted) return;
      if (!await sessionIsCurrent()) {
        if (mounted && accountVersion == _accountVersion) {
          _message('Votre session a changé. Rouvrez vos brouillons.');
        }
        return;
      }
      if (!mounted) return;

      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ReservationSearchScreen(
            client: client,
            draft: draft,
            draftDatabase: widget.draftDatabase,
            draftSessionIsCurrent: sessionIsCurrent,
          ),
        ),
      );
      if (!mounted || accountVersion != _accountVersion || updated != true) {
        return;
      }
      _refresh();
      _message('Brouillon mis à jour sur cet appareil.');
    } catch (_) {
      if (mounted && accountVersion == _accountVersion) {
        _message('Impossible de reprendre le brouillon. Réessayez.');
      }
    } finally {
      if (mounted && accountVersion == _accountVersion) {
        setState(() {
          _resuming = false;
        });
      }
    }
  }

  Future<void> _confirmDelete(int id) async {
    final client = widget.client;
    if (_deleting || _resuming || client == null || _clientId(client) == null) {
      return;
    }
    final accountVersion = _accountVersion;
    setState(() {
      _deleting = true;
    });

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          scrollable: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Supprimer ce brouillon ?',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
          content: const Text(
            'Cette action est définitive. Le brouillon sera supprimé de votre appareil.',
            style: TextStyle(color: _muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(foregroundColor: AppTheme.darkBlue),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || accountVersion != _accountVersion) {
        return;
      }
      final deleted =
          await (widget.deleteDraft ?? widget.draftDatabase.deleteDraft)(
        client,
        id,
      );
      if (!mounted || accountVersion != _accountVersion) return;
      _refresh();
      _message(deleted == 1
          ? 'Brouillon supprimé.'
          : 'Ce brouillon n’est plus sur cet appareil.');
    } catch (_) {
      if (!mounted || accountVersion != _accountVersion) return;
      _message('Impossible de supprimer le brouillon. Réessayez.');
    } finally {
      if (mounted && accountVersion == _accountVersion) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  void _message(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mes brouillons de réservation',
          style: TextStyle(
              color: _ink,
              fontSize: 25,
              fontWeight: FontWeight.w700,
              height: 1.15),
        ),
        const SizedBox(height: 8),
        const Text(
          'Retrouvez vos réservations non finalisées.',
          style: TextStyle(color: _muted, fontSize: 14, height: 1.4),
        ),
        if (_drafts != null)
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.darkBlue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enregistrés localement sur votre appareil',
                    style: TextStyle(color: AppTheme.darkBlue, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _status(IconData icon, String title, String subtitle,
      {bool retry = false}) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE1E7F1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFFEAF1FC),
              child: Icon(icon, color: AppTheme.darkBlue),
            ),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _ink, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.4)),
            if (retry)
              TextButton(
                onPressed: _refresh,
                style: TextButton.styleFrom(foregroundColor: AppTheme.darkBlue),
                child: const Text('Réessayer'),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _listStatus(
      AsyncSnapshot<List<ReservationDraft>> snapshot, bool isEmpty) {
    if (_clientId(widget.client) == null) {
      return _status(Icons.lock_outline, 'Connexion nécessaire',
          'Connectez-vous pour consulter vos brouillons.');
    }
    if (!_isMobile) {
      return _status(Icons.phone_android, 'Brouillons sur mobile',
          'Les brouillons locaux sont disponibles dans l’application Android ou iOS.');
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError) {
      return _status(Icons.info_outline, 'Impossible de charger les brouillons',
          'Réessayez dans un instant.',
          retry: true);
    }
    if (isEmpty) {
      return _status(Icons.folder_open_outlined, 'Aucun brouillon enregistré',
          'Enregistrez une réservation pour la retrouver plus tard.');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Mes brouillons'),
        centerTitle: true,
        backgroundColor: AppTheme.darkBlue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Localizations.override(
              context: context,
              locale: const Locale('fr'),
              delegates: GlobalMaterialLocalizations.delegates,
              child: FutureBuilder<List<ReservationDraft>>(
                key: ValueKey(_accountVersion),
                future: _drafts,
                builder: (context, snapshot) {
                  final clientId = _clientId(widget.client);
                  final drafts = (snapshot.data ?? [])
                      .where((draft) => draft.clientId == clientId)
                      .toList();
                  final status = _listStatus(snapshot, drafts.isEmpty);
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    itemCount: 1 + (status == null ? drafts.length : 1),
                    itemBuilder: (context, index) {
                      if (index == 0) return _header();
                      if (status != null) return status;
                      final draft = drafts[index - 1];
                      final id = draft.id;
                      return ReservationDraftCard(
                        key: ValueKey(id),
                        draft: draft,
                        onResume: _deleting || _resuming || id == null
                            ? null
                            : () => _resumeDraft(draft),
                        onDelete: _deleting || _resuming || id == null
                            ? null
                            : () => _confirmDelete(id),
                      );
                    },
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
