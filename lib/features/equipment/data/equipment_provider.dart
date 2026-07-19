import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/dio_client.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class Equipment {
  final int id;
  final String identifier;
  final String name;
  final String category;
  final String? brand;
  final String? model;
  final String status;
  final String? notes;

  const Equipment({
    required this.id,
    required this.identifier,
    required this.name,
    required this.category,
    this.brand,
    this.model,
    required this.status,
    this.notes,
  });

  factory Equipment.fromJson(Map<String, dynamic> j) => Equipment(
        id: j['id'],
        identifier: j['identifier'],
        name: j['name'],
        category: j['category'],
        brand: j['brand'],
        model: j['model'],
        status: j['status'],
        notes: j['notes'],
      );
}

class Incident {
  final int id;
  final int equipmentId;
  final String description;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic>? equipment;
  final Map<String, dynamic>? reporter;
  final String? photoUrl;
  final String? resolution;

  const Incident({
    required this.id,
    required this.equipmentId,
    required this.description,
    required this.status,
    required this.createdAt,
    this.equipment,
    this.reporter,
    this.photoUrl,
    this.resolution,
  });

  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
        id: j['id'],
        equipmentId: j['equipmentId'],
        description: j['description'],
        status: j['status'],
        createdAt: DateTime.parse(j['createdAt']),
        equipment: j['equipment'],
        reporter: j['reporter'],
        photoUrl: j['photoUrl'],
        resolution: j['resolution'],
      );
}

class EquipmentMovement {
  final int id;
  final int equipmentId;
  final String type;
  final String? fromStatus;
  final String? toStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime? expectedReturnDate;
  final DateTime? returnedAt;
  final Map<String, dynamic>? equipment;
  final Map<String, dynamic>? actor;
  final Map<String, dynamic>? order;

  const EquipmentMovement({
    required this.id,
    required this.equipmentId,
    required this.type,
    this.fromStatus,
    this.toStatus,
    this.notes,
    required this.createdAt,
    this.expectedReturnDate,
    this.returnedAt,
    this.equipment,
    this.actor,
    this.order,
  });

  factory EquipmentMovement.fromJson(Map<String, dynamic> j) => EquipmentMovement(
        id: j['id'],
        equipmentId: j['equipmentId'],
        type: j['type'],
        fromStatus: j['fromStatus'],
        toStatus: j['toStatus'],
        notes: j['notes'],
        createdAt: DateTime.parse(j['createdAt']),
        expectedReturnDate: j['expectedReturnDate'] != null
            ? DateTime.parse(j['expectedReturnDate'])
            : null,
        returnedAt: j['returnedAt'] != null ? DateTime.parse(j['returnedAt']) : null,
        equipment: j['equipment'],
        actor: j['actor'],
        order: j['order'],
      );

  bool get isOverdue =>
      expectedReturnDate != null &&
      returnedAt == null &&
      DateTime.now().isAfter(expectedReturnDate!);
}

// ─── Repository ───────────────────────────────────────────────────────────────

class EquipmentRepository {
  final Ref ref;
  EquipmentRepository(this.ref);

  Future<List<Equipment>> getAll({String? category, String? status}) async {
    final res = await ref.read(dioProvider).get('/equipment', queryParameters: {
      if (category != null) 'category': category,
      if (status != null) 'status': status,
    });
    return (res.data['data'] as List)
        .map((e) => Equipment.fromJson(e))
        .toList();
  }

  Future<List<Equipment>> getAvailable() async {
    final res = await ref.read(dioProvider).get('/equipment/available');
    return (res.data['data'] as List)
        .map((e) => Equipment.fromJson(e))
        .toList();
  }

  Future<Equipment> create(Map<String, dynamic> data) async {
    final res = await ref.read(dioProvider).post('/equipment', data: data);
    return Equipment.fromJson(res.data['data']);
  }

  Future<Equipment> update(int id, Map<String, dynamic> data) async {
    final res = await ref.read(dioProvider).put('/equipment/$id', data: data);
    return Equipment.fromJson(res.data['data']);
  }

  // ── Check-Out / Check-In ──────────────────────────────────────────────────

  Future<void> checkOut({
    required int equipmentId,
    int? orderId,
    String? notes,
    DateTime? expectedReturnDate,
  }) async {
    await ref.read(dioProvider).post('/equipment/checkout', data: {
      'equipmentId': equipmentId,
      if (orderId != null) 'orderId': orderId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (expectedReturnDate != null)
        'expectedReturnDate': expectedReturnDate.toUtc().toIso8601String(),
    });
  }

  Future<void> checkIn({required int movementId, String? notes}) async {
    await ref.read(dioProvider).post('/equipment/checkin', data: {
      'movementId': movementId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  // ── Movements ─────────────────────────────────────────────────────────────

  Future<List<EquipmentMovement>> getCurrentlyOut() async {
    final res = await ref.read(dioProvider).get('/equipment/currently-out');
    return (res.data['data'] as List)
        .map((e) => EquipmentMovement.fromJson(e))
        .toList();
  }

  Future<List<EquipmentMovement>> getMovements({int? equipmentId}) async {
    final res = await ref.read(dioProvider).get(
      '/equipment/movements/all',
      queryParameters: {if (equipmentId != null) 'equipmentId': equipmentId},
    );
    return (res.data['data'] as List)
        .map((e) => EquipmentMovement.fromJson(e))
        .toList();
  }

  // ── Incidents ─────────────────────────────────────────────────────────────

  Future<List<Incident>> getAllIncidents() async {
    final res = await ref.read(dioProvider).get('/equipment/incidents/all');
    return (res.data['data'] as List).map((e) => Incident.fromJson(e)).toList();
  }

  Future<Incident> createIncident(Map<String, dynamic> data) async {
    final res =
        await ref.read(dioProvider).post('/equipment/incidents', data: data);
    return Incident.fromJson(res.data['data']);
  }

  Future<void> uploadIncidentPhoto(int incidentId, String path) async {
    final data = FormData.fromMap({
      'photo': await MultipartFile.fromFile(path),
    });
    await ref.read(dioProvider).post(
          '/equipment/incidents/$incidentId/photo',
          data: data,
          options: Options(contentType: 'multipart/form-data'),
        );
  }

  Future<void> updateIncident(int id, Map<String, dynamic> data) async {
    await ref.read(dioProvider).put('/equipment/incidents/$id', data: data);
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final equipmentRepositoryProvider =
    Provider((ref) => EquipmentRepository(ref));

final equipmentListProvider = FutureProvider<List<Equipment>>((ref) async {
  return ref.read(equipmentRepositoryProvider).getAll();
});

final availableEquipmentProvider = FutureProvider<List<Equipment>>((ref) async {
  return ref.read(equipmentRepositoryProvider).getAvailable();
});

final currentlyOutProvider =
    FutureProvider<List<EquipmentMovement>>((ref) async {
  return ref.read(equipmentRepositoryProvider).getCurrentlyOut();
});

final movementsProvider = FutureProvider<List<EquipmentMovement>>((ref) async {
  return ref.read(equipmentRepositoryProvider).getMovements();
});

final incidentsProvider = FutureProvider<List<Incident>>((ref) async {
  return ref.read(equipmentRepositoryProvider).getAllIncidents();
});
