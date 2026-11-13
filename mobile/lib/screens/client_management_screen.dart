import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class ClientManagementScreen extends StatefulWidget {
  const ClientManagementScreen({super.key});

  @override
  State<ClientManagementScreen> createState() => _ClientManagementScreenState();
}

class _ClientManagementScreenState extends State<ClientManagementScreen> {
  final UserService _userService = UserService();
  late Future<List<User>> _futureUsers;
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'suspended'

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    setState(() {
      _futureUsers = _userService.getAllUsers().then((res) {
        if (res['success'] == true) {
          return res['users'] as List<User>;
        } else {
          throw Exception(res['message'] ?? 'Erreur de chargement');
        }
      });
    });
  }

  void _showAddClientDialog() {
    final formKey = GlobalKey<FormState>();
    final fullnameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final licenseController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Color(0xFF0B47C9)),
              SizedBox(width: 10),
              Text('Nouveau Client'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: fullnameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet *',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe *',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (v) => v == null || v.length < 6 ? 'Minimum 6 caractères' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone *',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: licenseController,
                    decoration: const InputDecoration(
                      labelText: 'N° de permis (optionnel)',
                      prefixIcon: Icon(Icons.card_membership_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B47C9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      final res = await _userService.createClient(
                        fullname: fullnameController.text.trim(),
                        email: emailController.text.trim(),
                        password: passwordController.text,
                        phone: phoneController.text.trim(),
                        driverLicenseNumber: licenseController.text.trim(),
                      );
                      setDialogState(() => isLoading = false);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res['message'] ?? (res['success'] == true ? 'Client ajouté avec succès' : 'Erreur')),
                          backgroundColor: res['success'] == true ? const Color(0xFF28A745) : const Color(0xFFDC3545),
                        ),
                      );
                      if (res['success'] == true) {
                        _loadUsers();
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Créer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(User user, String newStatus) async {
    final res = await _userService.updateUserStatus(user.id, newStatus);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? (res['success'] == true ? 'Statut mis à jour' : 'Erreur')),
        backgroundColor: res['success'] == true ? const Color(0xFF28A745) : const Color(0xFFDC3545),
      ),
    );
    if (res['success'] == true) {
      _loadUsers();
    }
  }

  Future<void> _deleteClient(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer le client ${user.fullname} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC3545),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _userService.deleteUser(user.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? (res['success'] == true ? 'Client supprimé' : 'Erreur')),
        backgroundColor: res['success'] == true ? const Color(0xFF28A745) : const Color(0xFFDC3545),
      ),
    );
    if (res['success'] == true) {
      _loadUsers();
    }
  }

  void _showClientDetails(User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF0B47C9).withValues(alpha: 0.1),
                  backgroundImage: user.avatar.isNotEmpty ? NetworkImage(user.avatar) : null,
                  child: user.avatar.isEmpty
                      ? Text(
                          user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : 'C',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0B47C9)),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullname,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: user.statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user.statusLabel,
                          style: TextStyle(color: user.statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _detailRow(Icons.email_outlined, 'Email', user.email),
            const SizedBox(height: 12),
            _detailRow(Icons.phone_outlined, 'Téléphone', user.phone),
            const SizedBox(height: 12),
            _detailRow(Icons.card_membership, 'Permis de conduire', user.driverLicense.number.isNotEmpty ? user.driverLicense.number : 'Non renseigné'),
            const SizedBox(height: 12),
            _detailRow(Icons.calendar_today_outlined, 'Compte créé le', user.createdAt != null ? user.createdAt.toString().split(' ')[0] : 'Inconnu'),
            const SizedBox(height: 24),
            Row(
              children: [
                if (user.role != 'admin') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: user.isActive ? const Color(0xFFDC3545) : const Color(0xFF28A745),
                        side: BorderSide(color: user.isActive ? const Color(0xFFDC3545) : const Color(0xFF28A745)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _updateStatus(user, user.isActive ? 'suspended' : 'active');
                      },
                      icon: Icon(user.isActive ? Icons.block : Icons.check_circle_outline),
                      label: Text(user.isActive ? 'Suspendre' : 'Activer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC3545),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _deleteClient(user);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Gestion des Clients', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0B47C9),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddClientDialog,
        backgroundColor: const Color(0xFF0B47C9),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Nouveau client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Barre de recherche et filtres de statut
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, email, téléphone...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0B47C9)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Tous'),
                        selected: _statusFilter == 'all',
                        onSelected: (selected) => setState(() => _statusFilter = 'all'),
                        selectedColor: const Color(0xFF0B47C9).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _statusFilter == 'all' ? const Color(0xFF0B47C9) : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Actifs'),
                        selected: _statusFilter == 'active',
                        onSelected: (selected) => setState(() => _statusFilter = 'active'),
                        selectedColor: const Color(0xFF28A745).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _statusFilter == 'active' ? const Color(0xFF28A745) : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Suspendus'),
                        selected: _statusFilter == 'suspended',
                        onSelected: (selected) => setState(() => _statusFilter = 'suspended'),
                        selectedColor: const Color(0xFFDC3545).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _statusFilter == 'suspended' ? const Color(0xFFDC3545) : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<User>>(
              future: _futureUsers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC3545)),
                          const SizedBox(height: 12),
                          const Text(
                            'Accès refusé ou erreur de chargement',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${snapshot.error}\n\nAssurez-vous d’être connecté avec un compte Administrateur (ex: admin@carrent.com).',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadUsers,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final users = (snapshot.data ?? []).where((u) {
                  final name = u.fullname.toLowerCase();
                  final email = u.email.toLowerCase();
                  final phone = u.phone.toLowerCase();
                  final matchesSearch = name.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      phone.contains(_searchQuery);

                  final matchesStatus = _statusFilter == 'all' || u.status == _statusFilter;

                  return matchesSearch && matchesStatus;
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('Aucun client trouvé', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showClientDetails(user),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF0B47C9).withValues(alpha: 0.1),
                                backgroundImage: user.avatar.isNotEmpty ? NetworkImage(user.avatar) : null,
                                child: user.avatar.isEmpty
                                    ? Text(
                                        user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : 'C',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B47C9)),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              user.fullname,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: user.statusColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              user.statusLabel,
                                              style: TextStyle(
                                                color: user.statusColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(user.email, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text(user.phone, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                    ],
                                  ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
