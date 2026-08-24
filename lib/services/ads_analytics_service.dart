import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore mein ad events log karta hai — impressions, clicks,
/// rewarded completions. Dashboard ke liye Firebase Console mein
/// Firestore > Collections dekho.
class AdsAnalyticsService {
  AdsAnalyticsService._();
  static final AdsAnalyticsService instance = AdsAnalyticsService._();

  final _db = FirebaseFirestore.instance;

  bool get _enabled => !_kEmulatorMode;
  static const _kEmulatorMode = false; // local testing ke liye flip to true

  String get _platform => Platform.isAndroid ? 'android' : 'ios';

  // ── Impression ──────────────────────────────────────────────────────
  Future<void> logImpression({
    required String adType,
    required String placement,
    String? themeId,
  }) async {
    if (!_enabled) return;
    try {
      await _db.collection('ad_impressions').add({
        'adType': adType,
        'placement': placement,
        if (themeId != null) 'themeId': themeId,
        'platform': _platform,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AdsAnalytics: impression log failed: $e');
    }
  }

  // ── Click ───────────────────────────────────────────────────────────
  Future<void> logClick({
    required String adType,
    required String placement,
    String? themeId,
  }) async {
    if (!_enabled) return;
    try {
      await _db.collection('ad_clicks').add({
        'adType': adType,
        'placement': placement,
        if (themeId != null) 'themeId': themeId,
        'platform': _platform,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AdsAnalytics: click log failed: $e');
    }
  }

  // ── Rewarded completed ──────────────────────────────────────────────
  Future<void> logRewardedCompleted({
    required String placement,
    String? themeId,
  }) async {
    if (!_enabled) return;
    try {
      await _db.collection('rewarded_completions').add({
        'placement': placement,
        if (themeId != null) 'themeId': themeId,
        'platform': _platform,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AdsAnalytics: rewarded log failed: $e');
    }
  }
}
