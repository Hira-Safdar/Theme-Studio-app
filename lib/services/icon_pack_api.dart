import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/online_icon_pack.dart';

/// Fetches online icon packs from bundled JSON, with optional remote endpoint
/// override and local cache.
class IconPackApi {
  IconPackApi._();
  static final IconPackApi instance = IconPackApi._();

  static const _cacheKey = 'icon_packs_cache_v2';
  static const _cacheTimeKey = 'icon_packs_cache_time_v2';
  static const _ttl = Duration(hours: 6);

  /// Remote endpoint URL — JSON array of packs. If set, overrides bundled.
  String? endpointUrl;

  List<OnlineIconPack>? _packs;
  bool _loading = false;
  String? _error;

  List<OnlineIconPack> get packs => _packs ?? [];
  bool get isLoading => _loading;
  String? get error => _error;

  /// Fetch packs — network (if endpoint set), then bundled JSON, then cache.
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

      // 2. Bundled asset JSON (primary source)
      try {
        final bundled = await _loadBundled();
        if (bundled.isNotEmpty) {
          _packs = bundled;
          _loading = false;
          return _packs!;
        }
      } catch (_) {}

      // 3. Fallback to cache
      final cached = await _loadCache();
      if (cached != null && cached.isNotEmpty) {
        _packs = cached;
        _loading = false;
        return _packs!;
      }

      // 4. Absolute fallback — empty
      _packs = [];
      _loading = false;
      return _packs!;
    } catch (e) {
      _error = e.toString();
      try {
        _packs = await _loadBundled();
      } catch (_) {
        _packs = [];
      }
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

  Future<List<OnlineIconPack>> _loadBundled() async {
    final raw = await rootBundle.loadString('assets/pack_catalog.json');
    final List<dynamic> jsonList = json.decode(raw);
    return jsonList
        .map((e) => OnlineIconPack.fromJson(e as Map<String, dynamic>))
        .toList();
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
