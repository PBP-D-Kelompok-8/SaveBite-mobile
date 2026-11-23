import 'package:flutter_test/flutter_test.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/models/paginated_response.dart';
import 'package:savebite_mobile/request_board/models/request_creation_status.dart';
import 'package:savebite_mobile/request_board/models/request_offer.dart';

void main() {
  group('FoodRequest', () {
    test('parses complete JSON and supports cache round-trip', () {
      final json = <String, dynamic>{
        'id': 10,
        'owner': {'id': 3, 'display_name': 'Budi Santoso'},
        'title': 'Butuh Beras untuk Dapur Umum',
        'food_item': 'Beras Putih',
        'quantity': '5.50',
        'unit': 'kg',
        'description': 'Untuk masak 30 porsi makan siang',
        'location': 'Depok',
        'status': 'offered',
        'effective_status': 'offered',
        'expires_at': '2026-12-01T10:00:00Z',
        'offer_count': 2,
        'has_offered': true,
        'selected_offer_id': 77,
        'created_at': '2026-11-20T08:00:00Z',
        'updated_at': '2026-11-21T09:30:00Z',
      };

      final request = FoodRequest.fromJson(json);

      expect(request.id, 10);
      expect(request.owner.id, 3);
      expect(request.owner.displayName, 'Budi Santoso');
      expect(request.title, 'Butuh Beras untuk Dapur Umum');
      expect(request.foodItem, 'Beras Putih');
      expect(request.quantity, '5.50');
      expect(request.unit, 'kg');
      expect(request.description, 'Untuk masak 30 porsi makan siang');
      expect(request.location, 'Depok');
      expect(request.status, 'offered');
      expect(request.effectiveStatus, 'offered');
      expect(request.expiresAt, DateTime.utc(2026, 12, 1, 10, 0, 0));
      expect(request.offerCount, 2);
      expect(request.hasOffered, isTrue);
      expect(request.selectedOfferId, 77);
      expect(request.createdAt, DateTime.utc(2026, 11, 20, 8, 0, 0));
      expect(request.updatedAt, DateTime.utc(2026, 11, 21, 9, 30, 0));
      expect(request.isActive, isTrue);

      final cached = FoodRequest.fromJson(request.toCacheJson());
      expect(cached.id, request.id);
      expect(cached.owner.displayName, request.owner.displayName);
      expect(cached.selectedOfferId, 77);
      expect(cached.expiresAt, request.expiresAt);
    });

    test('handles null expires_at and null selected_offer_id for non-owner', () {
      final json = <String, dynamic>{
        'id': 11,
        'owner': {'id': 4, 'display_name': 'Siti'},
        'title': 'Butuh Sayur Segar',
        'food_item': 'Bayam',
        'quantity': '2.00',
        'unit': 'ikat',
        'description': '',
        'location': '',
        'status': 'pending',
        'effective_status': 'pending',
        'expires_at': null,
        'offer_count': 0,
        'has_offered': false,
        'selected_offer_id': null,
        'created_at': '2026-11-20T08:00:00Z',
        'updated_at': '2026-11-20T08:00:00Z',
      };

      final request = FoodRequest.fromJson(json);

      expect(request.expiresAt, isNull);
      expect(request.selectedOfferId, isNull);
      expect(request.hasOffered, isFalse);
      expect(request.isActive, isTrue);
    });

    test('marks offered request with effective_status expired as inactive', () {
      final json = <String, dynamic>{
        'id': 12,
        'owner': {'id': 5, 'display_name': 'Andi'},
        'title': 'Butuh Roti Tawar',
        'food_item': 'Roti',
        'quantity': '1.00',
        'unit': 'porsi',
        'description': 'Tenggat lewat',
        'location': 'Jakarta',
        'status': 'offered',
        'effective_status': 'expired',
        'expires_at': '2026-11-19T12:00:00Z',
        'offer_count': 1,
        'has_offered': false,
        'selected_offer_id': null,
        'created_at': '2026-11-18T12:00:00Z',
        'updated_at': '2026-11-18T13:00:00Z',
      };

      final request = FoodRequest.fromJson(json);

      expect(request.status, 'offered');
      expect(request.effectiveStatus, 'expired');
      expect(request.isActive, isFalse);
    });
  });

  group('FoodRequestCreatePayload', () {
    test('omits expires_at and read-only fields when expiresAt is null', () {
      const payload = FoodRequestCreatePayload(
        title: 'Butuh Minyak Goreng',
        foodItem: 'Minyak Goreng',
        quantity: '2.50',
        unit: 'liter',
      );

      final json = payload.toJson();

      expect(json.containsKey('expires_at'), isFalse);
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('owner'), isFalse);
      expect(json.containsKey('status'), isFalse);
      expect(json.containsKey('effective_status'), isFalse);
      expect(json, <String, dynamic>{
        'title': 'Butuh Minyak Goreng',
        'food_item': 'Minyak Goreng',
        'quantity': '2.50',
        'unit': 'liter',
        'description': '',
        'location': '',
      });
    });

    test('includes UTC ISO-8601 expires_at when provided', () {
      final localDeadline = DateTime(2026, 12, 5, 15, 30);
      final payload = FoodRequestCreatePayload(
        title: 'Butuh Telur Ayam',
        foodItem: 'Telur',
        quantity: '12.00',
        unit: 'butir',
        description: 'Untuk sarapan panti',
        location: 'Bogor',
        expiresAt: localDeadline,
      );

      final json = payload.toJson();

      expect(json['expires_at'], localDeadline.toUtc().toIso8601String());
      expect(json['location'], 'Bogor');
      expect(json['description'], 'Untuk sarapan panti');
      expect(json.keys, hasLength(7));
    });
  });

  group('RequestOffer', () {
    test('parses RequestOffer from JSON', () {
      final json = <String, dynamic>{
        'id': 55,
        'request_id': 10,
        'offered_by': {'id': 9, 'display_name': 'Relawan A'},
        'created_at': '2026-11-21T07:15:00Z',
        'is_selected': true,
      };

      final offer = RequestOffer.fromJson(json);

      expect(offer.id, 55);
      expect(offer.requestId, 10);
      expect(offer.offeredBy.id, 9);
      expect(offer.offeredBy.displayName, 'Relawan A');
      expect(offer.createdAt, DateTime.utc(2026, 11, 21, 7, 15, 0));
      expect(offer.isSelected, isTrue);
    });
  });

  group('PaginatedResponse', () {
    test('parses paginated results and computes hasNextPage', () {
      final page1Json = <String, dynamic>{
        'count': 21,
        'page': 1,
        'page_size': 20,
        'total_pages': 2,
        'results': [
          {
            'id': 55,
            'request_id': 10,
            'offered_by': {'id': 9, 'display_name': 'Relawan A'},
            'created_at': '2026-11-21T07:15:00Z',
            'is_selected': false,
          },
        ],
      };

      final page1 = PaginatedResponse<RequestOffer>.fromJson(
        page1Json,
        RequestOffer.fromJson,
      );

      expect(page1.count, 21);
      expect(page1.page, 1);
      expect(page1.pageSize, 20);
      expect(page1.totalPages, 2);
      expect(page1.results, hasLength(1));
      expect(page1.results.first.id, 55);
      expect(page1.hasNextPage, isTrue);

      final page2 = PaginatedResponse<RequestOffer>.fromJson(
        {...page1Json, 'page': 2},
        RequestOffer.fromJson,
      );
      expect(page2.hasNextPage, isFalse);
    });
  });

  group('RequestCreationStatus', () {
    test('parses created and deleted states', () {
      final created = RequestCreationStatus.fromJson({
        'state': 'created',
        'request_id': 42,
      });
      expect(created.state, 'created');
      expect(created.requestId, 42);
      expect(created.isCreated, isTrue);
      expect(created.isDeleted, isFalse);

      final deleted = RequestCreationStatus.fromJson({
        'state': 'deleted',
        'request_id': null,
      });
      expect(deleted.state, 'deleted');
      expect(deleted.requestId, isNull);
      expect(deleted.isCreated, isFalse);
      expect(deleted.isDeleted, isTrue);
    });
  });

  group('Choices constants', () {
    test('exposes expected choices lists', () {
      expect(unitChoices, containsAll(['gram', 'kg', 'ml', 'liter', 'buah', 'butir', 'ikat', 'porsi']));
      expect(sortChoices, ['newest', 'oldest']);
      expect(storedStatusChoices, ['pending', 'offered', 'fulfilled']);
      expect(filterStatusChoices, ['pending', 'offered', 'fulfilled', 'expired']);
    });
  });
}
