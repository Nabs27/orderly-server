class CreditReport {
  final CreditSummary summary;
  final List<CreditTransaction> transactions;

  CreditReport({required this.summary, required this.transactions});

  factory CreditReport.fromJson(Map<String, dynamic> json) {
    final summary = CreditSummary.fromJson(
      (json['summary'] as Map<String, dynamic>?) ?? const {},
    );

    final transactionsJson = (json['transactions'] as List?) ?? const [];
    final transactions = transactionsJson
        .map((tx) => CreditTransaction.fromJson((tx as Map).cast<String, dynamic>()))
        .toList();

    return CreditReport(summary: summary, transactions: transactions);
  }
}

class CreditSummary {
  final double totalDebit;
  final double totalCredit;
  final double totalBalance;
  final int transactionsCount;
  final List<CreditClient> clients;

  const CreditSummary({
    required this.totalDebit,
    required this.totalCredit,
    required this.totalBalance,
    required this.transactionsCount,
    required this.clients,
  });

  factory CreditSummary.fromJson(Map<String, dynamic> json) {
    final clientsJson = (json['clients'] as List?) ?? const [];
    final clients = clientsJson
        .map((client) => CreditClient.fromJson((client as Map).cast<String, dynamic>()))
        .toList();

    return CreditSummary(
      totalDebit: (json['totalDebit'] as num?)?.toDouble() ?? 0,
      totalCredit: (json['totalCredit'] as num?)?.toDouble() ?? 0,
      totalBalance: (json['totalBalance'] as num?)?.toDouble() ??
          (json['totalAmount'] as num?)?.toDouble() ??
          0,
      transactionsCount: (json['transactionsCount'] as num?)?.toInt() ?? 0,
      clients: clients,
    );
  }
}

class CreditClient {
  final String? clientId;
  final String clientName;
  final double debitTotal;
  final double creditTotal;
  final double balance;
  final int transactionsCount;
  final String? lastTransaction;

  const CreditClient({
    required this.clientId,
    required this.clientName,
    required this.debitTotal,
    required this.creditTotal,
    required this.balance,
    required this.transactionsCount,
    required this.lastTransaction,
  });

  factory CreditClient.fromJson(Map<String, dynamic> json) {
    return CreditClient(
      clientId: (json['clientId'] ?? json['id'])?.toString(),
      clientName: (json['clientName'] as String?) ?? 'N/A',
      debitTotal: (json['debitTotal'] as num?)?.toDouble() ?? 0,
      creditTotal: (json['creditTotal'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      transactionsCount: (json['transactionsCount'] as num?)?.toInt() ?? 0,
      lastTransaction: json['lastTransaction'] as String?,
    );
  }
}

class CreditTransaction {
  final String? clientId;
  final String clientName;
  final String type; // DEBIT ou CREDIT
  final double amount;
  final String paymentMode;
  final String description;
  final DateTime? date;

  CreditTransaction({
    required this.clientId,
    required this.clientName,
    required this.type,
    required this.amount,
    required this.paymentMode,
    required this.description,
    required this.date,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      clientId: (json['clientId'] ?? json['id'])?.toString(),
      clientName: (json['clientName'] as String?) ?? 'N/A',
      type: (json['type'] as String? ?? 'DEBIT').toUpperCase(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentMode: (json['paymentMode'] as String?) ?? 'CREDIT',
      description: (json['description'] as String?) ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? ''),
    );
  }
}

