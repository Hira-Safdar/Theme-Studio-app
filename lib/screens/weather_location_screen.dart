import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/native_bridge_service.dart';

/// Weather widget tap (ya Widgets tab ka "Location" footnote tap) isi screen
/// par le aata hai. Yahan sirf ek hi kaam hota hai: user jo bhi city choose
/// kare, wahi humari saari jagah (in-app preview + pinned Home Screen widget)
/// ke liye "source of truth" ban jaati hai -- koi silent GPS auto-detect
/// nahi, koi random external weather app nahi.
class WeatherLocationScreen extends StatefulWidget {
  const WeatherLocationScreen({super.key});

  @override
  State<WeatherLocationScreen> createState() => _WeatherLocationScreenState();
}

class _WeatherLocationScreenState extends State<WeatherLocationScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _loadingCurrent = true;
  String? _currentLocation;
  String? _currentTemp;
  String? _currentCondition;
  String? _feelsLike;
  String? _humidity;
  String? _wind;
  List<Map<String, String>> _hourly = [];

  bool _searching = false;
  List<Map<String, dynamic>> _results = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Sirf cached values padhta hai -- na GPS, na network call. Jo bhi
  /// pehle se saved hai (ya kabhi choose hi nahi ki gayi to null) wahi
  /// dikhata hai.
  Future<void> _loadCurrent() async {
    setState(() => _loadingCurrent = true);
    final label = await NativeBridgeService.instance.getSavedWeatherLocation();
    final snapshot = await NativeBridgeService.instance.getWeatherSnapshot();
    if (!mounted) return;
    setState(() {
      _currentLocation = label;
      _currentTemp = snapshot['temperature'] as String?;
      _currentCondition = snapshot['condition'] as String?;
      _feelsLike = snapshot['feelsLike'] as String?;
      _humidity = snapshot['humidity'] as String?;
      _wind = snapshot['wind'] as String?;
      _hourly = (snapshot['hourly'] as List<Map<String, String>>?) ?? [];
      _loadingCurrent = false;
    });
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    final results = await NativeBridgeService.instance.searchWeatherLocations(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  /// Open-Meteo "2026-07-24T15:00" jaisa ISO-ish local time deta hai --
  /// yahan se sirf ghanta nikal ke "3 PM" / "12 AM" jaisa chhota label
  /// banate hain, hourly strip ke liye.
  String _formatHour(String isoTime) {
    final tIndex = isoTime.indexOf('T');
    if (tIndex == -1 || tIndex + 3 > isoTime.length) return isoTime;
    final hourStr = isoTime.substring(tIndex + 1, tIndex + 3);
    final hour = int.tryParse(hourStr);
    if (hour == null) return isoTime;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    var displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;
    return '$displayHour $suffix';
  }

  /// Condition ka chhota keyword check karke ek representative icon choose
  /// karta hai -- exact weather-code mapping Dart side nahi chahiye, native
  /// side ka human-readable label hi kaafi hai.
  IconData _iconForCondition(String? condition) {
    final c = (condition ?? '').toLowerCase();
    if (c.contains('thunder')) return Icons.thunderstorm_outlined;
    if (c.contains('snow')) return Icons.ac_unit;
    if (c.contains('rain') || c.contains('drizzle')) return Icons.water_drop_outlined;
    if (c.contains('fog')) return Icons.foggy;
    if (c.contains('overcast') || c.contains('cloud')) return Icons.cloud_outlined;
    if (c.contains('clear')) return Icons.wb_sunny_outlined;
    return Icons.thermostat_outlined;
  }

  String _formatResultLabel(Map<String, dynamic> r) {
    final parts = [r['name'], r['admin1'], r['country']]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  Future<void> _selectResult(Map<String, dynamic> r) async {
    final label = _formatResultLabel(r);
    final lat = (r['lat'] as num?)?.toDouble();
    final lon = (r['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return;

    setState(() => _saving = true);
    final ok = await NativeBridgeService.instance.setWeatherLocation(
      lat: lat,
      lon: lon,
      label: label,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _searchController.clear();
      setState(() => _results = []);
      FocusScope.of(context).unfocus();
      await _loadCurrent();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't set that location — try again")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weather location')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Current location + live snapshot — same source the pinned
          // widget reads from, so this is always exactly what's on the
          // Home Screen.
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: AppTheme.level1(context, radius: AppRadius.mdRadius),
            child: _loadingCurrent
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    children: [
                       Icon(Icons.location_on_outlined,
                           color: AppTheme.accentPrimary(context), size: 28),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentLocation ?? 'No location selected yet',
                              style: AppTypography.body,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentLocation == null
                                  ? 'Search below to choose one'
                                  : (_currentCondition ?? 'Waiting for weather…'),
                              style: AppTypography.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                      if (_currentTemp != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(_currentTemp!, style: AppTypography.heading),
                      ],
                    ],
                  ),
          ),

          // Feels-like / humidity / wind — only shown once we actually have
          // at least one of them cached (first fetch after choosing a city).
          if (!_loadingCurrent &&
              (_feelsLike != null || _humidity != null || _wind != null)) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.cardPadding,
                vertical: AppSpacing.sm,
              ),
              decoration: AppTheme.level1(context, radius: AppRadius.mdRadius),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (_feelsLike != null)
                    _WeatherStat(
                      icon: Icons.thermostat_outlined,
                      label: 'Feels like',
                      value: _feelsLike!,
                    ),
                  if (_humidity != null)
                    _WeatherStat(
                      icon: Icons.water_drop_outlined,
                      label: 'Humidity',
                      value: _humidity!,
                    ),
                  if (_wind != null)
                    _WeatherStat(
                      icon: Icons.air,
                      label: 'Wind',
                      value: _wind!,
                    ),
                ],
              ),
            ),
          ],

          // Hourly forecast strip — next few hours, horizontally scrollable.
          if (!_loadingCurrent && _hourly.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text('Hourly forecast', style: AppTypography.label),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _hourly.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final hour = _hourly[index];
                  return Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    decoration: AppTheme.level1(context, radius: AppRadius.mdRadius),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          index == 0 ? 'Now' : _formatHour(hour['time'] ?? ''),
                          style: AppTypography.bodySecondary.copyWith(fontSize: 11),
                        ),
                        Icon(
                          _iconForCondition(hour['condition']),
                          size: 20,
                          color: AppTheme.accentPrimary(context),
                        ),
                        Text(hour['temp'] ?? '--°', style: AppTypography.body),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          const Text('Search for a city', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'e.g. Lahore, London, Tokyo',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null),
              filled: true,
              fillColor: AppTheme.surface(context),
              border: OutlineInputBorder(
                borderRadius: AppRadius.smRadius,
                borderSide: BorderSide(color: AppTheme.borderSubtle(context)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_results.isEmpty && _searchController.text.trim().length >= 2 && !_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('No matching cities found', style: AppTypography.bodySecondary),
            )
          else
            ..._results.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: AppTheme.level1(context, radius: AppRadius.mdRadius),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                  leading: const Icon(Icons.place_outlined),
                  title: Text(_formatResultLabel(r), style: AppTypography.body),
                  onTap: () => _selectResult(r),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small icon + label + value column, used for Feels-like/Humidity/Wind.
class _WeatherStat extends StatelessWidget {
  const _WeatherStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.accentPrimary(context)),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.body),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.bodySecondary.copyWith(fontSize: 10)),
      ],
    );
  }
}