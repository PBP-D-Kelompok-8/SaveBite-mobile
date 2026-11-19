class FoodRescuePlan {
  final int id;
  final String namaBahan;
  final int jumlah;
  final String satuan;
  final DateTime targetDate;
  final String metodeAksi;
  final String status;
  final String notes;
  final DateTime? createdAt;
  final DateTime? completedAt;

  FoodRescuePlan({
    required this.id,
    required this.namaBahan,
    required this.jumlah,
    required this.satuan,
    required this.targetDate,
    required this.metodeAksi,
    required this.status,
    this.notes = '',
    this.createdAt,
    this.completedAt,
  });

  factory FoodRescuePlan.fromJson(Map<String, dynamic> json) {
    return FoodRescuePlan(
      id: json['id'],
      namaBahan: json['nama_bahan'],
      jumlah: json['jumlah'],
      satuan: json['satuan'],
      targetDate: DateTime.parse(json['target_date']),
      metodeAksi: json['metode_aksi'],
      status: json['status'],
      notes: json['notes'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama_bahan': namaBahan,
      'jumlah': jumlah,
      'satuan': satuan,
      'target_date':
          '${targetDate.year.toString().padLeft(4, '0')}-'
          '${targetDate.month.toString().padLeft(2, '0')}-'
          '${targetDate.day.toString().padLeft(2, '0')}',
      'metode_aksi': metodeAksi,
      'status': status,
      'notes': notes,
    };
  }
}