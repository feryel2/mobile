# 🚗 CarRent - Module "Gestion Client" (Fullstack)

Module complet de **Gestion Client** pour l'application de location de voitures **CarRent**, comprenant l'API Backend RESTful (Node.js/Express/MongoDB), l'application mobile Flutter (Front-office Client), et le tableau de bord web d'administration (Back-office).

---

## 🎨 1. Charte Graphique & UI/UX (Figma CarRent)
- **Couleur Principale :** Bleu intense (`#0052CC`)
- **Succès / Validation :** Vert (`#28A745`)
- **Alerte / Action Critique :** Rouge (`#DC3545`)
- **Fond d'écran :** Blanc / Gris très clair (`#F8F9FA`)
- **Style visuel :** Cards blanches arrondies avec ombres douces, boutons pilules (`border-radius: 30px`), police moderne Google Fonts Poppins.
- **Navigation mobile :** `BottomNavigationBar` à 4 onglets (*Accueil*, *Véhicules*, *Réservations*, *Profil*).

---

## 📁 2. Structure du Projet

```text
├── backend/
│   ├── controllers/
│   │   ├── userController.js      # Authentification, profil et administration client
│   │   └── rentalController.js    # Historique des locations côté client et admin
│   ├── middlewares/
│   │   ├── auth.js                # Vérification JWT (protect) & rôle Admin
│   │   └── upload.js              # Multer pour avatar et photos de permis
│   ├── models/
│   │   ├── User.js                # Schéma utilisateur avec hash bcrypt
│   │   └── Rental.js              # Location associée à un client
│   ├── routes/
│   │   └── users.js               # Définition des endpoints RESTful
│   ├── uploads/                   # Fichiers médias téléversés
│   ├── .env.example               # Variables d'environnement
│   ├── package.json
│   ├── seed.js                    # Script d'initialisation de données de test
│   └── server.js                  # Point d'entrée serveur Express
│
├── mobile_carrent/
│   ├── lib/
│   │   ├── models/
│   │   │   ├── user_model.dart    # Modèle Dart User & DriverLicense
│   │   │   └── rental_model.dart  # Modèle Dart de l'historique de location
│   │   ├── services/
│   │   │   └── user_service.dart  # Client HTTP (compte, profil, permis, historique)
│   │   ├── screens/
│   │   │   ├── auth_screen.dart   # Écran Inscription / Connexion avec toggle
│   │   │   ├── profile_screen.dart# Profil, informations personnelles, permis & navigation
│   │   │   └── rental_history_panel.dart # Historique du client
│   │   └── main.dart              # Point d'entrée Flutter avec thème CarRent
│   └── pubspec.yaml
│
└── admin_dashboard/
    ├── index.html                 # Tableau de bord Admin Web
    └── clients.js                 # Connexion et gestion des clients
```

---

## ⚙️ 3. Démarrage Rapide

### A. Démarrer le Backend (Node.js & MongoDB)
1. Ouvrez un terminal dans le dossier `backend` :
   ```bash
   cd backend
   npm install
   ```
2. Créez votre fichier `.env` ou copiez `.env.example` :
   ```bash
   cp .env.example .env
   ```
   Pour Gmail, activez la validation en deux étapes sur votre compte Google, puis créez un mot de passe d'application dans les paramètres de sécurité Google. Dans `backend/.env`, renseignez `SMTP_USER` avec votre adresse Gmail complète et `SMTP_PASS` avec ce mot de passe d'application (pas le mot de passe normal du compte). La configuration `SMTP_HOST=smtp.gmail.com`, `SMTP_PORT=587` et `SMTP_SECURE=false` est déjà préparée. `SMTP_FROM` peut rester vide ; l'adresse Gmail sera utilisée. Ne partagez pas le mot de passe d'application et ne le commitez pas. Sans ces deux valeurs, l'API refuse l'envoi du code et aucun compte n'est créé.
3. Initialisez la base de données avec des comptes de test :
   ```bash
   node seed.js
   ```
   > Attention : le seed supprime les utilisateurs déjà présents dans la base avant de créer les comptes de test.
   *Comptes générés :*
   - **Admin :** `admin@carrent.com` / `adminpassword123`
   - **Client Actif :** `alexandre.dupont@email.com` / `password123`
   - **Client en attente de permis :** `sarah.benali@email.com` / `password123`
   - **Client suspendu :** `julien.martin@email.com` / `password123`

4. Démarrez le serveur Express :
   ```bash
   npm start
   ```
   > Serveur disponible sur `http://localhost:5000`

### Historique des locations
- `GET /api/users/profile/rentals` — historique du client connecté (JWT).
- `GET /api/users/:id` — dossier complet du client (JWT administrateur), hors mot de passe.
- `GET /api/users/:id/rentals` — historique d'un client (JWT administrateur).

Les locations sont stockées dans `Rental` et doivent être créées par un module de réservation. En l'absence de réservations, l'application affiche un état vide plutôt que des locations fictives.

### Vérification email à l'inscription
- `POST /api/users/email-verifications` avec `{ "email": "client@example.com" }` envoie un code à 6 chiffres valable 10 minutes (renvoi limité à une demande par minute).
- `POST /api/users/register` exige `emailVerificationCode` en plus des informations du compte. Le code et tous les autres champs restent dans le formulaire d'inscription initial ; le compte n'est créé qu'après vérification du code.
- Un code est limité à 5 tentatives et son empreinte est stockée en base ; le code brut n'est jamais enregistré.

---

### B. Lancer le Front-office Mobile (Flutter)
1. Ouvrez un terminal dans le dossier `mobile_carrent` :
   ```bash
   cd mobile_carrent
   flutter pub get
   ```
2. Lancez l'application sur un émulateur ou appareil :
   ```bash
   flutter run
   ```
   *(Note : l'URL API pointe automatiquement sur `10.0.2.2:5000` sur Android Emulator et `localhost:5000` sur iOS/Web/Desktop)*.

---

### C. Ouvrir le Dashboard Administrateur (Web)
Servez le dossier `admin_dashboard` depuis un serveur HTTP local et ouvrez sa page `index.html`. Connectez-vous avec le compte administrateur de test indiqué plus haut. La recherche, les filtres, la pagination, la validation des permis, la gestion des comptes et leur historique utilisent l'API Node.js (`http://localhost:5000/api/users`).
