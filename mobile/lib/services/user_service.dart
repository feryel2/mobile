import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../database/helper.dart';
import '../models/rental_model.dart';
import '../models/user_model.dart';

class UserService {
  UserService({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  static String get baseUrl => '${ApiConfig.baseUrl}/users';

  static const String _tokenKey = 'jwt_carrent_token';
  static const String _userCacheKey = 'user_cache_carrent';

  static bool get _supportsSqliteCache =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException;

  static Future<String?> _cacheUserProfile(User user) async {
    if (!_supportsSqliteCache) return null;
    try {
      await DatabaseHelper.instance.cacheUserProfile(user);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userCacheKey, user.id);
      return null;
    } catch (error) {
      debugPrint('Impossible de mettre le profil en cache SQLite : $error');
      return 'Le profil est disponible en ligne, mais pas hors ligne.';
    }
  }

  static Future<User?> _getCachedUserProfile() async {
    if (!_supportsSqliteCache) return null;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userCacheKey);
    if (userId == null || userId.isEmpty) return null;
    return DatabaseHelper.instance.getCachedUserProfile(userId);
  }

  static Future<String?> _cacheAdminClients(List<User> users) async {
    if (!_supportsSqliteCache) return null;
    try {
      await DatabaseHelper.instance.cacheAdminClients(users);
      return null;
    } catch (error) {
      debugPrint(
          'Impossible de mettre la liste client en cache SQLite : $error');
      return 'La liste est disponible en ligne, mais le cache local n’a pas pu être actualisé.';
    }
  }

  static Future<String?> _upsertCachedAdminClient(User user) async {
    if (!_supportsSqliteCache) return null;
    try {
      await DatabaseHelper.instance.upsertCachedAdminClient(user);
      return null;
    } catch (error) {
      debugPrint('Impossible de synchroniser le client dans SQLite : $error');
      return 'Le client a été modifié, mais le cache local n’a pas pu être actualisé.';
    }
  }

  static Future<String?> _removeCachedAdminClient(String userId) async {
    if (!_supportsSqliteCache) return null;
    try {
      await DatabaseHelper.instance.removeCachedAdminClient(userId);
      return null;
    } catch (error) {
      debugPrint('Impossible de supprimer le client du cache SQLite : $error');
      return 'Le client a été supprimé, mais le cache local n’a pas pu être actualisé.';
    }
  }

  // --- GESTION DU TOKEN ET DE LA SESSION ---

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userCacheKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userCacheKey);
    if (_supportsSqliteCache && userId != null) {
      try {
        await DatabaseHelper.instance.deleteCachedUserProfile(userId);
      } catch (error) {
        debugPrint('Impossible de supprimer le profil SQLite local : $error');
      }
    }
    if (_supportsSqliteCache) {
      try {
        await DatabaseHelper.instance.clearCachedAdminClients();
      } catch (error) {
        debugPrint('Impossible de supprimer le cache admin SQLite : $error');
      }
    }
  }

  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // --- API CALLS ---

  // 1. Inscription (Register)
  Future<Map<String, dynamic>> register({
    required String fullname,
    required String email,
    required String password,
    required String phone,
    String? driverLicenseNumber,
    required String emailVerificationCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullname': fullname,
          'email': email,
          'password': password,
          'phone': phone,
          'driverLicenseNumber': driverLicenseNumber ?? '',
          'emailVerificationCode': emailVerificationCode,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        if (data['token'] != null) {
          await saveToken(data['token']);
        }
        final user = User.fromJson(data['user']);
        final cacheWarning = await _cacheUserProfile(user);
        return {
          'success': true,
          'user': user,
          if (cacheWarning != null) 'cacheWarning': cacheWarning,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors de l\'inscription'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  Future<Map<String, dynamic>> sendEmailVerificationCode({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/email-verifications'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'resendAfterSeconds': data['resendAfterSeconds'] ?? 60
        };
      }
      return {
        'success': false,
        'message':
            data['message'] ?? 'Impossible d’envoyer le code de vérification'
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  Future<Map<String, dynamic>> changeEmail({
    required String email,
    required String code,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Session expirée'};
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/profile/email'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'code': code.trim(),
            }),
          )
          .timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = User.fromJson(data['user']);
        final cacheWarning = await _cacheUserProfile(user);
        return {
          'success': true,
          'user': user,
          if (cacheWarning != null) 'cacheWarning': cacheWarning,
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Impossible de modifier l’adresse email.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  Future<Map<String, dynamic>> sendPasswordResetCode({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/password-reset-codes'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'resendAfterSeconds': data['resendAfterSeconds'] ?? 60,
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Impossible d’envoyer le code.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/password-resets'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'code': code.trim(),
              'newPassword': newPassword,
            }),
          )
          .timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      }
      return {
        'success': false,
        'message':
            data['message'] ?? 'Impossible de réinitialiser le mot de passe.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  // 2. Connexion (Login)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (data['token'] != null) {
          await saveToken(data['token']);
        }
        final user = User.fromJson(data['user']);
        final cacheWarning = await _cacheUserProfile(user);
        return {
          'success': true,
          'user': user,
          if (cacheWarning != null) 'cacheWarning': cacheWarning,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Email ou mot de passe invalide'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  Future<Map<String, dynamic>> createAdminDashboardTicket() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Connectez-vous avant d’ouvrir le tableau de bord.'
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/admin-login-tickets'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 &&
          data['success'] == true &&
          data['ticket'] is String) {
        return {'success': true, 'ticket': data['ticket']};
      }
      return {
        'success': false,
        'message': data['message'] ??
            'Impossible de préparer l’accès au tableau de bord.'
      };
    } catch (error) {
      return {'success': false, 'message': 'Erreur réseau : $error'};
    }
  }

  // 3. Récupérer le Profil (Get Profile)
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = User.fromJson(data['user']);
        final cacheWarning = await _cacheUserProfile(user);
        return {
          'success': true,
          'user': user,
          if (cacheWarning != null) 'cacheWarning': cacheWarning,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Impossible de charger le profil'
        };
      }
    } catch (e) {
      if (_isNetworkError(e)) {
        try {
          final cachedUser = await _getCachedUserProfile();
          if (cachedUser != null) {
            return {'success': true, 'user': cachedUser, 'offline': true};
          }
        } catch (cacheError) {
          return {
            'success': false,
            'message': 'Erreur réseau et cache local indisponible : $cacheError'
          };
        }
      }
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  // 4. Mettre à jour le Profil (avec support Multer Multipart pour avatar & permis)
  Future<Map<String, dynamic>> updateProfile({
    String? fullname,
    String? phone,
    String? driverLicenseNumber,
    DateTime? driverLicenseIssuedDate,
    String? avatarFilePath,
    String? licenseFilePath,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Session expirée'};
      }

      final uri = Uri.parse('$baseUrl/profile');
      final request = http.MultipartRequest('PUT', uri);

      request.headers['Authorization'] = 'Bearer $token';

      // Champs texte
      if (fullname != null && fullname.isNotEmpty) {
        request.fields['fullname'] = fullname;
      }
      if (phone != null && phone.isNotEmpty) {
        request.fields['phone'] = phone;
      }
      if (driverLicenseNumber != null) {
        request.fields['driverLicenseNumber'] = driverLicenseNumber;
      }
      if (driverLicenseIssuedDate != null) {
        request.fields['driverLicenseIssuedDate'] =
            driverLicenseIssuedDate.toIso8601String();
      }

      // Fichier Avatar
      if (avatarFilePath != null && avatarFilePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('avatar', avatarFilePath),
        );
      }

      // Fichier Permis de conduire
      if (licenseFilePath != null && licenseFilePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
              'driverLicensePhoto', licenseFilePath),
        );
      }

      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = User.fromJson(data['user']);
        final cacheWarning = await _cacheUserProfile(user);
        return {
          'success': true,
          'user': user,
          if (cacheWarning != null) 'cacheWarning': cacheWarning,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors de la mise à jour'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de la mise à jour : $e'
      };
    }
  }

  Future<Map<String, dynamic>> getRentalHistory() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Session expirée'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/profile/rentals'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final rentals = (data['data'] as List<dynamic>)
            .map((item) => Rental.fromJson(item as Map<String, dynamic>))
            .toList();
        return {'success': true, 'rentals': rentals};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Impossible de charger votre historique'
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  // 5. Modifier le mot de passe
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message':
              data['message'] ?? 'Erreur lors du changement de mot de passe'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  // 6. Déconnexion
  Future<void> logout() async {
    await clearSession();
  }

  // --- Méthodes Administrateur ---
  Future<Map<String, dynamic>> getAllUsers() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      const limit = 100;
      var page = 1;
      final users = <User>[];
      while (true) {
        final uri = Uri.parse(baseUrl).replace(
          queryParameters: {'page': '$page', 'limit': '$limit'},
        );
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final request = _httpClient != null
            ? _httpClient.get(uri, headers: headers)
            : http.get(uri, headers: headers);
        final response = await request.timeout(ApiConfig.timeout);

        final data = jsonDecode(response.body);
        if (response.statusCode != 200 || data['success'] != true) {
          return {
            'success': false,
            'message': data['message'] ??
                'Impossible de récupérer la liste des clients'
          };
        }

        final rawList = data['data'] ?? data['users'];
        if (rawList is! List) {
          return {
            'success': false,
            'message': 'Réponse invalide lors du chargement des clients.'
          };
        }
        users.addAll(
          rawList.map(
            (item) => User.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );

        final pagination = data['pagination'];
        final totalPages = pagination is Map
            ? int.tryParse(pagination['totalPages']?.toString() ?? '')
            : null;
        if (totalPages != null) {
          if (page >= totalPages) break;
        } else if (rawList.length < limit) {
          break;
        }
        page++;
      }

      final cacheWarning = await _cacheAdminClients(users);
      return {
        'success': true,
        'users': users,
        if (cacheWarning != null) 'cacheWarning': cacheWarning,
      };
    } catch (e) {
      if (_isNetworkError(e) && _supportsSqliteCache) {
        try {
          final cachedUsers =
              await DatabaseHelper.instance.getCachedAdminClients();
          if (cachedUsers != null) {
            return {
              'success': true,
              'users': cachedUsers,
              'offline': true,
            };
          }
        } catch (cacheError) {
          debugPrint('Impossible de lire le cache client SQLite : $cacheError');
          return {
            'success': false,
            'message':
                'Erreur réseau et cache local indisponible : $cacheError',
          };
        }
      }
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  Future<Map<String, dynamic>> updateUserStatus(
      String userId, String status) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/$userId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final cacheWarning = data['user'] is Map
            ? await _upsertCachedAdminClient(
                User.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
              )
            : null;
        return {
          'success': true,
          'message': data['message'],
          if (cacheWarning != null) 'cacheWarning': cacheWarning,
        };
      } else {
        return {
          'success': false,
          'message':
              data['message'] ?? 'Erreur lors de la mise à jour du statut'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final cacheWarning = await _removeCachedAdminClient(userId);
        return {
          'success': true,
          'message': data['message'],
          if (cacheWarning != null) 'cacheWarning': cacheWarning,
        };
      } else {
        return {
          'success': false,
          'message':
              data['message'] ?? 'Erreur lors de la suppression du client'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  Future<Map<String, dynamic>> updateClient({
    required String userId,
    required String fullname,
    required String phone,
    required String driverLicenseNumber,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'fullname': fullname,
              'phone': phone,
              'driverLicenseNumber': driverLicenseNumber,
            }),
          )
          .timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final cacheWarning = data['user'] is Map
            ? await _upsertCachedAdminClient(
                User.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
              )
            : null;
        return {
          'success': true,
          'message': data['message'] ?? 'Client mis à jour avec succès.',
          if (cacheWarning != null) 'cacheWarning': cacheWarning,
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Erreur lors de la mise à jour du client'
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  Future<Map<String, dynamic>> createClient({
    required String fullname,
    required String email,
    required String password,
    required String phone,
    String? driverLicenseNumber,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fullname': fullname,
          'email': email,
          'password': password,
          'phone': phone,
          if (driverLicenseNumber != null && driverLicenseNumber.isNotEmpty)
            'driverLicenseNumber': driverLicenseNumber,
        }),
      );

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        final cacheWarning = data['user'] is Map
            ? await _upsertCachedAdminClient(
                User.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
              )
            : null;
        return {
          'success': true,
          'message': data['message'] ?? 'Client créé avec succès',
          if (cacheWarning != null) 'cacheWarning': cacheWarning,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors de la création du client'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }
}
