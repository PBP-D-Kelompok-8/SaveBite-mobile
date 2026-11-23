import 'dart:convert';

import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Draf pengajuan create request yang hasil pengirimannya belum pasti
/// (misalnya karena timeout atau gangguan jaringan).
///
/// Menyimpan `accountId`, `idempotencyKey` (UUID v4), dan salinan payload
/// pertama agar retry tetap memakai key dan payload yang sama pada akun semula
/// selama jendela 30 hari backend.
class PendingRequestDraft {
  final int accountId;
  final String idempotencyKey;
  final Map<String, dynamic> payloadJson;
  final DateTime createdAt;

  const PendingRequestDraft({
    required this.accountId,
    required this.idempotencyKey,
    required this.payloadJson,
    required this.createdAt,
  });

  FoodRequestCreatePayload toPayload() {
    return FoodRequestCreatePayload(
      title: payloadJson['title'] as String? ?? '',
      foodItem: payloadJson['food_item'] as String? ?? '',
      quantity: payloadJson['quantity']?.toString() ?? '0.00',
      unit: payloadJson['unit'] as String? ?? 'kg',
      description: payloadJson['description'] as String? ?? '',
      location: payloadJson['location'] as String? ?? '',
      expiresAt: payloadJson['expires_at'] != null
          ? DateTime.tryParse(payloadJson['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'idempotency_key': idempotencyKey,
      'payload': payloadJson,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory PendingRequestDraft.fromJson(Map<String, dynamic> json) {
    return PendingRequestDraft(
      accountId: (json['account_id'] as num).toInt(),
      idempotencyKey: json['idempotency_key'] as String,
      payloadJson: Map<String, dynamic>.from(
        json['payload'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Penyimpanan lokal berbasis `SharedPreferences` untuk draf idempoten create
/// request (terikat pada akun pembuat dan kedaluwarsa setelah 30 hari).
class PendingRequestDraftStore {
  static const String _storageKey = 'request_board_pending_create_draft_v1';
  static const Duration retentionWindow = Duration(days: 30);

  final Future<SharedPreferences> Function() _prefsProvider;

  PendingRequestDraftStore({
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  Future<PendingRequestDraft?> loadForAccount(
    int accountId, {
    DateTime? now,
  }) async {
    try {
      final prefs = await _prefsProvider();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await clear();
        return null;
      }

      final draft = PendingRequestDraft.fromJson(decoded);
      final currentTime = (now ?? DateTime.now()).toUtc();
      final isExpired =
          currentTime.difference(draft.createdAt.toUtc()) > retentionWindow;

      // Bersihkan draf bila milik akun berbeda atau sudah melewati 30 hari.
      if (draft.accountId != accountId || isExpired) {
        await clear();
        return null;
      }

      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PendingRequestDraft draft) async {
    try {
      final prefs = await _prefsProvider();
      await prefs.setString(_storageKey, jsonEncode(draft.toJson()));
    } catch (_) {
      // Kegagalan penyimpanan lokal tidak boleh memblokir form.
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await _prefsProvider();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Abaikan error pembersihan.
    }
  }
}
