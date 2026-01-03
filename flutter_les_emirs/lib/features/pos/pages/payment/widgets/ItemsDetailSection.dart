import 'package:flutter/material.dart';

class ItemsDetailSection extends StatelessWidget {
  final List<Map<String, dynamic>> itemsToShow;
  final String selectedNoteForPayment;

  const ItemsDetailSection({
    super.key,
    required this.itemsToShow,
    required this.selectedNoteForPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2C3E50),
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  'Article',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Qté',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'Prix',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  'Total',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: itemsToShow.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun article sélectionné',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  itemCount: itemsToShow.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = itemsToShow[i];
                    final name = item['name'] as String;
                    final price = (item['price'] as num).toDouble();
                    final quantity = (item['quantity'] as num).toInt();
                    final subtotal = price * quantity;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: selectedNoteForPayment == 'partial'
                          ? const Color(0xFFE8F4F8)
                          : (i % 2 == 0 ? Colors.white : Colors.grey.shade50),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              '$quantity',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${price.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              '${subtotal.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

