import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'auth_screen.dart';
import 'admin_hub_screen.dart';
import 'reservations/reservation_history_api_screen.dart';
import 'reservations/reservation_search_screen.dart';
import 'vehicle_management_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userService});

  final UserService? userService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final UserService _userService;
  final ImagePicker _picker = ImagePicker();

  User? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentIndex = 3; // Index 3 = Profil
  final _profileFormKey = GlobalKey<FormState>();

  // Contrôleurs
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  DateTime? _selectedIssuedDate;
  File? _avatarFile;
  File? _licenseFile;

  static const Color primaryColor = Color(0xFF0052CC);
  static const Color successColor = Color(0xFF28A745);
  static const Color dangerColor = Color(0xFFDC3545);
  static const Color backgroundColor = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    final result = await _userService.getProfile();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final user = result['user'] as User;
      setState(() {
        _currentUser = user;
        _fullnameController.text = user.fullname;
        _emailController.text = user.email;
        _phoneController.text = user.phone;
        _licenseNumberController.text = user.driverLicense.number;
        _selectedIssuedDate = user.driverLicense.issuedDate;
      });
      final notice = result['offline'] == true
          ? 'Profil affiché depuis le cache hors ligne.'
          : result['cacheWarning']?.toString();
      if (notice != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notice)),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erreur lors du chargement'),
          backgroundColor: dangerColor,
        ),
      );
    }
  }

  Future<void> _openAdminDashboard() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminHubScreen(),
      ),
    );
  }

  // Sélection d'image avec image_picker
  Future<void> _pickImage(bool isAvatar) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          if (isAvatar) {
            _avatarFile = File(pickedFile.path);
          } else {
            _licenseFile = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sélection image : $e')),
        );
      }
    }
  }

  // Sauvegarde des modifications du profil
  Future<void> _saveProfile() async {
    if (_currentUser == null) return;
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final result = await _userService.updateProfile(
      fullname: _fullnameController.text.trim(),
      phone: _phoneController.text.trim(),
      driverLicenseNumber: _licenseNumberController.text.trim(),
      driverLicenseIssuedDate: _selectedIssuedDate,
      avatarFilePath: _avatarFile?.path,
      licenseFilePath: _licenseFile?.path,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      setState(() {
        _currentUser = result['user'] as User;
        _avatarFile = null;
        _licenseFile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['cacheWarning']?.toString() ??
                'Profil mis à jour avec succès !',
          ),
          backgroundColor: result['cacheWarning'] == null
              ? successColor
              : const Color(0xFFFF9800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result['message'] ?? 'Erreur lors de l\'enregistrement'),
          backgroundColor: dangerColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final emailController =
        TextEditingController(text: _currentUser?.email ?? '');
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var codeSent = false;
    var isBusy = false;
    var resendSeconds = 0;
    String? message;
    var isError = false;
    Timer? cooldownTimer;

    void startCooldown(
      BuildContext dialogContext,
      StateSetter setDialogState,
      int seconds,
    ) {
      cooldownTimer?.cancel();
      setDialogState(() => resendSeconds = seconds);
      if (seconds <= 0) return;
      cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!dialogContext.mounted) {
          timer.cancel();
          return;
        }
        setDialogState(() {
          resendSeconds--;
          if (resendSeconds <= 0) timer.cancel();
        });
      });
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> sendCode() async {
            final email = emailController.text.trim().toLowerCase();
            final emailIsValid = RegExp(
              r'^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,})+$',
            ).hasMatch(email);
            if (!emailIsValid) {
              setDialogState(() {
                message = 'Veuillez saisir une adresse email valide.';
                isError = true;
              });
              return;
            }
            if (email == _currentUser?.email.toLowerCase()) {
              setDialogState(() {
                message = 'Cette adresse est déjà associée à votre compte.';
                isError = true;
              });
              return;
            }

            setDialogState(() {
              isBusy = true;
              message = null;
            });
            final response =
                await _userService.sendEmailVerificationCode(email: email);
            if (!dialogContext.mounted) return;
            setDialogState(() {
              isBusy = false;
              isError = response['success'] != true;
              message = response['message']?.toString();
              if (response['success'] == true) {
                codeSent = true;
                codeController.clear();
              }
            });
            if (response['success'] == true) {
              startCooldown(
                dialogContext,
                setDialogState,
                (response['resendAfterSeconds'] as num?)?.toInt() ?? 60,
              );
            }
          }

          Future<void> confirmChange() async {
            if (!codeSent || !formKey.currentState!.validate()) return;
            setDialogState(() {
              isBusy = true;
              message = null;
            });
            final response = await _userService.changeEmail(
              email: emailController.text,
              code: codeController.text,
            );
            if (!dialogContext.mounted) return;
            if (response['success'] == true) {
              Navigator.of(dialogContext).pop(response);
              return;
            }
            setDialogState(() {
              isBusy = false;
              isError = true;
              message = response['message']?.toString();
            });
          }

          return AlertDialog(
            title: const Text('Modifier l’adresse email'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Un code sera envoyé à la nouvelle adresse pour confirmer le changement.',
                    ),
                    if (isBusy) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      enabled: !isBusy,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Nouvelle adresse email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return RegExp(
                          r'^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,})+$',
                        ).hasMatch(email)
                            ? null
                            : 'Saisissez une adresse email valide.';
                      },
                      onChanged: (_) {
                        if (codeSent) {
                          setDialogState(() {
                            codeSent = false;
                            codeController.clear();
                            message = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isBusy || resendSeconds > 0 ? null : sendCode,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(
                        resendSeconds > 0
                            ? 'Renvoyer le code dans ${resendSeconds}s'
                            : codeSent
                                ? 'Renvoyer le code'
                                : 'Envoyer le code',
                      ),
                    ),
                    if (codeSent) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: codeController,
                        enabled: !isBusy,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Code reçu par email',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                          counterText: '',
                        ),
                        validator: (value) =>
                            value != null && RegExp(r'^\d{6}$').hasMatch(value)
                                ? null
                                : 'Saisissez le code à 6 chiffres.',
                      ),
                    ],
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        message!,
                        style: TextStyle(
                          color: isError ? dangerColor : successColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isBusy ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: isBusy || !codeSent ? null : confirmChange,
                child: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );
    cooldownTimer?.cancel();
    await WidgetsBinding.instance.endOfFrame;
    emailController.dispose();
    codeController.dispose();

    if (!mounted || result == null || result['success'] != true) return;
    final user = result['user'] as User;
    setState(() {
      _currentUser = user;
      _emailController.text = user.email;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['cacheWarning']?.toString() ??
              'Adresse email modifiée et vérifiée.',
        ),
        backgroundColor: result['cacheWarning'] == null
            ? successColor
            : const Color(0xFFFF9800),
      ),
    );
  }

  // Dialogue de changement de mot de passe
  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Modifier le mot de passe',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: currentPassController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe actuel',
                        prefixIcon:
                            const Icon(Icons.lock_outline, color: primaryColor),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Veuillez renseigner le mot de passe actuel'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPassController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon:
                            const Icon(Icons.lock_reset, color: primaryColor),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Saisissez le nouveau mot de passe';
                        }
                        if (v.length < 6) {
                          return 'Minimum 6 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPassController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Confirmer le nouveau mot de passe',
                        prefixIcon:
                            const Icon(Icons.lock_reset, color: primaryColor),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) {
                        if (v != newPassController.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(ctx);
                          final res = await _userService.changePassword(
                            currentPassword: currentPassController.text,
                            newPassword: newPassController.text,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? ''),
                              backgroundColor: res['success'] == true
                                  ? successColor
                                  : dangerColor,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Valider la modification',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text(
            'Êtes-vous sûr de vouloir vous déconnecter de CarRent ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _userService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: _currentIndex == 0
          ? VehicleListScreen(canManage: _currentUser?.role == 'admin')
          : _currentIndex == 1
              ? ReservationSearchScreen(client: _currentUser)
              : _currentIndex == 2
                  ? ReservationHistoryApiScreen(client: _currentUser)
                  : _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: primaryColor))
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              // 1. Header Bleu avec Photo de Profil et Bouton Caméra
                              _buildProfileHeader(),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20.0, vertical: 16.0),
                                child: Column(
                                  children: [
                                    // Badge Statut Compte
                                    _buildStatusBadge(),
                                    const SizedBox(height: 16),

                                    // Card Informations Personnelles
                                    _buildPersonalDetailsCard(),
                                    const SizedBox(height: 16),

                                    // Card Permis de Conduire
                                    _buildDriverLicenseCard(),
                                    const SizedBox(height: 24),

                                    // Bouton "Modifier le mot de passe"
                                    OutlinedButton.icon(
                                      onPressed: _showChangePasswordDialog,
                                      icon: const Icon(Icons.key,
                                          color: primaryColor),
                                      label: const Text(
                                        'Modifier le mot de passe',
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: primaryColor, width: 1.5),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14, horizontal: 24),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                        minimumSize: const Size.fromHeight(50),
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    // Bouton Pillule "Enregistrer"
                                    ElevatedButton(
                                      onPressed:
                                          _isSaving ? null : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        minimumSize: const Size.fromHeight(52),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                        elevation: 4,
                                        shadowColor:
                                            primaryColor.withOpacity(0.4),
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Enregistrer les modifications',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Bouton Se Déconnecter
                                    TextButton.icon(
                                      onPressed: _logout,
                                      icon: const Icon(Icons.logout,
                                          color: dangerColor),
                                      label: const Text(
                                        'Se déconnecter',
                                        style: TextStyle(
                                          color: dangerColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

      // 5. Barre de Navigation Inférieure (Bottom Navigation Bar)
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // --- WIDGETS COMPOSANTS ---

  Widget _buildProfileHeader() {
    final avatarUrl = _currentUser?.avatar ?? '';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.only(top: 50, bottom: 28, left: 20, right: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mon Profil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (_currentUser?.role == 'admin')
                    IconButton(
                      icon: const Icon(Icons.admin_panel_settings_outlined,
                          color: Colors.white),
                      onPressed: _openAdminDashboard,
                      tooltip: 'Espace administrateur',
                    ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white70),
                    onPressed: _logout,
                    tooltip: 'Déconnexion',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avatar avec badge caméra
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue[100],
                  backgroundImage: _avatarFile != null
                      ? FileImage(_avatarFile!)
                      : (avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null)
                          as ImageProvider?,
                  child: (_avatarFile == null && avatarUrl.isEmpty)
                      ? const Icon(Icons.person, size: 55, color: primaryColor)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _pickImage(true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentUser?.fullname ?? 'Client CarRent',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _currentUser?.email ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (_currentUser == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _currentUser!.statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _currentUser!.statusColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _currentUser!.isActive
                ? Icons.check_circle
                : (_currentUser!.isPendingApproval
                    ? Icons.hourglass_top_rounded
                    : Icons.cancel),
            color: _currentUser!.statusColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            _currentUser!.statusLabel,
            style: TextStyle(
              color: _currentUser!.statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.badge_outlined, color: primaryColor, size: 22),
                SizedBox(width: 8),
                Text(
                  'Informations Personnelles',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInputLabel('Nom complet'),
            TextFormField(
              controller: _fullnameController,
              decoration: _inputDecoration('Jean Dupont', Icons.person_outline),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.length < 2) {
                  return 'Saisissez un nom d’au moins 2 caractères.';
                }
                if (name.length > 80) {
                  return 'Le nom ne peut pas dépasser 80 caractères.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildInputLabel('Adresse Email'),
            TextFormField(
              controller: _emailController,
              readOnly: true,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: _inputDecoration(
                'exemple@domaine.com',
                Icons.email_outlined,
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: 'Modifier l’adresse email',
                  onPressed: _isSaving ? null : _showChangeEmailDialog,
                  icon: const Icon(Icons.edit_outlined, color: primaryColor),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Le changement nécessite un code de vérification.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 14),
            _buildInputLabel('Numéro de téléphone'),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration:
                  _inputDecoration('+33 6 12 34 56 78', Icons.phone_outlined),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.length < 7 || digits.length > 15) {
                  return 'Saisissez un numéro valide (7 à 15 chiffres).';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverLicenseCard() {
    final licensePhotoUrl = _currentUser?.driverLicense.photoUrl ?? '';
    final hasExistingPhoto = licensePhotoUrl.isNotEmpty;
    final dateStr = _selectedIssuedDate != null
        ? DateFormat('dd/MM/yyyy').format(_selectedIssuedDate!)
        : 'Sélectionner une date';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_car_filled_outlined,
                  color: primaryColor, size: 22),
              SizedBox(width: 8),
              Text(
                'Permis de Conduire',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInputLabel('Numéro de permis'),
          TextFormField(
            controller: _licenseNumberController,
            decoration: _inputDecoration('Ex: DL-789012-FR', Icons.credit_card),
          ),
          const SizedBox(height: 14),
          _buildInputLabel('Date de délivrance'),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedIssuedDate ?? DateTime(2020, 1, 1),
                firstDate: DateTime(1960),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedIssuedDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Text(dateStr, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInputLabel('Photo du permis de conduire'),
          const SizedBox(height: 6),

          // Aperçu ou Sélection de photo
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.grey[300]!, style: BorderStyle.solid),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _licenseFile != null
                  ? Image.file(_licenseFile!, fit: BoxFit.cover)
                  : (hasExistingPhoto
                      ? Image.network(
                          licensePhotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image,
                                size: 40, color: Colors.grey),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_camera_back_outlined,
                                size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Aucune photo de permis enregistrée',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        )),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () => _pickImage(false),
              icon: const Icon(Icons.upload_file, color: primaryColor),
              label: Text(
                hasExistingPhoto || _licenseFile != null
                    ? 'Changer la photo du permis'
                    : 'Téléverser le permis',
                style: const TextStyle(
                    color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: backgroundColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: 'Véhicules',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Réserver',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
