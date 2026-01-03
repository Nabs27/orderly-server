import 'package:dio/dio.dart';
import '../../../../../core/api_client.dart';

class CancellationService {
  // Annuler des articles d'une note
  static Future<Map<String, dynamic>> cancelItems({
    required int orderId,
    required String noteId,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> cancellationDetails,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/pos/orders/$orderId/notes/$noteId/cancel-items',
        data: {
          'items': items,
          'cancellationDetails': cancellationDetails,
        },
      );
      
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('[CANCELLATION] Erreur annulation articles: $e');
      rethrow;
    }
  }
}

