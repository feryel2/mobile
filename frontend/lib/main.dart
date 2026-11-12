import 'widgets/price_conversion.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'models/vehicle.dart';
import 'services/vehicle_service.dart';

// ============================== Thème ==============================

const kPrimary = Color(0xFF0B47C9);
const kBackground = Color(0xFFEEF3FB);
const kTextGrey = Color(0xFF6B7280);

/// 45000 -> "45 000 DT"
String money(double v) {
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  final int = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
  return parts.length > 1 ? '$int,${parts[1]} DT' : '$int DT';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VehicleApp());
}

class VehicleApp extends StatelessWidget {
  const VehicleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Gestion des véhicules',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
      useMaterial3: true,
      scaffoldBackgroundColor: kBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        titleTextStyle: TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPrimary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
        ),
      ),
    ),
    home: const VehicleListScreen(),
  );
}

// ============================ Liste des véhicules ============================

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});
  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  final service = VehicleService();
  late Future<List<Vehicle>> future;
  String search = '';
  String filter = 'Toutes';
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  static const filters = ['Toutes', 'Essence', 'Diesel', 'Hybride', 'Electrique'];

  @override
  void initState() {
    super.initState();
    future = service.getAll();

    // Retour du réseau : envoyer les modifications faites hors ligne, puis recharger
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      if (results.any((r) => r != ConnectivityResult.none)) {
        await service.syncPending();
        if (mounted) {
          reload();
        }
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  void reload() {
    setState(() {
      future = service.getAll();
    });
  }

  Future<void> openForm([Vehicle? vehicle]) async {
    final saved = await Navigator.push<Vehicle>(
      context,
      MaterialPageRoute(builder: (_) => VehicleFormScreen(vehicle: vehicle)),
    );
    if (saved == null || !mounted) {
      return;
    }

    final isNew = vehicle == null;
    final offline = saved.syncStatus != 'synced';
    final text = offline
        ? 'Enregistré hors ligne. Synchronisation au retour du réseau.'
        : (isNew
        ? 'Véhicule ajouté avec succès.'
        : 'Véhicule modifié avec succès.');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: offline ? Colors.orange : Colors.green,
      ),
    );
    reload();
  }

  Future<void> remove(Vehicle vehicle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le véhicule ?'),
        content:
        Text('Voulez-vous supprimer ${vehicle.marque} ${vehicle.modele} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    try {
      await service.delete(vehicle);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Véhicule supprimé.')));
      reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void openDetail(Vehicle v) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleDetailScreen(
          vehicle: v,
          onEdit: () => openForm(v),
          onDelete: () => remove(v),
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: EdgeInsets.fromLTRB(
        16, MediaQuery.of(context).padding.top + 8, 16, 18),
    decoration: const BoxDecoration(
      color: kPrimary,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: Column(children: [
      Row(children: [
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Véhicules',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
        ),
        IconButton(
          tooltip: 'Actualiser',
          onPressed: reload,
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
      ]),
      const SizedBox(height: 8),
      TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Rechercher une voiture...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
      ),
    ]),
  );

  Widget _filters() => SizedBox(
    height: 44,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: filters.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final f = filters[i];
        final selected = f == filter;
        return ChoiceChip(
          label: Text(f),
          selected: selected,
          showCheckmark: false,
          selectedColor: kPrimary,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: selected ? kPrimary : Colors.grey.shade300)),
          onSelected: (_) => setState(() => filter = f),
        );
      },
    ),
  );

  Widget _card(Vehicle v) {
    final pending = v.syncStatus != 'synced';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openDetail(v),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: VehicleImage(image: v.image, size: 92),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text('${v.marque} ${v.modele}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    if (pending) ...[
                      const SizedBox(width: 6),
                      const Tooltip(
                        message: 'En attente de synchronisation',
                        child: Icon(Icons.cloud_off,
                            size: 16, color: Colors.orange),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: 28,
                      height: 24,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (action) {
                          if (action == 'detail') openDetail(v);
                          if (action == 'edit') openForm(v);
                          if (action == 'delete') remove(v);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'detail', child: Text('Consulter')),
                          PopupMenuItem(
                              value: 'edit', child: Text('Modifier')),
                          PopupMenuItem(
                              value: 'delete', child: Text('Supprimer')),
                        ],
                      ),
                    ),
                  ]),
                  Text('${v.carburant} • ${v.annee}',
                      style: const TextStyle(color: kTextGrey, fontSize: 13)),
                  Text(v.immatriculation,
                      style: const TextStyle(color: kTextGrey, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text(money(v.prix),
                          style: const TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                    _StatusBadge(available: v.disponible),
                  ]),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 32,
                      child: FilledButton(
                        onPressed: () => openDetail(v),
                        style: FilledButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 16)),
                        child: const Text('Voir détails',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => openForm(),
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Ajouter'),
    ),
    body: Column(children: [
      _header(),
      const SizedBox(height: 12),
      _filters(),
      const SizedBox(height: 8),
      Expanded(
        child: FutureBuilder<List<Vehicle>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(
                  message: snapshot.error.toString(), retry: reload);
            }
            final vehicles = (snapshot.data ?? [])
                .where((v) =>
                '${v.marque} ${v.modele} ${v.immatriculation}'
                    .toLowerCase()
                    .contains(search))
                .where((v) => filter == 'Toutes' || v.carburant == filter)
                .toList();
            if (vehicles.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.directions_car_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(search.isEmpty && filter == 'Toutes'
                      ? 'Aucun véhicule enregistré'
                      : 'Aucun résultat'),
                  const SizedBox(height: 8),
                  if (search.isEmpty && filter == 'Toutes')
                    FilledButton.icon(
                      onPressed: () => openForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un véhicule'),
                    ),
                ]),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                itemCount: vehicles.length,
                itemBuilder: (context, i) => _card(vehicles[i]),
              ),
            );
          },
        ),
      ),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final bool available;
  const _StatusBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    final color = available ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        available ? 'Disponible' : 'Indisponible',
        style: TextStyle(
            color: color.shade700, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const _ErrorView({required this.message, required this.retry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 52, color: Colors.redAccent),
        const SizedBox(height: 12),
        const Text('Impossible de charger les véhicules',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: retry, child: const Text('Réessayer')),
      ]),
    ),
  );
}

// ============================== Détails ==============================

class VehicleDetailScreen extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const VehicleDetailScreen(
      {super.key, required this.vehicle, this.onEdit, this.onDelete});

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Icon(icon, size: 20, color: kPrimary),
      const SizedBox(width: 12),
      Expanded(
          child: Text(label, style: const TextStyle(color: kTextGrey))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final synced = vehicle.syncStatus == 'synced';
    return Scaffold(
      appBar: AppBar(title: const Text('Détails du véhicule')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: VehicleImage(image: vehicle.image, size: 190),
            ),
            const SizedBox(height: 12),
            Text('${vehicle.marque} ${vehicle.modele}',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(vehicle.carburant,
                style: const TextStyle(color: kTextGrey)),
            const SizedBox(height: 10),
            _StatusBadge(available: vehicle.disponible),
            const SizedBox(height: 10),
            Text(money(vehicle.prix),
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: kPrimary)),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            _row(Icons.confirmation_number_outlined, 'Immatriculation',
                vehicle.immatriculation),
            const Divider(height: 1),
            _row(Icons.calendar_today_outlined, 'Année', '${vehicle.annee}'),
            const Divider(height: 1),
            _row(Icons.speed, 'Kilométrage', '${vehicle.kilometrage} km'),
            const Divider(height: 1),
            _row(Icons.local_gas_station_outlined, 'Carburant',
                vehicle.carburant),
            const Divider(height: 1),
            _row(synced ? Icons.cloud_done_outlined : Icons.cloud_off,
                'Synchronisation', synced ? 'Synchronisé' : 'En attente'),
          ]),
        ),
        const SizedBox(height: 14),
        PriceConversion(prixDt: vehicle.prix),
        const SizedBox(height: 18),
        if (onEdit != null)
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onEdit!();
            },
            icon: const Icon(Icons.edit),
            label: const Text('Modifier'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        if (onDelete != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onDelete!();
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Supprimer',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ]),
    );
  }
}

// ============================== Formulaire ==============================

class VehicleFormScreen extends StatefulWidget {
  final Vehicle? vehicle;
  const VehicleFormScreen({super.key, this.vehicle});
  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final formKey = GlobalKey<FormState>();
  final service = VehicleService();
  late final TextEditingController marque,
      modele,
      immatriculation,
      annee,
      prix,
      kilometrage;

  String carburant = 'Essence';
  bool disponible = true, saving = false;

  // Noms EXACTS des fichiers présents dans assets/images/
  static const imageOptions = [
    'kia_picanto.png',
    'peugeot-208.png',
    'renault-clio.png',
    'renault.png',
    'toyota_yaris.png',
  ];
  String image = 'default_car.png';

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    marque = TextEditingController(text: v?.marque ?? '');
    modele = TextEditingController(text: v?.modele ?? '');
    immatriculation = TextEditingController(text: v?.immatriculation ?? '');
    annee = TextEditingController(text: v?.annee.toString() ?? '');
    prix = TextEditingController(text: v?.prix.toString() ?? '');
    kilometrage = TextEditingController(text: v?.kilometrage.toString() ?? '');
    carburant = v?.carburant ?? 'Essence';
    disponible = v?.disponible ?? true;
    image = v?.image ?? 'default_car.png';
  }

  @override
  void dispose() {
    marque.dispose();
    modele.dispose();
    immatriculation.dispose();
    annee.dispose();
    prix.dispose();
    kilometrage.dispose();
    super.dispose();
  }

  String? requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label est obligatoire.';
    }
    if (value.trim().length < 2) {
      return '$label doit contenir au moins 2 caractères.';
    }
    return null;
  }

  String? positiveNumber(String? value, String label,
      {bool allowZero = false, bool integer = false}) {
    if (value == null || value.trim().isEmpty) {
      return '$label est obligatoire.';
    }
    final n = integer
        ? int.tryParse(value.trim())
        : double.tryParse(value.trim().replaceAll(',', '.'));
    if (n == null || (allowZero ? n < 0 : n <= 0)) {
      return '$label doit être ${allowZero ? 'positif ou nul' : 'supérieur à zéro'}.';
    }
    return null;
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez corriger les champs en rouge.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final year = int.parse(annee.text.trim());
    if (year < 1900 || year > DateTime.now().year + 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Année invalide.')));
      return;
    }
    setState(() => saving = true);

    final vehicle = Vehicle(
      marque: marque.text.trim(),
      modele: modele.text.trim(),
      immatriculation: immatriculation.text.trim().toUpperCase(),
      annee: year,
      prix: double.parse(prix.text.trim().replaceAll(',', '.')),
      kilometrage: int.parse(kilometrage.text.trim()),
      carburant: carburant,
      disponible: disponible,
      image: image,
    );

    try {
      final Vehicle saved;
      if (widget.vehicle == null) {
        saved = await service.create(vehicle);
      } else {
        saved = await service.update(widget.vehicle!, vehicle);
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget _imagePicker() => SizedBox(
    height: 96,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: imageOptions.map((name) {
        final selected = name == image;
        return GestureDetector(
          onTap: () => setState(() => image = name),
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? kPrimary : Colors.grey.shade300,
                width: selected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: VehicleImage(image: name, size: 88),
              ),
              if (selected)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: kPrimary,
                    child:
                    Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                ),
            ]),
          ),
        );
      }).toList(),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
        title: Text(widget.vehicle == null
            ? 'Ajouter un véhicule'
            : 'Modifier un véhicule')),
    body: Form(
      key: formKey,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Image du véhicule',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _imagePicker(),
        const SizedBox(height: 18),
        TextFormField(
          controller: marque,
          decoration: const InputDecoration(
              labelText: 'Marque *', prefixIcon: Icon(Icons.badge_outlined)),
          textCapitalization: TextCapitalization.words,
          validator: (v) => requiredText(v, 'La marque'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: modele,
          decoration: const InputDecoration(
              labelText: 'Modèle *',
              prefixIcon: Icon(Icons.directions_car_outlined)),
          textCapitalization: TextCapitalization.words,
          validator: (v) => requiredText(v, 'Le modèle'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: immatriculation,
          decoration: const InputDecoration(
              labelText: 'Immatriculation *',
              prefixIcon: Icon(Icons.confirmation_number_outlined)),
          textCapitalization: TextCapitalization.characters,
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return "L'immatriculation est obligatoire.";
            }
            if (v.trim().length < 3) {
              return 'Immatriculation trop courte.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: annee,
          decoration: const InputDecoration(
              labelText: 'Année *',
              prefixIcon: Icon(Icons.calendar_today_outlined)),
          keyboardType: TextInputType.number,
          validator: (v) {
            final err = positiveNumber(v, "L'année", integer: true);
            if (err != null) {
              return err;
            }
            final y = int.parse(v!.trim());
            if (y < 1900 || y > DateTime.now().year + 1) {
              return 'Saisir une année valide.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: prix,
          decoration: const InputDecoration(
              labelText: 'Prix (DT) *',
              prefixIcon: Icon(Icons.payments_outlined)),
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          validator: (v) => positiveNumber(v, 'Le prix'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: kilometrage,
          decoration: const InputDecoration(
              labelText: 'Kilométrage *', prefixIcon: Icon(Icons.speed)),
          keyboardType: TextInputType.number,
          validator: (v) => positiveNumber(v, 'Le kilométrage',
              allowZero: true, integer: true),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: carburant,
          decoration: const InputDecoration(
              labelText: 'Carburant *',
              prefixIcon: Icon(Icons.local_gas_station_outlined)),
          items: const ['Essence', 'Diesel', 'Hybride', 'Electrique']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => carburant = v ?? 'Essence'),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Véhicule disponible'),
          value: disponible,
          onChanged: (v) => setState(() => disponible = v),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: saving ? null : save,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
          icon: saving
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save),
          label: Text(saving ? 'Enregistrement...' : 'Enregistrer'),
        ),
      ]),
    ),
  );
}

// ============================== Image du véhicule ==============================

class VehicleImage extends StatelessWidget {
  final String? image;
  final double size;

  const VehicleImage({super.key, this.image, this.size = 65});

  @override
  Widget build(BuildContext context) {
    final imageName =
    image?.isNotEmpty == true ? image! : 'default_car.png';

    return Image.asset(
      'assets/images/$imageName',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          color: Colors.grey.shade200,
          child: Icon(
            Icons.directions_car,
            size: size * 0.5,
            color: Colors.grey,
          ),
        );
      },
    );
  }
}
