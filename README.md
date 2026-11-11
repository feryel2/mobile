# Gestion des véhicules — Flutter + Node.js + MongoDB

Projet CRUD complet :
- Ajouter, consulter, modifier et supprimer des véhicules
- Validation des saisies côté Flutter et côté API
- Recherche par marque, modèle ou immatriculation
- API REST Express + MongoDB/Mongoose

## Prérequis
- Flutter SDK installé (`flutter doctor`)
- Node.js LTS et npm
- MongoDB local, ou une URI MongoDB Atlas

## 1. Démarrer MongoDB
Option A — MongoDB installé localement : démarrer le service MongoDB.

Option B — Docker :
```bash
cd backend
docker compose up -d
```

## 2. Démarrer le backend
Dans un terminal :
```bash
cd backend
copy .env.example .env
npm install
npm run dev
```
Sur PowerShell, `copy` fonctionne aussi. Le serveur écoute sur `http://localhost:5000`.
Tester : ouvrir `http://localhost:5000/health`.

## 3. Ouvrir et démarrer Flutter
Ouvrir le dossier `frontend` dans Android Studio ou VS Code, puis :
```bash
flutter pub get
flutter run
```

Le projet est configuré par défaut pour l'émulateur Android (`http://10.0.2.2:5000/api`).

### Téléphone Android physique
1. Connecter le téléphone et le PC au même réseau Wi-Fi.
2. Trouver l'adresse IPv4 du PC avec `ipconfig`.
3. Modifier `frontend/lib/config/api_config.dart` et remplacer `10.0.2.2` par l'IPv4 du PC, par exemple `192.168.1.20`.
4. Autoriser Node.js ou le port TCP 5000 dans le pare-feu Windows si nécessaire.

### Navigateur / Windows desktop
Modifier `api_config.dart` et utiliser `http://localhost:5000/api`.

## 4. Endpoints
- `GET /api/vehicles` — liste
- `GET /api/vehicles/:id` — détail
- `POST /api/vehicles` — création
- `PUT /api/vehicles/:id` — modification
- `DELETE /api/vehicles/:id` — suppression

## Champs véhicule
`marque`, `modele`, `immatriculation`, `annee`, `prix`, `kilometrage`, `carburant`, `disponible`.

## Notes
- Le backend valide les champs et rend l'immatriculation unique.
- Les prix sont exprimés dans la devise de ton choix (à adapter dans l'interface).
- `frontend` contient le code source Flutter et `pubspec.yaml`. Pour générer les dossiers natifs si besoin, exécuter `flutter create .` depuis `frontend` après sauvegarde du dossier `lib`.
