
import 'package:flutter/material.dart';
import '../services/currency_service.dart';

/// Carte affichant le prix d'un véhicule converti en EUR et USD
/// grâce à l'API externe de taux de change.
class PriceConversion extends StatefulWidget {
  final double prixDt;
  const PriceConversion({super.key, required this.prixDt});

  @override
  State<PriceConversion> createState() => _PriceConversionState();
}

class _PriceConversionState extends State<PriceConversion> {
  late Future<Map<String, double>> future;

  @override
  void initState() {
    super.initState();
    future = CurrencyService().getRates();
  }

  void retry() {
    setState(() {
      future = CurrencyService().getRates();
    });
  }

  Widget _line(String code, String symbol, double amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(code, style: const TextStyle(color: Colors.grey)),
      const Spacer(),
      Text('$symbol ${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
    ]),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.currency_exchange,
            size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        const Text('Prix converti',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      FutureBuilder<Map<String, double>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Row(children: [
              const Expanded(
                child: Text('Conversion indisponible (hors ligne ?)',
                    style: TextStyle(color: Colors.grey)),
              ),
              TextButton(onPressed: retry, child: const Text('Réessayer')),
            ]);
          }
          final rates = snapshot.data!;
          final eur = rates['EUR'];
          final usd = rates['USD'];
          return Column(children: [
            if (eur != null) _line('Euro (EUR)', '€', widget.prixDt * eur),
            if (usd != null)
              _line('Dollar (USD)', '\$', widget.prixDt * usd),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('Taux fournis par ExchangeRate-API',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ]);
        },
      ),
    ]),
  );
}
