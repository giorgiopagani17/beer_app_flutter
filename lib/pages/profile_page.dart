import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../components/games/beer_pouring_game.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AuthService? _authService;
  bool _isInitializing = true;
  bool _isGameHovered = false;

  List<dynamic> _scores = [];
  bool _isLoadingScores = true;

  @override
  void initState() {
    super.initState();
    _initializeAuthService();
    _fetchScores();
  }

  Future<void> _initializeAuthService() async {
    try {
      _authService = await AuthService.getInstance();
    } catch (e) {
      debugPrint('Error initializing AuthService in ProfilePage: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _fetchScores() async {
    setState(() => _isLoadingScores = true);
    final api = await ApiService.getInstance();
    final response = await api.getScores(limit: 10);
    if (mounted) {
      setState(() {
        _scores = response.isSuccess ? (response.data ?? []) : [];
        _isLoadingScores = false;
      });
    }
  }

  void _startBeerPouringGame(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BeerPouringGame(),
      ),
    ).then((_) => _fetchScores());
  }

  Future<void> _logout() async {
    if (_authService == null) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            const Text('Logout'),
          ],
        ),
        content: const Text(
          'Sei sicuro di voler uscire dal tuo account?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annulla',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _authService!.logout();
    }
  }

  double get _averageScore {
    if (_scores.isEmpty) return 0;
    final validScores = _scores
        .map((s) => s['score'] ?? s['value'] ?? 0)
        .whereType<num>()
        .toList();
    if (validScores.isEmpty) return 0;
    return validScores.reduce((a, b) => a + b) / validScores.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, size: 64, color: Colors.amber),
              SizedBox(height: 16),
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.amber)),
              SizedBox(height: 16),
              Text('Caricamento profilo...'),
            ],
          ),
        ),
      );
    }

    double maxWidth = 380;
    double screenWidth = MediaQuery.of(context).size.width;
    double contentWidth = screenWidth < maxWidth ? screenWidth - 32 : maxWidth;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Box profilo coerente
                  Container(
                    width: contentWidth,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(top: 24, bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 56,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _authService?.userName ?? 'Il Tuo Profilo',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Account Attivo',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cards funzionalità e storico punteggi
                  Container(
                    width: contentWidth,
                    child: Column(
                      children: [
                        // Card Gioco Spillatura con hover e focus arrotondato
                        Theme(
                          data: Theme.of(context).copyWith(
                            highlightColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                          ),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setState(() => _isGameHovered = true),
                              onExit: (_) => setState(() => _isGameHovered = false),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.sports_esports, color: Colors.orange, size: 24),
                                      ),
                                      title: const Text(
                                        'Gioco Spillatura',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                      ),
                                      subtitle: const Text(
                                        'Testa le tue abilità da barista!',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: const Color.fromARGB(137, 255, 255, 255),
                                      ),
                                      hoverColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      selectedTileColor: Colors.transparent,
                                      selected: false,
                                      autofocus: false,
                                      enableFeedback: false,
                                      onTap: () => _startBeerPouringGame(context),
                                    ),
                                  ),
                                  if (_isGameHovered)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            color: Colors.black.withOpacity(0.08),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: double.infinity, // Occupa tutta la larghezza del parent (che è già contentWidth)
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Storico Punteggi Spillatura',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_scores.isNotEmpty)
                                      Row(
                                        children: [
                                          Icon(Icons.leaderboard, color: Colors.amber.shade700, size: 22),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Media: ',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            _averageScore.toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (_scores.isNotEmpty) const SizedBox(height: 10),
                                    if (_isLoadingScores)
                                      const Center(child: CircularProgressIndicator())
                                    else if (_scores.isEmpty)
                                      const SizedBox(
                                        height: 120, // Mantieni l'altezza anche senza dati
                                        child: Center(
                                          child: Text(
                                            'Nessun punteggio registrato.',
                                            style: TextStyle(fontSize: 15, color: Colors.grey),
                                          ),
                                        ),
                                      )
                                    else
                                      SizedBox(
                                        height: 120,
                                        child: ListView.separated(
                                          physics: const AlwaysScrollableScrollPhysics(),
                                          itemCount: _scores.length,
                                          separatorBuilder: (_, __) => const Divider(height: 16),
                                          itemBuilder: (context, i) {
                                            final score = _scores[i];
                                            final value = score['score'] ?? score['value'] ?? 0;
                                            final dateStr = score['createdAt'] ?? score['date'] ?? '';
                                            final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;
                                            final formattedDate = date != null
                                                ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
                                                  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                                                : '';
                        
                                            IconData icon;
                                            Color iconColor;
                                            if (value >= 90) {
                                              icon = Icons.emoji_events;
                                              iconColor = Colors.amber.shade700;
                                            } else if (value >= 75) {
                                              icon = Icons.star_rounded;
                                              iconColor = Colors.lightBlue;
                                            } else if (value >= 60) {
                                              icon = Icons.thumb_up_rounded;
                                              iconColor = Colors.green;
                                            } else {
                                              icon = Icons.warning_amber_rounded;
                                              iconColor = Colors.redAccent;
                                            }
                        
                                            return Row(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: iconColor.withOpacity(0.12),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  padding: const EdgeInsets.all(10),
                                                  child: Icon(icon, color: iconColor, size: 28),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Punteggio: $value',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      if (formattedDate.isNotEmpty)
                                                        Text(
                                                          formattedDate,
                                                          style: const TextStyle(
                                                            fontSize: 13,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                
                      ],
                    ),
                  ),

                  // Bottone logout coerente
                  Container(
                    width: contentWidth,
                    margin: const EdgeInsets.only(top: 24, bottom: 24),
                    child: ElevatedButton.icon(
                      onPressed: (_authService == null || (_authService?.isLoading ?? false))
                          ? null
                          : _logout,
                      icon: (_authService?.isLoading ?? false)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.logout, size: 20),
                      label: Text(
                        (_authService?.isLoading ?? false) ? 'Disconnessione...' : 'Logout',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}