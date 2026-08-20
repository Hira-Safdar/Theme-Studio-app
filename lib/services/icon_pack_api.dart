import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/online_icon_pack.dart';

/// Fetches online icon packs from a remote JSON endpoint with local cache
/// and hardcoded fallback.
class IconPackApi {
  IconPackApi._();
  static final IconPackApi instance = IconPackApi._();

  static const _cacheKey = 'icon_packs_cache';
  static const _cacheTimeKey = 'icon_packs_cache_time';
  static const _ttl = Duration(hours: 6);

  /// Remote endpoint URL — JSON array of packs.
  /// Set this to your own backend, GitHub raw file, or any JSON host.
  String? endpointUrl;

  List<OnlineIconPack>? _packs;
  bool _loading = false;
  String? _error;

  List<OnlineIconPack> get packs => _packs ?? OnlineIconPack.curated;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isFromApi => _packs != null;

  /// Fetch packs — cache first, then network, then hardcoded fallback.
  Future<List<OnlineIconPack>> fetch({bool forceRefresh = false}) async {
    if (_loading) return packs;
    _loading = true;
    _error = null;

    try {
      // 1. Try network if endpoint is set
      if (endpointUrl != null && endpointUrl!.isNotEmpty) {
        if (!forceRefresh) {
          final cached = await _loadCache();
          if (cached != null && cached.isNotEmpty) {
            _packs = cached;
            _loading = false;
            return _packs!;
          }
        }

        try {
          final response = await http
              .get(Uri.parse(endpointUrl!))
              .timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final List<dynamic> jsonList = json.decode(response.body);
            final fetched = jsonList
                .map((e) => OnlineIconPack.fromJson(e as Map<String, dynamic>))
                .toList();

            if (fetched.isNotEmpty) {
              _packs = fetched;
              await _saveCache(fetched);
              _loading = false;
              return _packs!;
            }
          }
        } catch (e) {
          _error = e.toString();
        }
      }

      // 2. Fallback to cached data
      final cached = await _loadCache();
      if (cached != null && cached.isNotEmpty) {
        _packs = cached;
        _loading = false;
        return _packs!;
      }

      // 3. Final fallback — hardcoded curated
      _packs = OnlineIconPack.curated;
      _loading = false;
      return _packs!;
    } catch (e) {
      _error = e.toString();
      _packs = OnlineIconPack.curated;
      _loading = false;
      return _packs!;
    }
  }

  /// Search/filter packs by name, description, or author.
  List<OnlineIconPack> search(String query) {
    if (query.isEmpty) return packs;
    final q = query.toLowerCase();
    return packs.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.author.toLowerCase().contains(q);
    }).toList();
  }

  Future<List<OnlineIconPack>?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimeKey);
      if (timestamp == null) return null;

      final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cachedAt) > _ttl) return null;

      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;

      final List<dynamic> jsonList = json.decode(raw);
      return jsonList
          .map((e) => OnlineIconPack.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(List<OnlineIconPack> packs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = packs.map((p) => p.toJson()).toList();
      await prefs.setString(_cacheKey, json.encode(jsonList));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimeKey);
    } catch (_) {}
  }
}
