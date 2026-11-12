const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const driverLicenseSchema = new mongoose.Schema({
  number: {
    type: String,
    trim: true,
    default: ''
  },
  issuedDate: {
    type: Date,
    default: null
  },
  photoUrl: {
    type: String,
    default: ''
  }
}, { _id: false });

const userSchema = new mongoose.Schema({
  fullname: {
    type: String,
    required: [true, 'Le nom complet est requis'],
    trim: true
  },
  email: {
    type: String,
    required: [true, "L'email est requis"],
    unique: true,
    lowercase: true,
    trim: true,
    match: [
      /^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,})+$/,
      'Veuillez renseigner un email valide'
    ]
  },
  emailVerified: {
    type: Boolean,
    default: true
  },
  password: {
    type: String,
    required: [true, 'Le mot de passe est requis'],
    minlength: [6, 'Le mot de passe doit comporter au moins 6 caractères']
  },
  phone: {
    type: String,
    required: [true, 'Le numéro de téléphone est requis'],
    trim: true
  },
  avatar: {
    type: String,
    default: ''
  },
  driverLicense: {
    type: driverLicenseSchema,
    default: () => ({})
  },
  role: {
    type: String,
    enum: ['client', 'admin'],
    default: 'client'
  },
  status: {
    type: String,
    enum: ['active', 'suspended', 'pending_approval'],
    default: 'active'
  }
}, {
  timestamps: true,
  toJSON: {
    transform: function (doc, ret) {
      delete ret.password;
      delete ret.__v;
      return ret;
    }
  }
});

// Hashage automatique du mot de passe avant sauvegarde
userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Méthode de vérification du mot de passe
userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model('User', userSchema);
