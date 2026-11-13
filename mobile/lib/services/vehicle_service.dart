import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../database/helper.dart';
import '../models/vehicle.dart';
import 'user_service.dart';

class VehicleService {
  final _db = DatabaseHelper.instance;

  // ======================= API (votre code d'origine) =======================
  Uri _uri([String suffix = '']) =>
      Uri.parse('${ApiConfig.baseUrl}/vehicles$suffix');

  Map<String, dynamic> _decode(http.Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is Map<String, dynamic>) {
      if (response.statusCode >= 200 && response.statusCode < 300) return body;
      throw Exception(
          body['message'] ?? 'Erreur serveur (${response.statusCode})');
    }
    throw Exception('Réponse serveur invalide.');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await UserService.getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Vehicle>> _apiGetAll() async {
    final response = await http.get(_uri()).timeout(ApiConfig.timeout);
    final body = _decode(response);
    return (body['data'] as List).map((e) => Vehicle.fromJson(e)).toList();
  }

  Future<List<Vehicle>> getAvailableForDates(
    DateTime pickupDate,
    DateTime returnDate,
  ) async {
    final uri = _uri('/available').replace(queryParameters: {
      'pickupDate': _dateOnly(pickupDate),
      'returnDate': _dateOnly(returnDate),
    });
    final response = await http.get(uri).timeout(ApiConfig.timeout);
    final body = _decode(response);
    final data = body['data'];
    if (data is! List) {
      throw const FormatException('Réponse véhicule invalide.');
    }
    return data
        .map((item) => Vehicle.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  String _dateOnly(DateTime value) {
    final date = DateTime.utc(value.year, value.month, value.day);
    return date.toIso8601String().substring(0, 10);
  }

  Future<Vehicle> _apiCreate(Vehicle vehicle) async {
    final response = await http
        .post(_uri(),
            headers: await _authHeaders(), body: jsonEncode(vehicle.toJson()))
        .timeout(ApiConfig.timeout);
    return Vehicle.fromJson(_decode(response)['data']);
  }

  Future<Vehicle> _apiUpdate(String id, Vehicle vehicle) async {
    final response = await http
        .put(_uri('/$id'),
            headers: await _authHeaders(), body: jsonEncode(vehicle.toJson()))
        .timeout(ApiConfig.timeout);
    return Vehicle.fromJson(_decode(response)['data']);
  }

  Future<void> _apiDelete(String id) async {
    final response = await http
        .delete(_uri('/$id'), headers: await _authHeaders())
        .timeout(ApiConfig.timeout);
    _decode(response);
  }

  /// Vrai si l'erreur vient du réseau (et non d'un refus du serveur).
  bool _isNetworkError(Object e) =>
      e is SocketException ||
      e is TimeoutException ||
      e is http.ClientException;

  // ============================ Méthodes publiques ============================
  /// Lecture instantanée depuis SQLite.
  Future<List<Vehicle>> getLocal() => _db.getAll();

  /// Synchronise avec le serveur. Renvoie false si le serveur est injoignable.
  Future<bool> refreshFromServer() async {
    try {
      await syncPending();
      final remote = await _apiGetAll();
      await _db.cacheRemote(remote);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// API d'abord (et mise en cache), SQLite en secours.
  Future<List<Vehicle>> getAll() async {
    try {
      await syncPending();
      final remote = await _apiGetAll();
      await _db.cacheRemote(remote);
    } catch (_) {
      // Hors ligne ou serveur injoignable : on lit le cache local
    }
    return _db.getAll();
  }

  Future<Vehicle> create(Vehicle vehicle) async {
    try {
      final created = await _apiCreate(vehicle);
      final saved = created.copyWith(syncStatus: 'synced');
      final localId = await _db.insert(saved);
      return saved.copyWith(localId: localId);
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final pending = vehicle.copyWith(syncStatus: 'pending_create');
      final localId = await _db.insert(pending);
      return pending.copyWith(localId: localId);
    }
  }

  /// `original` = véhicule avant modification, `edited` = nouvelles valeurs.
  Future<Vehicle> update(Vehicle original, Vehicle edited) async {
    final target = edited.copyWith(id: original.id, localId: original.localId);

    // Jamais envoyé au serveur : on modifie seulement la ligne locale
    if (original.id == null) {
      final v = target.copyWith(syncStatus: 'pending_create');
      await _db.update(v);
      return v;
    }

    try {
      final updated = await _apiUpdate(original.id!, edited);
      final v =
          updated.copyWith(localId: original.localId, syncStatus: 'synced');
      await _db.update(v);
      return v;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final v = target.copyWith(syncStatus: 'pending_update');
      await _db.update(v);
      return v;
    }
  }

  Future<void> delete(Vehicle vehicle) async {
    // Jamais synchronisé : simple suppression locale
    if (vehicle.id == null) {
      await _db.delete(vehicle.localId!);
      return;
    }

    try {
      await _apiDelete(vehicle.id!);
      await _db.delete(vehicle.localId!);
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      await _db.update(vehicle.copyWith(syncStatus: 'pending_delete'));
    }
  }

  /// Envoie à MongoDB (via l'API) tout ce qui a été fait hors ligne.
  Future<void> syncPending() async {
    final pending = await _db.getPending();

    for (final v in pending) {
      try {
        switch (v.syncStatus) {
          case 'pending_create':
            final created = await _apiCreate(v);
            await _db.update(
                created.copyWith(localId: v.localId, syncStatus: 'synced'));
          case 'pending_update':
            final updated = await _apiUpdate(v.id!, v);
            await _db.update(
                updated.copyWith(localId: v.localId, syncStatus: 'synced'));
          case 'pending_delete':
            await _apiDelete(v.id!);
            await _db.delete(v.localId!);
        }
      } catch (e) {
        if (_isNetworkError(e)) break; // toujours hors ligne, on réessaiera
        // Erreur serveur (ex. immatriculation en double) : la ligne reste
        // en attente et on passe à la suivante
      }
    }
  }
}
