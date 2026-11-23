import 'package:savebite_mobile/request_board/models/food_request.dart';

/// Model respons baca untuk penawaran bantuan (`RequestOfferSerializer`).
class RequestOffer {
  final int id;
  final int requestId;
  final RequestOwner offeredBy;
  final DateTime createdAt;
  final bool isSelected;

  const RequestOffer({
    required this.id,
    required this.requestId,
    required this.offeredBy,
    required this.createdAt,
    required this.isSelected,
  });

  factory RequestOffer.fromJson(Map<String, dynamic> json) {
    return RequestOffer(
      id: (json['id'] as num).toInt(),
      requestId: (json['request_id'] as num).toInt(),
      offeredBy: RequestOwner.fromJson(
        json['offered_by'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      isSelected: json['is_selected'] as bool? ?? false,
    );
  }
}
