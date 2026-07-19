import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

class Supplier {
  final int id;
  final String name;
  final String category;
  final String? contact;
  final String? email;
  final String? phone;
  final String? zones;
  final String status;
  final int? qualityRating;
  final int subcontractsCount;

  const Supplier({
    required this.id,
    required this.name,
    required this.category,
    this.contact,
    this.email,
    this.phone,
    this.zones,
    required this.status,
    this.qualityRating,
    this.subcontractsCount = 0,
  });

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
    id: j['id'],
    name: j['name'],
    category: j['category'],
    contact: j['contact'],
    email: j['email'],
    phone: j['phone'],
    zones: j['zones'],
    status: j['status'] ?? 'ACTIVE',
    qualityRating: j['qualityRating'],
    subcontractsCount: j['_count']?['subcontracts'] ?? 0,
  );
}

class Subcontract {
  final int id;
  final double cost;
  final double? actualCost;
  final String status;
  final DateTime? deadline;
  final int? qualityRating;
  final Map<String, dynamic>? supplier;
  final Map<String, dynamic>? order;

  const Subcontract({
    required this.id,
    required this.cost,
    this.actualCost,
    required this.status,
    this.deadline,
    this.qualityRating,
    this.supplier,
    this.order,
  });

  factory Subcontract.fromJson(Map<String, dynamic> j) => Subcontract(
    id: j['id'],
    cost: (j['cost'] as num).toDouble(),
    actualCost: j['actualCost'] == null ? null : (j['actualCost'] as num).toDouble(),
    status: j['status'],
    deadline: j['deadline'] == null ? null : DateTime.parse(j['deadline']),
    qualityRating: j['qualityRating'],
    supplier: j['supplier'],
    order: j['order'],
  );
}

class SupplierRepository {
  final Ref ref;
  SupplierRepository(this.ref);

  Future<List<Supplier>> getAll() async {
    final res = await ref.read(dioProvider).get('/suppliers');
    return (res.data['data'] as List).map((e) => Supplier.fromJson(e)).toList();
  }

  Future<List<Subcontract>> getSubcontracts() async {
    final res = await ref.read(dioProvider).get('/subcontracts');
    return (res.data['data'] as List).map((e) => Subcontract.fromJson(e)).toList();
  }
}

final supplierRepositoryProvider = Provider((ref) => SupplierRepository(ref));

final suppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  return ref.read(supplierRepositoryProvider).getAll();
});

final subcontractsProvider = FutureProvider<List<Subcontract>>((ref) async {
  return ref.read(supplierRepositoryProvider).getSubcontracts();
});
