# CarRent

Application de location de voitures réunissant la gestion des clients, des
véhicules et des réservations dans une API Node.js/MongoDB et une app Flutter.
Le tableau de bord Web admin utilise la même API.

## Architecture

- `backend/` — API Express, authentification JWT, clients, véhicules et
  réservations.
- `mobile/` — app Flutter : connexion/profil, catalogue et gestion admin des
  véhicules, recherche et réservation, historique.
- `admin_dashboard/` — tableau de bord Web pour la gestion des clients.

Les clients actifs peuvent consulter les véhicules et réserver. Les opérations
de gestion des véhicules et les fonctions d’administration nécessitent un compte
admin. Le serveur calcule le prix d’une réservation à partir du prix journalier
du véhicule et empêche les doubles réservations sur les mêmes jours.

## Démarrer l’API

Prérequis : Node.js LTS et MongoDB local ou MongoDB Atlas.

```powershell
cd backend
Copy-Item .env.example .env
```

Générer une clé JWT de développement, puis la renseigner dans `backend/.env` :

```powershell
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

Configurer `MONGODB_URI` dans `.env`, puis lancer :

```powershell
npm install
npm test
npm start
```

L’API écoute par défaut sur `http://localhost:5000`. Au démarrage, elle crée
les index MongoDB requis pour les véhicules et les réservations.

Pour créer les comptes de démonstration et quelques véhicules :

```powershell
node seed.js
```

Le seed ajoute les comptes de démonstration et les véhicules qui manquent ;
il conserve les utilisateurs et véhicules déjà présents. Les mots de passe
initiaux sont affichés dans le terminal uniquement pour les comptes créés.
L’inscription et la réinitialisation du mot de passe par email nécessitent
également de configurer les paramètres SMTP dans `.env`.

## Démarrer l’app Flutter

Prérequis : Flutter SDK. Dans un autre terminal :

```powershell
cd mobile
flutter pub get
flutter run
```

L’émulateur Android utilise `10.0.2.2` pour joindre l’API sur le PC. Pour un
téléphone physique, fournir l’adresse IP du PC :

```powershell
flutter run --dart-define=CARRENT_API_BASE_URL=http://192.168.1.20:5000/api
```

Remplacer l’adresse d’exemple par l’IP réelle du PC.

## Tableau de bord admin

Servir `admin_dashboard/` avec un serveur HTTP local et ouvrir `index.html`.
Le tableau de bord appelle l’API sur `http://localhost:5000/api/users`.

## Vérifications

- Backend : `cd backend; npm test`
- Flutter : `cd mobile; flutter test` et `flutter analyze`
