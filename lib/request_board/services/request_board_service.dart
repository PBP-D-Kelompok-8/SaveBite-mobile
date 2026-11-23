import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/models/paginated_response.dart';
import 'package:savebite_mobile/request_board/models/request_creation_status.dart';
import 'package:savebite_mobile/request_board/models/request_offer.dart';
import 'package:savebite_mobile/request_board/services/session_client.dart';

/// Exception jaringan / timeout saat berkomunikasi dengan server SaveBite.
class RequestBoardNetworkException implements Exception {
  final String message;
  final Object? cause;

  const RequestBoardNetworkException(this.message, {this.cause});

  @override
  String toString() => message;
}

/// Exception dasar untuk respons error HTTP dari API DRF `request_board`.
class RequestBoardApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final dynamic rawBody;

  const RequestBoardApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.rawBody,
  });

  @override
  String toString() => message;
}

/// Exception `400 Bad Request` dengan peta error validasi per field.
class RequestBoardValidationException extends RequestBoardApiException {
  final Map<String, String> fieldErrors;

  const RequestBoardValidationException({
    required this.fieldErrors,
    required super.message,
    super.code,
    super.rawBody,
  }) : super(statusCode: 400);
}

/// Exception `403 Forbidden` (tamu atau tidak memiliki izin).
class RequestBoardForbiddenException extends RequestBoardApiException {
  const RequestBoardForbiddenException({
    required super.message,
    super.code,
    super.rawBody,
  }) : super(statusCode: 403);
}

/// Exception `404 Not Found`.
class RequestBoardNotFoundException extends RequestBoardApiException {
  const RequestBoardNotFoundException({
    required super.message,
    super.code,
    super.rawBody,
  }) : super(statusCode: 404);
}

/// Exception `409 Conflict` beserta `code` bisnis (`offers_closed`,
/// `request_expired`, `request_fulfilled`, `offer_selection_required`,
/// `idempotency_conflict`, `idempotency_deleted`).
class RequestBoardConflictException extends RequestBoardApiException {
  const RequestBoardConflictException({
    required super.message,
    super.code,
    super.rawBody,
  }) : super(statusCode: 409);
}

/// Service layer untuk integrasi modul Request Board dengan REST API
/// Django SaveBite (`/api/v1/`).
class RequestBoardService {
  final SaveBiteSessionClient sessionClient;

  RequestBoardService({
    SaveBiteSessionClient? sessionClient,
  }) : sessionClient = sessionClient ?? SaveBiteSessionClient();

  String get baseUrl => sessionClient.baseUrl;

  /// Mengambil daftar request terpaginasi (`GET /api/v1/requests/`).
  Future<PaginatedResponse<FoodRequest>> fetchRequests({
    int page = 1,
    String? query,
    String? status,
    bool mine = false,
    String? sort,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
    };

    final trimmedQuery = query?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      queryParams['q'] =
          trimmedQuery.length > 120 ? trimmedQuery.substring(0, 120) : trimmedQuery;
    }

    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    if (mine) {
      queryParams['mine'] = 'true';
    }

    if (sort != null && sort.isNotEmpty) {
      queryParams['sort'] = sort;
    }

    final uri = Uri.parse('$baseUrl/api/v1/requests/')
        .replace(queryParameters: queryParams);

    final response = await _execute(() => sessionClient.send(
          method: 'GET',
          uri: uri,
        ));

    if (response.statusCode == 200) {
      final decoded = _decodeJsonMap(response);
      return PaginatedResponse<FoodRequest>.fromJson(
        decoded,
        FoodRequest.fromJson,
      );
    }

    throw _mapErrorResponse(response);
  }

  /// Mengambil detail satu request (`GET /api/v1/requests/<id>/`).
  Future<FoodRequest> fetchRequestDetail(int id) async {
    final uri = Uri.parse('$baseUrl/api/v1/requests/$id/');
    final response = await _execute(() => sessionClient.send(
          method: 'GET',
          uri: uri,
        ));

    if (response.statusCode == 200) {
      return FoodRequest.fromJson(_decodeJsonMap(response));
    }

    throw _mapErrorResponse(response);
  }

  /// Membuat request baru dengan header wajib `Idempotency-Key`
  /// (`POST /api/v1/requests/`). Menerima `201` (baru) maupun `200` (replay).
  Future<FoodRequest> createRequest(
    FoodRequestCreatePayload payload, {
    required String idempotencyKey,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/requests/');
    final response = await _execute(() => sessionClient.send(
          method: 'POST',
          uri: uri,
          contentType: 'application/json',
          extraHeaders: {'Idempotency-Key': idempotencyKey},
          body: jsonEncode(payload.toJson()),
        ));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return FoodRequest.fromJson(_decodeJsonMap(response));
    }

    throw _mapErrorResponse(response);
  }

  /// Memeriksa status pembuatan idempoten (`GET /api/v1/request-creations/<key>/`).
  /// Mengembalikan `null` apabila server merespons `404`.
  Future<RequestCreationStatus?> fetchRequestCreationStatus(
    String idempotencyKey,
  ) async {
    final uri = Uri.parse('$baseUrl/api/v1/request-creations/$idempotencyKey/');
    final response = await _execute(() => sessionClient.send(
          method: 'GET',
          uri: uri,
        ));

    if (response.statusCode == 200) {
      return RequestCreationStatus.fromJson(_decodeJsonMap(response));
    }

    if (response.statusCode == 404) {
      return null;
    }

    throw _mapErrorResponse(response);
  }

  /// Menghapus request milik sendiri (`DELETE /api/v1/requests/<id>/`).
  /// Mengirim body kosong dan mengharapkan `204 No Content`.
  Future<void> deleteRequest(int id) async {
    final uri = Uri.parse('$baseUrl/api/v1/requests/$id/');
    final response = await _execute(() => sessionClient.send(
          method: 'DELETE',
          uri: uri,
        ));

    if (response.statusCode == 204 || response.statusCode == 200) {
      return;
    }

    throw _mapErrorResponse(response);
  }

  /// Mengambil daftar penawar terpaginasi untuk owner
  /// (`GET /api/v1/requests/<id>/offers/`).
  Future<PaginatedResponse<RequestOffer>> fetchOffers(
    int requestId, {
    int page = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/requests/$requestId/offers/')
        .replace(queryParameters: {'page': page.toString()});

    final response = await _execute(() => sessionClient.send(
          method: 'GET',
          uri: uri,
        ));

    if (response.statusCode == 200) {
      final decoded = _decodeJsonMap(response);
      return PaginatedResponse<RequestOffer>.fromJson(
        decoded,
        RequestOffer.fromJson,
      );
    }

    throw _mapErrorResponse(response);
  }

  /// Mengirim penawaran bantuan (`POST /api/v1/requests/<id>/offers/`).
  /// Mengirim body `{}` dan menerima `201` (baru) maupun `200` (replay).
  Future<RequestOffer> submitOffer(int requestId) async {
    final uri = Uri.parse('$baseUrl/api/v1/requests/$requestId/offers/');
    final response = await _execute(() => sessionClient.send(
          method: 'POST',
          uri: uri,
          contentType: 'application/json',
          body: jsonEncode(const <String, dynamic>{}),
        ));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return RequestOffer.fromJson(_decodeJsonMap(response));
    }

    throw _mapErrorResponse(response);
  }

  /// Memilih atau mengganti penawar terpilih (`PATCH /api/v1/requests/<id>/selection/`).
  Future<FoodRequest> selectOffer(int requestId, int offerId) async {
    final uri = Uri.parse('$baseUrl/api/v1/requests/$requestId/selection/');
    final response = await _execute(() => sessionClient.send(
          method: 'PATCH',
          uri: uri,
          contentType: 'application/json',
          body: jsonEncode({'offer_id': offerId}),
        ));

    if (response.statusCode == 200) {
      return FoodRequest.fromJson(_decodeJsonMap(response));
    }

    throw _mapErrorResponse(response);
  }

  /// Menandai permintaan sebagai terpenuhi (`PATCH /api/v1/requests/<id>/status/`).
  Future<FoodRequest> fulfillRequest(int requestId) async {
    final uri = Uri.parse('$baseUrl/api/v1/requests/$requestId/status/');
    final response = await _execute(() => sessionClient.send(
          method: 'PATCH',
          uri: uri,
          contentType: 'application/json',
          body: jsonEncode({'status': 'fulfilled'}),
        ));

    if (response.statusCode == 200) {
      return FoodRequest.fromJson(_decodeJsonMap(response));
    }

    throw _mapErrorResponse(response);
  }

  Future<http.Response> _execute(Future<http.Response> Function() call) async {
    try {
      return await call();
    } on TimeoutException catch (e) {
      throw RequestBoardNetworkException(
        'Koneksi ke server melebihi batas waktu. Silakan coba lagi.',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw RequestBoardNetworkException(
        'Gagal terhubung ke server. Periksa koneksi internet Anda.',
        cause: e,
      );
    } on RequestBoardApiException {
      rethrow;
    } catch (e) {
      throw RequestBoardNetworkException(
        'Terjadi gangguan jaringan saat menghubungi server.',
        cause: e,
      );
    }
  }

  Map<String, dynamic> _decodeJsonMap(http.Response response) {
    if (response.body.isEmpty) {
      return const <String, dynamic>{};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw RequestBoardApiException(
      statusCode: response.statusCode,
      message: 'Format respons server tidak sesuai.',
      rawBody: decoded,
    );
  }

  RequestBoardApiException _mapErrorResponse(http.Response response) {
    dynamic decoded;
    try {
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      }
    } catch (_) {
      decoded = response.body;
    }

    String? detail;
    String? code;
    final fieldErrors = <String, String>{};

    if (decoded is Map<String, dynamic>) {
      if (decoded['detail'] != null) {
        detail = decoded['detail'].toString();
      }
      if (decoded['code'] != null) {
        code = decoded['code'].toString();
      }

      if (response.statusCode == 400) {
        for (final entry in decoded.entries) {
          if (entry.key == 'detail' || entry.key == 'code') continue;
          final value = entry.value;
          if (value is List && value.isNotEmpty) {
            fieldErrors[entry.key] = value.first.toString();
          } else if (value is String && value.isNotEmpty) {
            fieldErrors[entry.key] = value;
          }
        }
      }
    }

    switch (response.statusCode) {
      case 400:
        return RequestBoardValidationException(
          fieldErrors: fieldErrors,
          message: detail ??
              (fieldErrors.isNotEmpty
                  ? fieldErrors.values.first
                  : 'Data yang dikirim tidak valid.'),
          code: code,
          rawBody: decoded,
        );
      case 403:
        return RequestBoardForbiddenException(
          message: detail ??
              'Akses ditolak. Pastikan Anda sudah login dan sesi masih aktif.',
          code: code,
          rawBody: decoded,
        );
      case 404:
        return RequestBoardNotFoundException(
          message: detail ?? 'Data permintaan tidak ditemukan.',
          code: code,
          rawBody: decoded,
        );
      case 409:
        return RequestBoardConflictException(
          message: detail ?? 'Terjadi konflik status permintaan.',
          code: code,
          rawBody: decoded,
        );
      default:
        return RequestBoardApiException(
          statusCode: response.statusCode,
          message: detail ?? 'Terjadi kesalahan server (${response.statusCode}).',
          code: code,
          rawBody: decoded,
        );
    }
  }
}
