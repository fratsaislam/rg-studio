import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

// ── Models ────────────────────────────────────────────────────────
class Client {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? company;
  final String? address;
  final String? notes;
  final int ordersCount;

  const Client({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.company,
    this.address,
    this.notes,
    this.ordersCount = 0,
  });

  factory Client.fromJson(Map<String, dynamic> j) => Client(
    id: j['id'],
    name: j['name'],
    email: j['email'],
    phone: j['phone'],
    company: j['company'],
    address: j['address'],
    notes: j['notes'],
    ordersCount: j['_count']?['orders'] ?? 0,
  );
}

// ── Repository ────────────────────────────────────────────────────
class ClientRepository {
  final Ref ref;
  ClientRepository(this.ref);

  Future<List<Client>> getAll({String? search}) async {
    final res = await ref.read(dioProvider).get('/clients', queryParameters: search != null ? {'search': search} : null);
    return (res.data['data'] as List).map((e) => Client.fromJson(e)).toList();
  }

  Future<Client> getById(int id) async {
    final res = await ref.read(dioProvider).get('/clients/$id');
    return Client.fromJson(res.data['data']);
  }

  Future<Client> create(Map<String, dynamic> data) async {
    final res = await ref.read(dioProvider).post('/clients', data: data);
    return Client.fromJson(res.data['data']);
  }

  Future<Client> update(int id, Map<String, dynamic> data) async {
    final res = await ref.read(dioProvider).put('/clients/$id', data: data);
    return Client.fromJson(res.data['data']);
  }

  Future<void> delete(int id) async {
    await ref.read(dioProvider).delete('/clients/$id');
  }
}

final clientRepositoryProvider = Provider((ref) => ClientRepository(ref));

// ── Providers ─────────────────────────────────────────────────────
final clientsProvider = FutureProvider.family<List<Client>, String?>((ref, search) async {
  return ref.read(clientRepositoryProvider).getAll(search: search);
});

final clientDetailProvider = FutureProvider.family<Client, int>((ref, id) async {
  return ref.read(clientRepositoryProvider).getById(id);
});
