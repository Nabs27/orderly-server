import 'package:flutter/material.dart';
import '../services/history_service.dart';
import 'HistoryTableCard.dart';
import 'TableHistoryDialog.dart';

/// Vue historique des tables archivées d'un serveur
class HistoryView extends StatefulWidget {
  final String serverName;
  final Map<String, Map<String, dynamic>> processedTables; // 🆕 Tables avec données pré-traitées
  final bool loading;

  const HistoryView({
    super.key,
    required this.serverName,
    required this.processedTables,
    required this.loading,
  });

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  // 🆕 Filtre par date : par défaut = aujourd'hui
  DateTime _selectedDate = DateTime.now();
  
  // 🆕 Fonction pour vérifier si une table appartient à la date sélectionnée
  bool _isTableInSelectedDate(String tableNumber, Map<String, dynamic> tableData) {
    final sessions = List<Map<String, dynamic>>.from(
      (tableData['sessions'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []
    );
    
    if (sessions.isEmpty) return false;
    
    // 🆕 Vérifier TOUTES les sessions pour voir si au moins une appartient à la date sélectionnée
    // (pas seulement la plus récente, car une table peut avoir plusieurs sessions sur différentes dates)
    for (final session in sessions) {
      final archivedAtStr = session['archivedAt'] ?? session['createdAt'];
      if (archivedAtStr == null) continue;
      
      try {
        final archivedAt = DateTime.parse(archivedAtStr);
        // Comparer seulement la date (sans l'heure)
        final sessionDate = DateTime(archivedAt.year, archivedAt.month, archivedAt.day);
        final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        
        if (sessionDate == selectedDate) {
          return true; // Au moins une session correspond à la date sélectionnée
        }
      } catch (e) {
        continue; // Ignorer les sessions avec des dates invalides
      }
    }
    
    return false; // Aucune session ne correspond à la date sélectionnée
  }
  
  // 🆕 Fonction pour obtenir la date de la session la plus récente d'une table
  DateTime? _getLatestSessionDate(String tableNumber, Map<String, dynamic> tableData) {
    final sessions = List<Map<String, dynamic>>.from(
      (tableData['sessions'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []
    );
    
    if (sessions.isEmpty) return null;
    
    final latestSession = sessions.first;
    final archivedAtStr = latestSession['archivedAt'] ?? latestSession['createdAt'];
    if (archivedAtStr == null) return null;
    
    try {
      return DateTime.parse(archivedAtStr);
    } catch (e) {
      return null;
    }
  }
  
  // 🆕 Fonction pour filtrer les services d'une table par date sélectionnée
  Map<String, dynamic> _filterServicesByDate(Map<String, dynamic> tableData) {
    final services = tableData['services'] as Map<String, dynamic>? ?? {};
    final filteredServices = <String, Map<String, dynamic>>{};
    
    // Filtrer les services pour ne garder que ceux de la date sélectionnée
    services.forEach((serviceKey, serviceData) {
      final serviceMap = Map<String, dynamic>.from(serviceData as Map);
      final sessions = serviceMap['sessions'] as List? ?? [];
      
      // Vérifier si au moins une session du service correspond à la date sélectionnée
      bool hasSessionInSelectedDate = false;
      for (final session in sessions) {
        final sessionMap = Map<String, dynamic>.from(session as Map);
        final archivedAtStr = sessionMap['archivedAt'] ?? sessionMap['createdAt'];
        if (archivedAtStr == null) continue;
        
        try {
          final archivedAt = DateTime.parse(archivedAtStr);
          final sessionDate = DateTime(archivedAt.year, archivedAt.month, archivedAt.day);
          final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
          
          if (sessionDate == selectedDateOnly) {
            hasSessionInSelectedDate = true;
            break;
          }
        } catch (e) {
          continue;
        }
      }
      
      if (hasSessionInSelectedDate) {
        // 🆕 Convertir explicitement en Map<String, dynamic>
        filteredServices[serviceKey.toString()] = Map<String, dynamic>.from(serviceData as Map);
      }
    });
    
    // Créer une copie de tableData avec seulement les services filtrés
    final filteredTableData = Map<String, dynamic>.from(tableData);
    filteredTableData['services'] = filteredServices;
    
    // Filtrer aussi les sessions pour ne garder que celles de la date sélectionnée
    final allSessions = List<Map<String, dynamic>>.from(
      (tableData['sessions'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []
    );
    
    final filteredSessions = <Map<String, dynamic>>[];
    for (final session in allSessions) {
      final archivedAtStr = session['archivedAt'] ?? session['createdAt'];
      if (archivedAtStr == null) continue;
      
      try {
        final archivedAt = DateTime.parse(archivedAtStr);
        final sessionDate = DateTime(archivedAt.year, archivedAt.month, archivedAt.day);
        final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        
        if (sessionDate == selectedDateOnly) {
          filteredSessions.add(session);
        }
      } catch (e) {
        continue;
      }
    }
    
    filteredTableData['sessions'] = filteredSessions;
    
    return filteredTableData;
  }
  
  // 🆕 Fonction pour sélectionner une date
  Future<void> _selectDate(BuildContext context) async {
    // 🆕 Utiliser le contexte directement comme les autres DatePicker dans le code
    // Ne pas spécifier locale car MaterialApp n'a pas de localizationsDelegates configuré
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 🆕 Filtrer les tables par date sélectionnée
    final filteredTables = <String, Map<String, dynamic>>{};
    widget.processedTables.forEach((tableNumber, tableData) {
      if (_isTableInSelectedDate(tableNumber, tableData)) {
        filteredTables[tableNumber] = tableData;
      }
    });

    if (filteredTables.isEmpty) {
      return Column(
        children: [
          // 🆕 Barre de filtre de date
          _buildDateFilterBar(context),
          Expanded(
            child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
                    'Aucun historique disponible pour cette date',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
                  const SizedBox(height: 8),
                  Text(
                    'Sélectionnez une autre date',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
          ],
        ),
            ),
          ),
        ],
      );
    }

    // 🆕 Trier les tables par date (plus récentes en premier), puis par numéro
    final sortedTables = filteredTables.keys.toList()
      ..sort((a, b) {
        final dateA = _getLatestSessionDate(a, filteredTables[a]!);
        final dateB = _getLatestSessionDate(b, filteredTables[b]!);
        
        if (dateA == null && dateB == null) {
          return (int.tryParse(a) ?? 999).compareTo(int.tryParse(b) ?? 999);
        }
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        
        // Comparer d'abord par date (plus récent en premier)
        final dateComparison = dateB.compareTo(dateA);
        if (dateComparison != 0) return dateComparison;
        
        // Si même date, trier par numéro de table
        return (int.tryParse(a) ?? 999).compareTo(int.tryParse(b) ?? 999);
      });

    return Column(
      children: [
        // 🆕 Barre de filtre de date
        _buildDateFilterBar(context),
        // 🆕 Compteur de tables
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.table_restaurant, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                '${sortedTables.length} ${sortedTables.length > 1 ? 'tables' : 'table'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        // Grille des tables
        Expanded(
          child: GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: sortedTables.length,
      itemBuilder: (context, index) {
        final tableNumber = sortedTables[index];
              final tableData = filteredTables[tableNumber]!;
              
              // 🆕 Filtrer les services et sessions pour ne garder que ceux de la date sélectionnée
              final filteredTableData = _filterServicesByDate(tableData);
              
        final sessions = List<Map<String, dynamic>>.from(
                (filteredTableData['sessions'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []
        );
              final services = filteredTableData['services'] as Map<String, dynamic>? ?? {};
              final serviceCount = services.length; // 🆕 Nombre de services filtrés uniquement

        return HistoryTableCard(
          tableNumber: tableNumber,
          sessions: sessions,
          sessionCount: serviceCount,
                tableData: filteredTableData, // 🆕 Passer tableData filtré pour accéder aux stats
          onTap: () => _showTableHistoryDialog(context, tableNumber),
        );
      },
          ),
        ),
      ],
    );
  }
  
  // 🆕 Widget pour la barre de filtre de date
  Widget _buildDateFilterBar(BuildContext context) {
    final isToday = _selectedDate.year == DateTime.now().year &&
                    _selectedDate.month == DateTime.now().month &&
                    _selectedDate.day == DateTime.now().day;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Aujourd\'hui' : 'Date sélectionnée',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Row(
                    children: [
                      Text(
                        _formatDateForDisplay(_selectedDate),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_drop_down, color: Colors.blue.shade700),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bouton pour revenir à aujourd'hui si on n'est pas sur aujourd'hui
          if (!isToday)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime.now();
                });
              },
              icon: Icon(Icons.today, size: 18, color: Colors.blue.shade700),
              label: Text(
                'Aujourd\'hui',
                style: TextStyle(color: Colors.blue.shade700),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }

  // 🆕 Fonction pour formater la date pour l'affichage
  String _formatDateForDisplay(DateTime date) {
    final weekdays = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    
    final weekday = weekdays[date.weekday - 1];
    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;
    
    return '$weekday $day $month $year';
  }

  void _showTableHistoryDialog(
    BuildContext context,
    String tableNumber,
  ) {
    showDialog(
      context: context,
      builder: (context) => TableHistoryDialog(
        tableNumber: tableNumber,
        processedTables: widget.processedTables,
        selectedDate: _selectedDate, // 🆕 Passer la date sélectionnée pour filtrer les services
      ),
    );
  }
}

