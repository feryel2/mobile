// Each pair is [latitude, longitude] for a representative weather point.
// Airport reference point: Tunisian Ministry of Transport. Other areas: GeoNames
// (Place de l’Indépendance for Centre-ville), and OpenStreetMap for Les Berges du Lac.
const reservationLocations = <String, List<double>>{
  'Tunis - Aéroport': [36.8511, 10.2269],
  'Tunis - Centre-ville': [36.79944, 10.17851],
  'Tunis - Les Berges du Lac': [36.83509, 10.23884],
  'Tunis - La Marsa': [36.87818, 10.32466],
  'Tunis - Carthage': [36.85961, 10.32978],
  'Tunis - Sidi Bou Saïd': [36.87111, 10.34619],
  'Grand Tunis - Ariana': [36.86542, 10.16846],
};
