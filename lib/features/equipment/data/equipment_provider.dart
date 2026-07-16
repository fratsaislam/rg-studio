import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

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

  const Incident({
    required this.id,
    required this.equipmentId,
    required this.description,
    required this.status,
    required this.createdAt,
    this.equipment,
    this.reporter,
  });

  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
    id: j['id'],
    equipmentId: j['equipmentId'],
    description: j['description'],
    status: j['status'],
    createdAt: DateTime.parse(j['createdAt']),
    equipment: j['equipment'],
    reporter: j['reporter'],
  );
}

class EquipmentRepository {
  final Ref ref;
  EquipmentRepository(this.ref);

  Future<List<Equipment>> getAll({String? category, String? status}) async {
    final res = await ref.read(dioProvider).get('/equipment', queryParameters: {
      if (category != null) 'category': category,
      if (status != null) 'status': status,
    });
    return (res.data['data'] as List).map((e) => Equipment.fromJson(e)).toList();
  }

  Future<Equipment> create(Map<String, dynamic> data) async {
    final res = await ref.read(dioProvider).post('/equipment', data: data);
    return Equipment.fromJson(res.data['data']);
  }

  Future<Equipment> update(int id, Map<String, dynamic> data) async {
    final res = await ref.read(dioProvider).put('/equipment/$id', data: data);
    return Equipment.fromJson(res.data['data']);
  }

  Future<List<Incident>> getAllIncidents() async {
    final res = await ref.read(dioProvider).get('/equipment/incidents/all');
    return (res.data['data'] as List).map((e) => Incident.fromJson(e)).toList();
  }

  Future<void> reportIncident(Map<String, dynamic> data) async {
    await ref.read(dioProvider).post('/equipment/incidents', data: data);
  }
}

final equipmentRepositoryProvider = Provider((ref) => EquipmentRepository(ref));

final equipmentListProvider = FutureProvider<List<Equipment>>((ref) async {
  return ref.read(equipmentRepositoryProvider).getAll();
});

final incidentsProvider = FutureProvider<List<Incident>>((ref) async {
  return ref.read(equipmentRepositoryProvider).getAllIncidents();
});
