import 'package:flutter/material.dart';

import '../services/user_service.dart';
import 'auth_screen.dart';
import 'client_management_screen.dart';
import 'reservations/admin_reservations_screen.dart';
import 'vehicle_management_screen.dart';

class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen> {
  int _currentIndex = 0;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vous déconnecter de CarRent ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await UserService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRoot = ModalRoute.of(context)?.isFirst ?? true;
    return PopScope(
      canPop: !isRoot || _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isRoot && _currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Espace Administrateur'),
          backgroundColor: const Color(0xFF0B47C9),
          foregroundColor: Colors.white,
          actions: [
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Déconnexion'),
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HeroMode(
              enabled: _currentIndex == 0,
              child: const VehicleListScreen(canManage: true),
            ),
            HeroMode(
              enabled: _currentIndex == 1,
              child: const ClientManagementScreen(),
            ),
            if (_currentIndex == 2)
              const AdminReservationsScreen()
            else
              const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: const Color(0xFF0B47C9),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.car_rental),
              label: 'Parc',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Clients',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'Réservations',
            ),
          ],
        ),
      ),
    );
  }
}
