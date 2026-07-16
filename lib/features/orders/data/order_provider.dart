import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

// ── Models ────────────────────────────────────────────────────────
class Order {
  final int id;
  final int clientId;
  final String eventType;
  final DateTime eventDate;
  final String location;
  final String package;
  final double totalAmount;
  final double deposit;
  final String status;
  final DateTime deliveryDate;
  final String? notes;
  final Map<String, dynamic>? client;

  const Order({
    required this.id,
    required this.clientId,
    required this.eventType,
    required this.eventDate,
    required this.location,
    required this.package,
    required this.totalAmount,
    required this.deposit,
    required this.status,
    required this.deliveryDate,
    this.notes,
    this.client,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        clientId: j['clientId'],
        eventType: j['eventType'],
        eventDate: DateTime.parse(j['eventDate']),
        location: j['location'],
        package: j['package'],
        totalAmount: (j['totalAmount'] as num).toDouble(),
        deposit: (j['deposit'] as num?)?.toDouble() ?? 0,
        status: j['status'],
        deliveryDate: DateTime.parse(j['deliveryDate']),
        notes: j['notes'],
        client: j['client'],
      );

  double get remaining => totalAmount - deposit;
}

// ── Repository ────────────────────────────────────────────────────
class OrderRepository {
  final Ref ref;
  OrderRepository(this.ref);

  Future<List<Order>> getAll({String? status}) async {
    final res = await ref.read(dioProvider).get('/orders',
        queryParameters: status != null ? {'status': status} : null);
    return (res.data['data'] as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<Order> getById(int id) async {
    final res = await ref.read(dioProvider).get('/orders/$id');
    return Order.fromJson(res.data['data']);
  }

  Future<Order> create(Map<String, dynamic> data) async {
    final res = await ref.read(dioProvider).post('/orders', data: data);
    return Order.fromJson(res.data['data']);
  }

  Future<Order> update(int id, Map<String, dynamic> data) async {
    final res = await ref.read(dioProvider).put('/orders/$id', data: data);
    return Order.fromJson(res.data['data']);
  }

  Future<void> delete(int id) async {
    await ref.read(dioProvider).delete('/orders/$id');
  }
}

final orderRepositoryProvider = Provider((ref) => OrderRepository(ref));

final ordersProvider =
    FutureProvider.family<List<Order>, String?>((ref, status) async {
  return ref.read(orderRepositoryProvider).getAll(status: status);
});
