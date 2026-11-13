import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../utils/client_form_validators.dart';

class ClientFormDialog extends StatefulWidget {
  const ClientFormDialog({
    super.key,
    required this.userService,
    this.user,
  });

  final UserService userService;
  final User? user;

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullnameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _phoneController;
  late final TextEditingController _licenseController;
  var _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    _fullnameController =
        TextEditingController(text: widget.user?.fullname ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController = TextEditingController();
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
    _licenseController =
        TextEditingController(text: widget.user?.driverLicense.number ?? '');
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = widget.user;
    final result = user != null
        ? await widget.userService.updateClient(
            userId: user.id,
            fullname: _fullnameController.text.trim(),
            phone: _phoneController.text.trim(),
            driverLicenseNumber: _licenseController.text.trim(),
          )
        : await widget.userService.createClient(
            fullname: _fullnameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            phone: _phoneController.text.trim(),
            driverLicenseNumber: _licenseController.text.trim(),
          );
    if (!mounted) return;

    setState(() => _isLoading = false);
    if (result['success'] == true) {
      Navigator.of(context).pop(result);
    } else {
      setState(
        () => _errorMessage =
            result['message']?.toString() ?? 'Une erreur est survenue.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit_outlined : Icons.person_add,
            color: const Color(0xFF0B47C9),
          ),
          const SizedBox(width: 10),
          Text(_isEditing ? 'Modifier le client' : 'Nouveau Client'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('client-fullname'),
                controller: _fullnameController,
                decoration: const InputDecoration(
                  labelText: 'Nom complet *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: validateClientFullName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('client-email'),
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  helperText: _isEditing
                      ? 'Le client doit passer par le parcours de vérification.'
                      : null,
                ),
                readOnly: _isEditing,
                keyboardType: TextInputType.emailAddress,
                validator: validateClientEmail,
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('client-password'),
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe *',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: validateClientPassword,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('client-phone'),
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone *',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: validateClientPhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('client-license'),
                controller: _licenseController,
                decoration: InputDecoration(
                  labelText: 'N° de permis (optionnel)',
                  prefixIcon: const Icon(Icons.card_membership_outlined),
                  helperText: _isEditing
                      ? 'Une modification nécessitera une nouvelle validation.'
                      : null,
                ),
                validator: validateDriverLicenseNumber,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  key: const ValueKey('client-form-error'),
                  style: const TextStyle(color: Color(0xFFDC3545)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          key: const ValueKey('client-form-submit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B47C9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isEditing ? 'Enregistrer' : 'Créer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
