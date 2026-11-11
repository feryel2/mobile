class ApiConfig {
  //Emulateur Android : 10.0.2.2 désigne le PC hôte.
  // Téléphone physique : remplacer par l'adresse IPv4 du PC.
  // Windows desktop / navigateur : utiliser localhost.
  //static const String baseUrl ='http://localhost:5000/api';
  static const String baseUrl = 'http://192.168.1.20:5000/api';
  static const Duration timeout = Duration(seconds: 4);
}

