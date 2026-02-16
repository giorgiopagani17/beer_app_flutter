import 'package:flutter/material.dart';
import '../../models/beer.dart';
import '../../services/api_service.dart';

class BeerListCard extends StatefulWidget {
  final Beer beer;
  final VoidCallback onTap;
  final void Function(Beer, bool)? onFavoriteChanged;

  const BeerListCard({
    super.key,
    required this.beer,
    required this.onTap,
    this.onFavoriteChanged,
  });

  @override
  State<BeerListCard> createState() => _BeerListCardState();
}

class _BeerListCardState extends State<BeerListCard> {
  late bool _isFavorite;
  bool _isTogglingFavorite = false;
  ApiService? _apiService;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.beer.isFavorite;
    _initializeApiService();
  }

  @override
  void didUpdateWidget(covariant BeerListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.beer.isFavorite != _isFavorite) {
      setState(() {
        _isFavorite = widget.beer.isFavorite;
      });
    }
  }

  Future<void> _initializeApiService() async {
    _apiService = await ApiService.getInstance();
    setState(() {}); // Aggiorna lo stato quando ApiService è pronto
  }

  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite || _apiService == null) return;

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      if (_isFavorite) {
        final response = await _apiService!.deleteFavorite(widget.beer.id);
        if (!response.isSuccess) throw response.error ?? 'Errore nella rimozione dai preferiti';
      } else {
        final response = await _apiService!.addToFavorite(widget.beer.id);
        if (!response.isSuccess) throw response.error ?? 'Errore nell\'aggiunta ai preferiti';
      }

      setState(() {
        _isFavorite = !_isFavorite;
      });

      widget.onFavoriteChanged?.call(widget.beer, _isFavorite);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nell\'aggiornare i preferiti: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isTogglingFavorite = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Immagine a sinistra
            Container(
              width: 80,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.beer.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[700],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 30,
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Contenuto centrale con Stack per posizionamento assoluto
            Expanded(
              child: Stack(
                children: [
                  // Contenuto principale
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Prima riga: Nome della birra e icona cuore
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nome della birra
                          Expanded(
                            child: Text(
                              widget.beer.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Icona cuore cliccabile in alto a destra
                          GestureDetector(
                            onTap: _toggleFavorite,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return ScaleTransition(scale: animation, child: child);
                                },
                                child: _isTogglingFavorite
                                    ? const SizedBox(
                                        key: ValueKey('loading'),
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Icon(
                                        key: ValueKey(_isFavorite),
                                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                                        color: _isFavorite ? Colors.red : Colors.grey,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Sottotitolo
                      Text(
                        widget.beer.subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Informazioni rapide
                      Row(
                        children: [
                          Icon(Icons.water_drop, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.beer.alcoholContent.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on, size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.beer.origin,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Bottone Scopri posizionato in basso a destra
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: ElevatedButton(
                      onPressed: widget.onTap,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Scopri',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}