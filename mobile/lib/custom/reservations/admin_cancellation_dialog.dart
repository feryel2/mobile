import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/reservation_service.dart';
import '../../utils/app_theme.dart';

class AdminCancellationDialog extends StatefulWidget {
  final String reservationId;
  final VoidCallback onConflict;

  const AdminCancellationDialog({
    super.key,
    required this.reservationId,
    required this.onConflict,
  });

  @override
  State<AdminCancellationDialog> createState() =>
      _AdminCancellationDialogState();
}

class _AdminCancellationDialogState extends State<AdminCancellationDialog> {
  static const _maxReasonLength = 500;
  static const _red = Color(0xFFA62834);

  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  bool _submitting = false;
  bool _canRetry = true;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String? _validateReason(String? value) {
    final reason = value?.trim() ?? '';
    if (reason.isEmpty) return 'Indiquez un motif d’annulation.';
    if (reason.length > _maxReasonLength) {
      return 'Le motif ne doit pas dépasser 500 caractères.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting || !_canRetry || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ReservationService.adminCancelReservation(
        widget.reservationId,
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AdminReservationAccessException {
      _showError('Reconnectez-vous avec un compte administrateur.',
          retry: false);
    } on ReservationRequestException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        widget.onConflict();
        _showError(
          'Cette réservation est déjà annulée ou ne peut plus être annulée.',
          retry: false,
        );
      } else {
        _showError(error.message, retry: error.statusCode != 404);
      }
    } catch (_) {
      _showError('Impossible de confirmer l’annulation. Réessayez.');
    }
  }

  void _showError(String message, {bool retry = true}) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _canRetry = retry;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Annuler la réservation'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Réf. · ${widget.reservationId}',
                style: const TextStyle(
                  color: AppTheme.darkBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Cette action annulera la réservation et libérera les dates du '
                'véhicule. Veuillez indiquer un motif.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _reason,
                enabled: !_submitting && _canRetry,
                minLines: 2,
                maxLines: 4,
                maxLength: _maxReasonLength,
                // Keep pasted text visible so the user can fix an overlong reason.
                maxLengthEnforcement: MaxLengthEnforcement.none,
                validator: _validateReason,
                decoration: const InputDecoration(
                  labelText: 'Motif d’annulation',
                  alignLabelWithHint: true,
                  hintText:
                      'Ex. : Véhicule indisponible suite à un problème technique.',
                  border: OutlineInputBorder(),
                  errorMaxLines: 2,
                ),
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: const TextStyle(color: _red)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Retour'),
          ),
          FilledButton.icon(
            onPressed: _submitting || !_canRetry ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: _red),
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined, size: 18),
            label: Text(
              _submitting ? 'Annulation en cours…' : 'Confirmer l’annulation',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
