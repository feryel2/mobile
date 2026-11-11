require('dotenv').config();
const express = require('express');
const cors = require('cors');
const connectDB = require('./config/database');
const vehicleRoutes = require('./routes/vehicleRoutes');

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.get('/', (req, res) => res.json({ message: 'API Gestion des véhicules' }));
app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.use('/api/vehicles', vehicleRoutes);

// Réponse JSON pour les routes inconnues
app.use((req, res) => res.status(404).json({ message: 'Route introuvable.' }));

const PORT = process.env.PORT || 5000;
connectDB()
  .then(() => app.listen(PORT, '0.0.0.0', () => console.log(`API démarrée sur le port ${PORT}`)))
  .catch(err => { console.error('Connexion MongoDB impossible :', err.message); process.exit(1); });
