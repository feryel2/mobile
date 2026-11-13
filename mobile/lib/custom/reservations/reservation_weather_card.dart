import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../services/weather_service.dart';
import '../../utils/app_theme.dart';

class ReservationWeatherCard extends StatefulWidget {
  final DateTime pickupDate;
  final String pickupLocation;
  final WeatherService weatherService;

  const ReservationWeatherCard({
    super.key,
    required this.pickupDate,
    required this.pickupLocation,
    this.weatherService = const WeatherService(),
  });

  @override
  State<ReservationWeatherCard> createState() => _ReservationWeatherCardState();
}

class _ReservationWeatherCardState extends State<ReservationWeatherCard> {
  static const _ink = Color(0xFF102047);
  static const _muted = Color(0xFF5D6678);
  late Future<PickupForecast?> _forecast;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  @override
  void didUpdateWidget(covariant ReservationWeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.pickupDate, widget.pickupDate) ||
        oldWidget.pickupLocation != widget.pickupLocation ||
        oldWidget.weatherService != widget.weatherService) {
      _loadForecast();
    }
  }

  void _loadForecast() {
    _forecast = widget.weatherService.getPickupForecast(
      pickupDate: widget.pickupDate,
      pickupLocation: widget.pickupLocation,
    );
  }

  String _condition(int code) {
    switch (code) {
      case 0:
      case 1:
        return 'Ensoleillé';
      case 2:
        return 'Partiellement nuageux';
      case 3:
        return 'Nuageux';
      case 45:
      case 48:
        return 'Brouillard';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return 'Pluie';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'Neige';
      case 95:
      case 96:
      case 97:
      case 99:
        return 'Orage';
      default:
        return 'Conditions variables';
    }
  }

  Widget _forecastDetails(PickupForecast forecast) {
    final temperature = forecast.maxTemperatureCelsius.toStringAsFixed(1);
    final degrees = temperature.endsWith('.0')
        ? temperature.substring(0, temperature.length - 2)
        : temperature.replaceAll('.', ',');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Localizations.override(
          context: context,
          locale: const Locale('fr'),
          delegates: GlobalMaterialLocalizations.delegates,
          child: Builder(builder: (context) {
            final dates = MaterialLocalizations.of(context);
            return Text(
              '${dates.formatDecimal(forecast.date.day)} ${dates.formatMonthYear(forecast.date)}',
              style: const TextStyle(color: _muted),
            );
          }),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$degrees°C',
              style: const TextStyle(
                color: AppTheme.blue,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _condition(forecast.weatherCode),
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const Text('Température max. prévue', style: TextStyle(color: _muted)),
        const SizedBox(height: 6),
        const Text(
          'Prévisions indicatives · Source : Open-Meteo',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD9DFEA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.wb_cloudy_outlined,
                color: AppTheme.blue, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Météo prévue au départ',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
                  ),
                  FutureBuilder<PickupForecast?>(
                    future: _forecast,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.blue,
                              semanticsLabel: 'Chargement de la météo',
                            ),
                          ),
                        );
                      }
                      final forecast = snapshot.data;
                      if (forecast == null) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Prévisions météo non disponibles pour ce départ.',
                            style: TextStyle(color: _muted),
                          ),
                        );
                      }
                      return _forecastDetails(forecast);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
