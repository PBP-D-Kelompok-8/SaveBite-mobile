import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/models/request_offer.dart';

/// ID pengguna dummy yang sedang login untuk pengujian UI lokal sebelum
/// integrasi sesi API pada Tahap 4.
const int dummyCurrentUserId = 1;

const RequestOwner _dummyCurrentUser = RequestOwner(
  id: dummyCurrentUserId,
  displayName: 'Dapur Komunitas Menteng',
);

const RequestOwner _dummyPartnerA = RequestOwner(
  id: 2,
  displayName: 'Warung Berkah Tebet',
);

const RequestOwner _dummyPartnerB = RequestOwner(
  id: 3,
  displayName: 'Panti Asuhan Harapan',
);

const RequestOwner _dummyPartnerC = RequestOwner(
  id: 4,
  displayName: 'Komunitas Pangan Depok',
);

/// Daftar dummy [FoodRequest] yang selaras dengan kontrak REST API `SaveBite`.
///
/// Mencakup variasi `status` tersimpan (`pending`, `offered`, `fulfilled`),
/// kasus kedaluwarsa (`status: "offered"`/`"pending"` dengan
/// `effectiveStatus: "expired"`), serta perbedaan hak akses `selectedOfferId`
/// antara milik sendiri dan milik pengguna lain (`null` bagi non-owner).
final List<FoodRequest> dummyFoodRequests = [
  FoodRequest(
    id: 1,
    owner: _dummyCurrentUser,
    title: 'Butuh Beras Putih untuk Dapur Umum',
    foodItem: 'Beras Putih Medium',
    quantity: '15.00',
    unit: 'kg',
    description:
        'Untuk kebutuhan masak makan siang 60 porsi di posko Menteng.',
    location: 'Menteng, Jakarta Pusat',
    status: 'pending',
    effectiveStatus: 'pending',
    expiresAt: DateTime.utc(2026, 11, 25, 10, 0),
    offerCount: 0,
    hasOffered: false,
    selectedOfferId: null,
    createdAt: DateTime.utc(2026, 11, 23, 2, 0),
    updatedAt: DateTime.utc(2026, 11, 23, 2, 0),
  ),
  FoodRequest(
    id: 2,
    owner: _dummyCurrentUser,
    title: 'Telur Ayam Segar untuk Sarapan Anak',
    foodItem: 'Telur Ayam Negeri',
    quantity: '50.00',
    unit: 'butir',
    description:
        'Dibutuhkan untuk menu sarapan bergizi akhir pekan ini.',
    location: 'Cikini, Jakarta Pusat',
    status: 'offered',
    effectiveStatus: 'offered',
    expiresAt: DateTime.utc(2026, 11, 24, 18, 0),
    offerCount: 3,
    hasOffered: false,
    selectedOfferId: 101,
    createdAt: DateTime.utc(2026, 11, 22, 9, 30),
    updatedAt: DateTime.utc(2026, 11, 22, 14, 15),
  ),
  FoodRequest(
    id: 3,
    owner: _dummyPartnerA,
    title: 'Minyak Goreng Kemasan 2 Liter',
    foodItem: 'Minyak Goreng Sawit',
    quantity: '6.00',
    unit: 'liter',
    description:
        'Persediaan minyak goreng menipis untuk dapur berbagi sore hari.',
    location: 'Tebet, Jakarta Selatan',
    status: 'offered',
    effectiveStatus: 'offered',
    expiresAt: DateTime.utc(2026, 11, 25, 15, 0),
    offerCount: 2,
    hasOffered: false,
    // Non-owner selalu menerima selected_offer_id: null dari backend.
    selectedOfferId: null,
    createdAt: DateTime.utc(2026, 11, 22, 7, 0),
    updatedAt: DateTime.utc(2026, 11, 22, 12, 0),
  ),
  FoodRequest(
    id: 4,
    owner: _dummyPartnerB,
    title: 'Sayur Bayam & Kangkung Segar',
    foodItem: 'Sayuran Hijau',
    quantity: '12.00',
    unit: 'ikat',
    description:
        'Untuk tambahan sayur makan malam anak-anak panti asuhan.',
    location: 'Pasar Minggu, Jakarta Selatan',
    status: 'pending',
    effectiveStatus: 'pending',
    expiresAt: null,
    offerCount: 0,
    hasOffered: false,
    selectedOfferId: null,
    createdAt: DateTime.utc(2026, 11, 21, 16, 45),
    updatedAt: DateTime.utc(2026, 11, 21, 16, 45),
  ),
  FoodRequest(
    id: 5,
    owner: _dummyCurrentUser,
    title: 'Nasi Kotak Siap Santap untuk Relawan',
    foodItem: 'Nasi Kotak Ayam Bakar',
    quantity: '30.00',
    unit: 'porsi',
    description: 'Sudah diterima lengkap oleh koordinator lapangan.',
    location: 'Salemba, Jakarta Pusat',
    status: 'fulfilled',
    effectiveStatus: 'fulfilled',
    expiresAt: DateTime.utc(2026, 11, 21, 12, 0),
    offerCount: 2,
    hasOffered: false,
    selectedOfferId: 201,
    createdAt: DateTime.utc(2026, 11, 20, 8, 0),
    updatedAt: DateTime.utc(2026, 11, 21, 10, 30),
  ),
  FoodRequest(
    id: 6,
    owner: _dummyPartnerC,
    title: 'Susu UHT Kemasan untuk Balita',
    foodItem: 'Susu UHT Full Cream',
    quantity: '4500.00',
    unit: 'ml',
    description:
        'Permintaan melewati batas waktu sebelum sempat ditandai terpenuhi.',
    location: 'Beji, Depok',
    // Kasus kontrak: status tersimpan tetap "offered", namun effectiveStatus "expired".
    status: 'offered',
    effectiveStatus: 'expired',
    expiresAt: DateTime.utc(2026, 11, 19, 17, 0),
    offerCount: 1,
    hasOffered: true,
    selectedOfferId: null,
    createdAt: DateTime.utc(2026, 11, 18, 10, 0),
    updatedAt: DateTime.utc(2026, 11, 18, 15, 20),
  ),
  FoodRequest(
    id: 7,
    owner: _dummyCurrentUser,
    title: 'Roti Tawar Gandum untuk Snack Pagi',
    foodItem: 'Roti Tawar',
    quantity: '10.00',
    unit: 'buah',
    description: 'Belum ada penawaran hingga tenggat berakhir.',
    location: 'Kramat, Jakarta Pusat',
    status: 'pending',
    effectiveStatus: 'expired',
    expiresAt: DateTime.utc(2026, 11, 18, 9, 0),
    offerCount: 0,
    hasOffered: false,
    selectedOfferId: null,
    createdAt: DateTime.utc(2026, 11, 17, 9, 0),
    updatedAt: DateTime.utc(2026, 11, 17, 9, 0),
  ),
];

/// Daftar dummy [RequestOffer] untuk menguji tampilan daftar penawar,
/// pemilihan penawar, dan pergantian penawar terpilih.
final List<RequestOffer> dummyRequestOffers = [
  RequestOffer(
    id: 101,
    requestId: 2,
    offeredBy: _dummyPartnerA,
    createdAt: DateTime.utc(2026, 11, 22, 10, 5),
    isSelected: true,
  ),
  RequestOffer(
    id: 102,
    requestId: 2,
    offeredBy: _dummyPartnerB,
    createdAt: DateTime.utc(2026, 11, 22, 11, 20),
    isSelected: false,
  ),
  RequestOffer(
    id: 103,
    requestId: 2,
    offeredBy: _dummyPartnerC,
    createdAt: DateTime.utc(2026, 11, 22, 13, 45),
    isSelected: false,
  ),
  RequestOffer(
    id: 201,
    requestId: 5,
    offeredBy: _dummyPartnerA,
    createdAt: DateTime.utc(2026, 11, 20, 9, 15),
    isSelected: true,
  ),
  RequestOffer(
    id: 202,
    requestId: 5,
    offeredBy: _dummyPartnerC,
    createdAt: DateTime.utc(2026, 11, 20, 11, 0),
    isSelected: false,
  ),
];

/// Mengembalikan daftar penawaran dummy untuk [requestId] tertentu.
List<RequestOffer> getDummyOffersForRequest(int requestId) {
  return dummyRequestOffers
      .where((offer) => offer.requestId == requestId)
      .toList();
}
