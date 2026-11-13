import 'package:carrent_client/models/reservation_draft.dart';
import 'package:carrent_client/models/user_model.dart';
import 'package:carrent_client/models/vehicle.dart';

final clientA = User(
  id: '000000000000000000000001',
  fullname: 'Test Client A',
  email: '',
  phone: '',
);
final clientB = User(
  id: '000000000000000000000002',
  fullname: 'Test Client B',
  email: '',
  phone: '',
);
const vehicle = Vehicle(
  id: '000000000000000000000003',
  marque: 'Toyota',
  modele: 'Yaris',
  immatriculation: 'TEST',
  annee: 2024,
  prix: 120.5,
  kilometrage: 10000,
  carburant: 'Essence',
  disponible: true,
  image: 'toyota yaris.png',
);

ReservationDraft draftFor(User client) {
  return ReservationDraft.fromVehicle(
    client: client,
    vehicle: vehicle,
    pickupDate: DateTime(2026, 12, 10, 17),
    returnDate: DateTime(2026, 12, 13, 9),
    pickupLocation: 'Tunis - Aéroport',
    returnLocation: 'Tunis - Centre-ville',
  );
}
