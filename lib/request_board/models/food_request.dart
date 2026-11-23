/// Konstanta pilihan satuan bahan makanan yang didukung oleh backend.
const List<String> unitChoices = [
  'gram',
  'kg',
  'ml',
  'liter',
  'buah',
  'butir',
  'ikat',
  'porsi',
];

/// Konstanta pilihan pengurutan daftar request.
const List<String> sortChoices = [
  'newest',
  'oldest',
];

/// Status yang tersimpan di database backend.
const List<String> storedStatusChoices = [
  'pending',
  'offered',
  'fulfilled',
];

/// Status yang dapat digunakan sebagai query filter (termasuk `expired`).
const List<String> filterStatusChoices = [
  'pending',
  'offered',
  'fulfilled',
  'expired',
];

/// Representasi pemilik (pembuat) sebuah food request.
class RequestOwner {
  final int id;
  final String displayName;

  const RequestOwner({
    required this.id,
    required this.displayName,
  });

  factory RequestOwner.fromJson(Map<String, dynamic> json) {
    return RequestOwner(
      id: (json['id'] as num).toInt(),
      displayName: json['display_name'] as String? ?? '',
    );
  }

  /// Serialisasi untuk kebutuhan cache offline lokal.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
    };
  }
}

/// Model respons baca untuk endpoint request (`RequestSerializer`).
class FoodRequest {
  final int id;
  final RequestOwner owner;
  final String title;
  final String foodItem;
  final String quantity;
  final String unit;
  final String description;
  final String location;
  final String status;
  final String effectiveStatus;
  final DateTime? expiresAt;
  final int offerCount;
  final bool hasOffered;
  final int? selectedOfferId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FoodRequest({
    required this.id,
    required this.owner,
    required this.title,
    required this.foodItem,
    required this.quantity,
    required this.unit,
    required this.description,
    required this.location,
    required this.status,
    required this.effectiveStatus,
    this.expiresAt,
    required this.offerCount,
    required this.hasOffered,
    this.selectedOfferId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Mengembalikan `true` selama request belum terpenuhi maupun kedaluwarsa.
  bool get isActive =>
      effectiveStatus != 'fulfilled' && effectiveStatus != 'expired';

  factory FoodRequest.fromJson(Map<String, dynamic> json) {
    return FoodRequest(
      id: (json['id'] as num).toInt(),
      owner: RequestOwner.fromJson(json['owner'] as Map<String, dynamic>),
      title: json['title'] as String? ?? '',
      foodItem: json['food_item'] as String? ?? '',
      quantity: json['quantity'].toString(),
      unit: json['unit'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      status: json['status'] as String? ?? '',
      effectiveStatus: json['effective_status'] as String? ?? '',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      offerCount: (json['offer_count'] as num?)?.toInt() ?? 0,
      hasOffered: json['has_offered'] as bool? ?? false,
      selectedOfferId: (json['selected_offer_id'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Khusus untuk penyimpanan cache offline lokal (jangan dipakai untuk POST).
  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'owner': owner.toJson(),
      'title': title,
      'food_item': foodItem,
      'quantity': quantity,
      'unit': unit,
      'description': description,
      'location': location,
      'status': status,
      'effective_status': effectiveStatus,
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'offer_count': offerCount,
      'has_offered': hasOffered,
      'selected_offer_id': selectedOfferId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

/// Payload ketat untuk `POST /api/v1/requests/` sesuai allowlist backend.
class FoodRequestCreatePayload {
  final String title;
  final String foodItem;
  final String quantity;
  final String unit;
  final String description;
  final String location;
  final DateTime? expiresAt;

  const FoodRequestCreatePayload({
    required this.title,
    required this.foodItem,
    required this.quantity,
    required this.unit,
    this.description = '',
    this.location = '',
    this.expiresAt,
  });

  /// Mengeluarkan hanya 7 field allowlist dan menghilangkan `expires_at` jika null.
  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'title': title,
      'food_item': foodItem,
      'quantity': quantity,
      'unit': unit,
      'description': description,
      'location': location,
    };

    if (expiresAt != null) {
      payload['expires_at'] = expiresAt!.toUtc().toIso8601String();
    }

    return payload;
  }
}
