import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'admin_hub_screen.dart';
import 'password_reset_screen.dart';
import 'profile_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _verificationEmail;

  // Contrôleurs de texte
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licenseController = TextEditingController();
  final _emailVerificationCodeController = TextEditingController();

  static const Color primaryColor = Color(0xFF0052CC);
  static const Color backgroundColor = Color(0xFFF8F9FA);

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _licenseController.dispose();
    _emailVerificationCodeController.dispose();
    super.dispose();
  }

  void _openAdminDashboard() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AdminHubScreen(),
        ),
      );
    }
  }

  Future<void> _openPasswordReset() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PasswordResetScreen(
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
    if (!mounted || email == null) return;
    setState(() {
      _emailController.text = email;
      _passwordController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mot de passe modifié. Connectez-vous avec le nouveau.'),
        backgroundColor: Color(0xFF28A745),
      ),
    );
  }

  Future<void> _sendVerificationCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Saisissez une adresse email valide avant de demander le code.'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _userService.sendEmailVerificationCode(email: email);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _verificationEmail = email;
        _emailVerificationCodeController.clear();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Impossible d’envoyer le code.',
        ),
        backgroundColor: result['success'] == true
            ? const Color(0xFF28A745)
            : const Color(0xFFDC3545),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin &&
        _verificationEmail != _emailController.text.trim().toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Vérifiez votre adresse email avant de créer le compte.'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_isLogin) {
      final result = await _userService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final user = result['user'] as User;
        if (user.role == 'admin') {
          final handoff = await _userService.createAdminDashboardTicket();
          if (!mounted) return;
          if (handoff['success'] != true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(handoff['message'] ?? 'Accès admin impossible.'),
                backgroundColor: const Color(0xFFDC3545),
              ),
            );
            return;
          }
          _openAdminDashboard();
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['cacheWarning']?.toString() ??
                  'Connexion réussie ! Bienvenue sur CarRent.',
            ),
            backgroundColor: result['cacheWarning'] == null
                ? const Color(0xFF28A745)
                : const Color(0xFFFF9800),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Échec de connexion'),
            backgroundColor: const Color(0xFFDC3545),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final result = await _userService.register(
        fullname: _fullnameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        driverLicenseNumber: _licenseController.text.trim().isNotEmpty
            ? _licenseController.text.trim()
            : null,
        emailVerificationCode: _emailVerificationCodeController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['cacheWarning']?.toString() ??
                  'Compte créé avec succès ! Bienvenue.',
            ),
            backgroundColor: result['cacheWarning'] == null
                ? const Color(0xFF28A745)
                : const Color(0xFFFF9800),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Échec de l\'inscription'),
            backgroundColor: const Color(0xFFDC3545),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Logo CarRent
                _buildLogoHeader(),
                const SizedBox(height: 30),

                // Onglet bascule Connexion / Inscription
                _buildAuthToggle(),
                const SizedBox(height: 24),

                // Carte Formulaire stylisée Figma
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isLogin
                              ? 'Bon retour parmi nous !'
                              : 'Rejoignez CarRent',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isLogin
                              ? 'Connectez-vous pour louer votre prochain véhicule'
                              : 'Créez votre compte en quelques secondes',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Champ Nom Complet (Inscription seulement)
                        if (!_isLogin) ...[
                          _buildTextField(
                            controller: _fullnameController,
                            label: 'Nom complet',
                            hint: 'Jean Dupont',
                            icon: Icons.person_outline,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Veuillez saisir votre nom complet'
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Champ Email
                        _buildTextField(
                          controller: _emailController,
                          label: 'Adresse Email',
                          hint: 'exemple@domaine.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Veuillez renseigner votre email';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                .hasMatch(v.trim())) {
                              return 'Format d\'email non valide';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            final email = value.trim().toLowerCase();
                            if (_verificationEmail != null &&
                                email != _verificationEmail) {
                              setState(() {
                                _verificationEmail = null;
                                _emailVerificationCodeController.clear();
                              });
                            }
                          },
                        ),
                        if (!_isLogin) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed:
                                  _isLoading ? null : _sendVerificationCode,
                              icon: const Icon(Icons.mark_email_unread_outlined,
                                  size: 18),
                              label: Text(
                                _verificationEmail == null
                                    ? 'Envoyer le code de vérification'
                                    : 'Renvoyer le code',
                              ),
                            ),
                          ),
                          _buildTextField(
                            controller: _emailVerificationCodeController,
                            label: 'Code de vérification email',
                            hint: 'Saisissez le code à 6 chiffres',
                            icon: Icons.verified_user_outlined,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null ||
                                  !RegExp(r'^\d{6}$').hasMatch(value.trim())) {
                                return 'Saisissez le code à 6 chiffres reçu par email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _verificationEmail ==
                                    _emailController.text.trim().toLowerCase()
                                ? 'Code envoyé à $_verificationEmail. Il expire dans 10 minutes.'
                                : 'Demandez le code ici, puis saisissez-le dans ce même formulaire.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Champ Téléphone (Inscription seulement)
                        if (!_isLogin) ...[
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Numéro de téléphone',
                            hint: '+33 6 12 34 56 78',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Veuillez saisir votre numéro de téléphone'
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Champ Numéro de permis (Optionnel à l'inscription)
                        if (!_isLogin) ...[
                          _buildTextField(
                            controller: _licenseController,
                            label: 'Numéro de permis (optionnel)',
                            hint: 'DL-123456-FR',
                            icon: Icons.credit_card_outlined,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Champ Mot de Passe
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Mot de passe',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Veuillez saisir votre mot de passe';
                            }
                            if (v.length < 6) {
                              return 'Au moins 6 caractères requis';
                            }
                            return null;
                          },
                        ),

                        if (_isLogin) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _openPasswordReset,
                              child: const Text(
                                'Mot de passe oublié ?',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 20),
                        ],

                        const SizedBox(height: 10),

                        // Bouton Pilule Principal
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 3,
                            shadowColor: primaryColor.withOpacity(0.4),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  _isLogin
                                      ? 'Se connecter'
                                      : 'Créer mon compte',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  '© 2024 CarRent - Tous droits réservés',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.directions_car_filled_rounded,
            size: 42,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            text: 'Car',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(
                text: 'Rent',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Location de véhicules premium & accessible',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildAuthToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isLogin) {
                  setState(() {
                    _isLogin = true;
                    _verificationEmail = null;
                    _emailVerificationCodeController.clear();
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isLogin ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: _isLogin
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Text(
                  'Se connecter',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isLogin ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isLogin) {
                  setState(() {
                    _isLogin = false;
                    _verificationEmail = null;
                    _emailVerificationCodeController.clear();
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isLogin ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: !_isLogin
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Text(
                  'Créer un compte',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isLogin ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            prefixIcon: Icon(icon, color: primaryColor, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: backgroundColor,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
