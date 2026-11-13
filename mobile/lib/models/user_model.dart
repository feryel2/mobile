import 'package:flutter/material.dart';

class DriverLicense {
  final String number;
  final DateTime? issuedDate;
  final String photoUrl;

  DriverLicense({
    this.number = '',
    this.issuedDate,
    this.photoUrl = '',
  });

  factory DriverLicense.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return DriverLicense();
    }
    return DriverLicense(
      number: json['number']?.toString() ?? '',
      issuedDate: json['issuedDate'] != null
          ? DateTime.tryParse(json['issuedDate'].toString())
          : null,
      photoUrl: json['photoUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'issuedDate': issuedDate?.toIso8601String(),
      'photoUrl': photoUrl,
    };
  }

  DriverLicense copyWith({
    String? number,
    DateTime? issuedDate,
    String? photoUrl,
  }) {
    return DriverLicense(
      number: number ?? this.number,
      issuedDate: issuedDate ?? this.issuedDate,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

class User {
  final String id;
  final String fullname;
  final String email;
  final String phone;
  final String avatar;
  final DriverLicense driverLicense;
  final String role;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.fullname,
    required this.email,
    required this.phone,
    this.avatar = '',
    DriverLicense? driverLicense,
    this.role = 'client',
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  }) : driverLicense = driverLicense ?? DriverLicense();

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      fullname: json['fullname']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      driverLicense: DriverLicense.fromJson(
          json['driverLicense'] as Map<String, dynamic>?),
      role: json['role']?.toString() ?? 'client',
      status: json['status']?.toString() ?? 'active',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullname': fullname,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'driverLicense': driverLicense.toJson(),
      'role': role,
      'status': status,
    };
  }

  Map<String, Object?> toDatabaseMap() {
    return {
      'id': id,
      'fullname': fullname,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'driver_license_number': driverLicense.number,
      'driver_license_issued_date': driverLicense.issuedDate?.toIso8601String(),
      'driver_license_photo_url': driverLicense.photoUrl,
      'role': role,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory User.fromDatabaseMap(Map<String, Object?> map) {
    DateTime? parseDate(Object? value) =>
        value == null ? null : DateTime.tryParse(value.toString());

    return User(
      id: map['id']?.toString() ?? '',
      fullname: map['fullname']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      avatar: map['avatar']?.toString() ?? '',
      driverLicense: DriverLicense(
        number: map['driver_license_number']?.toString() ?? '',
        issuedDate: parseDate(map['driver_license_issued_date']),
        photoUrl: map['driver_license_photo_url']?.toString() ?? '',
      ),
      role: map['role']?.toString() ?? 'client',
      status: map['status']?.toString() ?? 'active',
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  // Helpers pour l'affichage de l'UI
  bool get isActive => status == 'active';
  bool get isPendingApproval => status == 'pending_approval';
  bool get isSuspended => status == 'suspended';

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Compte Actif';
      case 'pending_approval':
        return 'Permis en attente de validation';
      case 'suspended':
        return 'Compte Suspendu';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'active':
        return const Color(0xFF28A745); // Vert succès
      case 'pending_approval':
        return const Color(0xFFFFC107); // Jaune attente
      case 'suspended':
        return const Color(0xFFDC3545); // Rouge alerte
      default:
        return Colors.grey;
    }
  }

  User copyWith({
    String? id,
    String? fullname,
    String? email,
    String? phone,
    String? avatar,
    DriverLicense? driverLicense,
    String? role,
    String? status,
  }) {
    return User(
      id: id ?? this.id,
      fullname: fullname ?? this.fullname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      driverLicense: driverLicense ?? this.driverLicense,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
