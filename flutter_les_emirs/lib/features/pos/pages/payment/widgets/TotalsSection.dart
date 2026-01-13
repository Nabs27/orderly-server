import 'package:flutter/material.dart';

class TotalsSection extends StatelessWidget {
  final double paymentTotal;
  final double finalTotal;
  final double discount;
  final bool isPercentDiscount;

  const TotalsSection({
    super.key,
    required this.paymentTotal,
    required this.finalTotal,
    required this.discount,
    required this.isPercentDiscount,
  });

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isTotal)
                Icon(
                  Icons.payments,
                  color: Colors.white,
                  size: 20,
                ),
              if (isTotal) const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: isTotal ? 20 : 16,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                  color: isTotal ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
          Container(
            padding: isTotal
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                : EdgeInsets.zero,
            decoration: isTotal
                ? BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  )
                : null,
            child: Text(
              isDiscount ? '-${_formatCurrency(amount.abs())}' : _formatCurrency(amount),
              style: TextStyle(
                fontSize: isTotal ? 24 : 16,
                fontWeight: FontWeight.bold,
                color: isTotal
                    ? Colors.white
                    : isDiscount
                        ? Colors.orange.shade200
                        : Colors.white70,
                letterSpacing: isTotal ? 0.5 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]} ',
    ) + ' TND';
  }

  Color _getAmountColor(double amount) {
    if (amount < 50) return Colors.green.shade300;
    if (amount < 200) return Colors.orange.shade300;
    return Colors.red.shade300;
  }

  @override
  Widget build(BuildContext context) {
    final discountAmount = discount > 0
        ? (isPercentDiscount ? (paymentTotal * discount / 100) : discount)
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF27AE60),
            const Color(0xFF229954),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 2)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🆕 Afficher le sous-total uniquement s'il est différent du total final (remise appliquée)
          if ((paymentTotal - finalTotal).abs() > 0.01) ...[
            _buildTotalRow('Sous-total', paymentTotal),
            if (discount > 0) ...[
              const SizedBox(height: 4),
              _buildTotalRow(
                isPercentDiscount
                    ? 'Remise (${discount.toStringAsFixed(0)}%)'
                    : 'Remise',
                -discountAmount,
                isDiscount: true,
              ),
            ],
            const Divider(color: Colors.white70, height: 16),
          ],
          _buildTotalRow('TOTAL À PAYER', finalTotal, isTotal: true),
        ],
      ),
    );
  }
}

