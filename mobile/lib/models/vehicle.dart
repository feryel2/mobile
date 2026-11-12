class Vehicle {
  final String? id;          // _id MongoDB (null tant que non synchronisé)
  final int? localId;        // clé primaire SQLite
  final String syncStatus;   // 'synced' | 'pending_create' | 'pending_update' | 'pending_delete'
  final String marque;
  final String modele;
  final String immatriculation;
  final int annee;
  final double prix;
  final int kilometrage;
  final String carburant;
  final bool disponible;
  final String image;

  const Vehicle({
    this.id,
    this.localId,
    this.syncStatus = 'synced',
    required this.marque,
    required this.modele,
    required this.immatriculation,
    required this.annee,
    required this.prix,
    required this.kilometrage,
    required this.carburant,
    required this.disponible,
    this.image = 'default_car.png',
  });

  // ---------- API (inchangé) ----------
  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['_id']?.toString() ?? json['id']?.toString(),
    marque: json['marque'] ?? '',
    modele: json['modele'] ?? '',
    immatriculation: json['immatriculation'] ?? '',
    annee: (json['annee'] as num).toInt(),
    prix: (json['prix'] as num).toDouble(),
    kilometrage: (json['kilometrage'] as num).toInt(),
    carburant: json['carburant'] ?? 'Essence',
    disponible: json['disponible'] == true,
    image: json['image'] ?? 'default_car.png',
  );

  Map<String, dynamic> toJson() => {
    'marque': marque,
    'modele': modele,
    'immatriculation': immatriculation,
    'annee': annee,
    'prix': prix,
    'kilometrage': kilometrage,
    'carburant': carburant,
    'disponible': disponible,
    'image': image,
  };

  // ---------- SQLite ----------
  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle(
    localId: map['local_id'] as int?,
    id: map['mongo_id'] as String?,
    syncStatus: map['sync_status'] as String? ?? 'synced',
    marque: map['marque'] as String,
    modele: map['modele'] as String,
    immatriculation: map['immatriculation'] as String,
    annee: map['annee'] as int,
    prix: (map['prix'] as num).toDouble(),
    kilometrage: map['kilometrage'] as int,
    carburant: map['carburant'] as String,
    disponible: (map['disponible'] as int) == 1,
    image: map['image'] as String? ?? 'default_car.png',
  );

  Map<String, dynamic> toMap() => {
    if (localId != null) 'local_id': localId,
    'mongo_id': id,
    'sync_status': syncStatus,
    'marque': marque,
    'modele': modele,
    'immatriculation': immatriculation,
    'annee': annee,
    'prix': prix,
    'kilometrage': kilometrage,
    'carburant': carburant,
    'disponible': disponible ? 1 : 0, // SQLite n'a pas de bool
    'image': image,
  };

  Vehicle copyWith({
    String? id,
    int? localId,
    String? syncStatus,
  }) =>
      Vehicle(
        id: id ?? this.id,
        localId: localId ?? this.localId,
        syncStatus: syncStatus ?? this.syncStatus,
        marque: marque,
        modele: modele,
        immatriculation: immatriculation,
        annee: annee,
        prix: prix,
        kilometrage: kilometrage,
        carburant: carburant,
        disponible: disponible,
        image: image,
      );
}