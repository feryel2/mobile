const mongoose = require('mongoose');
const User = require('./models/User');
const Vehicle = require('./models/Vehicle');
require('dotenv').config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/carrent_db';

async function createUserIfMissing(userData) {
  const existingUser = await User.findOne({ email: userData.email }).select('_id');
  if (existingUser) {
    console.log(`Compte déjà présent, conservé : ${userData.email}`);
    return false;
  }

  await new User(userData).save();
  return true;
}

const seedDatabase = async () => {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('Connecté à MongoDB pour le seed...');

    const admin = {
      fullname: 'Administrateur CarRent',
      email: 'admin@carrent.com',
      emailVerified: true,
      password: 'adminpassword123',
      phone: '+33 6 12 34 56 78',
      role: 'admin',
      status: 'active',
      avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&h=200&fit=crop&crop=faces'
    };

    // Créer des comptes clients d'exemple
    const clients = [
      {
        fullname: 'Alexandre Dupont',
        email: 'alexandre.dupont@email.com',
        emailVerified: true,
        password: 'password123',
        phone: '+33 6 98 76 54 32',
        role: 'client',
        status: 'active',
        avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=faces',
        driverLicense: {
          number: 'DL-758921-FR',
          issuedDate: new Date('2020-04-15'),
          photoUrl: 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=600'
        }
      },
      {
        fullname: 'Sarah Benali',
        email: 'sarah.benali@email.com',
        emailVerified: true,
        password: 'password123',
        phone: '+33 7 45 12 89 63',
        role: 'client',
        status: 'pending_approval',
        avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop&crop=faces',
        driverLicense: {
          number: 'DL-882319-FR',
          issuedDate: new Date('2023-08-20'),
          photoUrl: 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=600'
        }
      },
      {
        fullname: 'Julien Martin',
        email: 'julien.martin@email.com',
        emailVerified: true,
        password: 'password123',
        phone: '+33 6 11 22 33 44',
        role: 'client',
        status: 'suspended',
        avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&crop=faces',
        driverLicense: {
          number: 'DL-341902-FR',
          issuedDate: new Date('2018-02-10'),
          photoUrl: ''
        }
      }
    ];

    const demoUsers = [admin, ...clients];
    const insertedUsers = [];
    for (const user of demoUsers) {
      if (await createUserIfMissing(user)) insertedUsers.push(user);
    }

    const vehicles = [
      {
        marque: 'Toyota',
        modele: 'Yaris',
        immatriculation: 'DEMO-001',
        annee: 2023,
        prix: 120,
        kilometrage: 18000,
        carburant: 'Essence',
        disponible: true,
        image: 'toyota yaris.png'
      },
      {
        marque: 'Hyundai',
        modele: 'Tucson',
        immatriculation: 'DEMO-002',
        annee: 2022,
        prix: 190,
        kilometrage: 26000,
        carburant: 'Diesel',
        disponible: true,
        image: 'car_suv_grise.png'
      },
      {
        marque: 'Renault',
        modele: 'Clio',
        immatriculation: 'DEMO-003',
        annee: 2024,
        prix: 105,
        kilometrage: 9000,
        carburant: 'Hybride',
        disponible: true,
        image: 'car_citadine_rouge.png'
      }
    ];

    for (const vehicle of vehicles) {
      await Vehicle.updateOne(
        { immatriculation: vehicle.immatriculation },
        { $setOnInsert: vehicle },
        { upsert: true }
      );
    }

    console.log('✅ Base de données initialisée avec succès !');
    console.log('Les véhicules de démonstration ont été ajoutés s’ils étaient absents.');
    if (insertedUsers.length > 0) {
      console.log('Comptes de démonstration nouvellement créés :');
      for (const user of insertedUsers) {
        console.log(`${user.email} / ${user.password}`);
      }
    }

    process.exit(0);
  } catch (error) {
    console.error('Erreur seed :', error);
    process.exit(1);
  }
};

seedDatabase();
