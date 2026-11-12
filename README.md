# CarRent

Application de location de voitures réunissant la gestion des clients, des
véhicules et des réservations dans une API Node.js/MongoDB et une app Flutter.
Le tableau de bord Web admin utilise la même API.

## Architecture

- `backend/` — API Express, authentification JWT, clients, véhicules et
  réservations.
- `mobile/` — app Flutter : connexion/profil, cache SQLite du profil utilisateur
  (hors ligne sur Android/iOS, sans mot de passe), catalogue et gestion admin des
  véhicules, recherche et réservation, historique.
- `admin_dashboard/` — back-office Web pour gérer les clients, les véhicules et
  les réservations.

Les clients actifs peuvent consulter les véhicules et réserver. Les opérations
de gestion des véhicules et les fonctions d’administration nécessitent un compte
admin. Le serveur calcule le prix d’une réservation à partir du prix journalier
du véhicule et empêche les doubles réservations sur les mêmes jours.
Après connexion avec un compte admin dans Flutter, le navigateur ouvre le
back-office via un code à usage unique valable 60 secondes. Les comptes clients
restent dans l’application. Le lien « Espace client » du back-office ouvre
l’écran de connexion client et efface la session Flutter précédente.

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

Le seed ajoute les comptes et véhicules de démonstration manquants, ainsi qu’une
réservation confirmée et une réservation annulée ; il conserve les données déjà
présentes et ne duplique pas ces exemples. Les mots de passe initiaux sont
affichés dans le terminal uniquement pour les comptes créés.
L’inscription, la réinitialisation du mot de passe et la modification de
l’adresse email après connexion utilisent un code envoyé par email; elles
nécessitent de configurer les paramètres SMTP dans `.env`. Le cache SQLite du
profil est disponible hors ligne sur Android/iOS; les modifications de compte
restent validées par l’API.

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
