require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');

const reservationRoutes = require('./routes/reservationRoutes');

const app = express();
const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI;

app.use(express.json());
app.use('/reservations', reservationRoutes);

// Mongoose connection states: 0, 1, 2 and 3 respectively.
const databaseStates = ['disconnected', 'connected', 'connecting', 'disconnecting'];

app.get('/health', (req, res) => {
  // HTTP 200 means the server responds, not that MongoDB is connected.
  res.status(200).json({
    server: 'running',
    database: {
      configured: Boolean(MONGO_URI),
      connected: mongoose.connection.readyState === 1,
      status: MONGO_URI
        ? databaseStates[mongoose.connection.readyState] || 'unknown'
        : 'not_configured'
    }
  });
});

if (MONGO_URI) {
  mongoose
    .connect(MONGO_URI, { serverSelectionTimeoutMS: 5000 })
    .then(() => console.log('Connecté à MongoDB avec succès'))
    .catch(() => {
      // Do not log the connection URI: it could contain private credentials.
      console.error(
        'Connexion MongoDB impossible. Vérifiez MONGO_URI et le serveur MongoDB.'
      );
    });
} else {
  console.warn(
    'MONGO_URI non configurée. Copiez .env.example vers .env et configurez MongoDB.'
  );
}

app.listen(PORT, () => {
  console.log(`Serveur CarRent démarré sur http://localhost:${PORT}`);
});
