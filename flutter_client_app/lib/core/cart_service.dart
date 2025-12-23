import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final int id;
  final String name;
  final double price;
  int quantity;
  CartItem({required this.id, required this.name, required this.price, required this.quantity});

  Map<String, dynamic> toJson() => { 'id': id, 'name': name, 'price': price, 'quantity': quantity };
  static CartItem fromJson(Map<String, dynamic> m) => CartItem(id: m['id'] as int, name: m['name'] as String, price: (m['price'] as num).toDouble(), quantity: (m['quantity'] as num).toInt());
}

class CartService {
  CartService._();
  static final CartService instance = CartService._();

  final ValueNotifier<List<CartItem>> items = ValueNotifier<List<CartItem>>([]);
  String notes = '';
  String tableCode = '';
  int? lastOrderId; // 🆕 ID officiel (si commande confirmée)
  String? lastOrderTempId; // 🆕 tempId pour commandes client en attente
  double? lastOrderTotal;
  String? lastOrderAt; // ISO string

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('cart');
    if (raw != null) {
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>().map(CartItem.fromJson).toList();
      items.value = list;
    }
    notes = sp.getString('cart_notes') ?? '';
    tableCode = sp.getString('table_code') ?? '';
    lastOrderId = sp.getInt('last_order_id');
    lastOrderTempId = sp.getString('last_order_temp_id'); // 🆕 Charger tempId si présent
    lastOrderTotal = sp.getDouble('last_order_total');
    lastOrderAt = sp.getString('last_order_at');
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    final raw = json.encode(items.value.map((e) => e.toJson()).toList());
    await sp.setString('cart', raw);
    await sp.setString('cart_notes', notes);
    await sp.setString('table_code', tableCode);
    if (lastOrderId != null) {
      await sp.setInt('last_order_id', lastOrderId!);
    } else {
      await sp.remove('last_order_id');
    }
    if (lastOrderTempId != null) {
      await sp.setString('last_order_temp_id', lastOrderTempId!);
    } else {
      await sp.remove('last_order_temp_id');
    }
    if (lastOrderTotal != null) {
      await sp.setDouble('last_order_total', lastOrderTotal!);
    } else {
      await sp.remove('last_order_total');
    }
    if (lastOrderAt != null) {
      await sp.setString('last_order_at', lastOrderAt!);
    } else {
      await sp.remove('last_order_at');
    }
  }

  Future<void> clear() async {
    items.value = [];
    notes = '';
    await save();
  }

  // 🆕 CORRECTION : Accepter id (int) ou tempId (String) pour les commandes client
  Future<void> recordLastOrder({
    int? id, // ID officiel (si commande confirmée)
    String? tempId, // tempId pour commandes client en attente
    required double total,
    required String createdAt,
  }) async {
    lastOrderId = id;
    lastOrderTempId = tempId;
    lastOrderTotal = total;
    lastOrderAt = createdAt;
    await save();
  }

  Future<void> addItem({required int id, required String name, required double price}) async {
    final list = List<CartItem>.from(items.value);
    final idx = list.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      list[idx].quantity += 1;
    } else {
      list.add(CartItem(id: id, name: name, price: price, quantity: 1));
    }
    items.value = list;
    await save();
  }

  Future<void> updateQty(int id, int delta) async {
    final list = List<CartItem>.from(items.value);
    final idx = list.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      list[idx].quantity += delta;
      if (list[idx].quantity <= 0) list.removeAt(idx);
      items.value = list;
      await save();
    }
  }

  Future<void> remove(int id) async {
    final list = List<CartItem>.from(items.value)..removeWhere((e) => e.id == id);
    items.value = list;
    await save();
  }

  double get total => items.value.fold(0.0, (s, e) => s + e.price * e.quantity);
}



