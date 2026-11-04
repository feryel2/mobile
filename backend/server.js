const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const userRoutes = require('./routes/users');

const app = express();

// Middlewares globaux
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rendre le dossier des uploads accessible publiquement
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes API
app.use('/api/users', userRoutes);

// Route de bienvenue / Health check
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Bienvenue sur l\'API CarRent - Module Gestion Client',
    version: '1.0.0',
    endpoints: {
      auth: ['POST /api/users/register', 'POST /api/users/login'],
      profile: ['GET /api/users/profile', 'PUT /api/users/profile', 'PUT /api/users/change-password'],
      admin: ['GET /api/users', 'PUT /api/users/:id/status', 'DELETE /api/users/:id']
    }
  });
});

// Middleware de gestion d'erreur globale
app.use((err, req, res, next) => {
  console.error('Erreur Serveur:', err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Une erreur serveur inattendue est survenue'
  });
});

// Connexion MongoDB et démarrage serveur
const PORT = process.env.PORT || 5000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/carrent_db';

mongoose
  .connect(MONGODB_URI)
  .then(() => {
    console.log('--------------------------------------------------');
    console.log('✅ Connecté avec succès à la base MongoDB (CarRent)');
    app.listen(PORT, () => {
      console.log(`🚀 Serveur backend CarRent démarré sur http://localhost:${PORT}`);
      console.log('--------------------------------------------------');
    });
  })
  .catch((err) => {
    console.error('❌ Erreur de connexion à MongoDB :', err.message);
  });
