const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const cors = require('cors');
const express = require('express');
const mongoose = require('mongoose');

const userRoutes = require('./routes/users');
const vehicleRoutes = require('./routes/vehicleRoutes');
const reservationRoutes = require('./routes/reservationRoutes');
const User = require('./models/User');
const AdminLoginTicket = require('./models/AdminLoginTicket');
const EmailVerification = require('./models/EmailVerification');
const PasswordResetCode = require('./models/PasswordResetCode');
const Vehicle = require('./models/Vehicle');
const Reservation = require('./models/Reservation');

const app = express();

app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/admin', express.static(path.join(__dirname, '../admin_dashboard')));

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
  });
});

app.use('/api/users', userRoutes);
app.use('/api/vehicles', vehicleRoutes);
app.use('/api/reservations', reservationRoutes);

app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route introuvable.' });
});

app.use((err, req, res, next) => {
  console.error('Erreur serveur :', err.message);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Une erreur serveur inattendue est survenue.'
  });
});

async function startServer() {
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
    throw new Error('JWT_SECRET doit être configurée avec au moins 32 caractères.');
  }

  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/carrent_db';
  await mongoose.connect(mongoUri);
  await Promise.all([
    User.createIndexes(),
    AdminLoginTicket.createIndexes(),
    EmailVerification.createIndexes(),
    PasswordResetCode.createIndexes(),
    Vehicle.createIndexes(),
    Reservation.createIndexes()
  ]);

  const port = Number(process.env.PORT) || 5000;
  return app.listen(port, '0.0.0.0', () => {
    console.log(`API CarRent disponible sur http://localhost:${port}`);
  });
}

if (require.main === module) {
  startServer().catch((error) => {
    console.error('Démarrage de l’API impossible :', error.message);
    process.exitCode = 1;
  });
}

module.exports = { app, startServer };
