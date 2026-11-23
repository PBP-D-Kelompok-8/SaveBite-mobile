/// Model status hasil lookup idempotensi (`GET /api/v1/request-creations/<key>/`).
class RequestCreationStatus {
  final String state;
  final int? requestId;

  const RequestCreationStatus({
    required this.state,
    this.requestId,
  });

  bool get isCreated => state == 'created';

  bool get isDeleted => state == 'deleted';

  factory RequestCreationStatus.fromJson(Map<String, dynamic> json) {
    return RequestCreationStatus(
      state: json['state'] as String? ?? '',
      requestId: (json['request_id'] as num?)?.toInt(),
    );
  }
}
