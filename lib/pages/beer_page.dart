import 'package:flutter/material.dart';
import '../models/beer.dart';
import '../components/single_beer/beer_image_widget.dart';
import '../components/single_beer/beer_title_widget.dart';
import '../components/single_beer/beer_info_card.dart';
import '../services/api_service.dart';

class BeerPage extends StatefulWidget {
  final Beer beer;
  final void Function(Beer, bool)? onFavoriteChanged;

  const BeerPage({super.key, required this.beer, this.onFavoriteChanged});

  @override
  State<BeerPage> createState() => _BeerPageState();
}

class _BeerPageState extends State<BeerPage> {
  late bool _isFavorite;
  bool _isToggling = false;
  ApiService? _apiService;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.beer.isFavorite;
    _initializeApiService();
  }

  Future<void> _initializeApiService() async {
    _apiService = await ApiService.getInstance();
  }

  Future<void> _toggleFavorite() async {
    if (_isToggling || _apiService == null) return;
    setState(() {
      _isToggling = true;
    });

    try {
      if (_isFavorite) {
        final response = await _apiService!.deleteFavorite(widget.beer.id);
        if (!response.isSuccess) {
          throw response.error ?? 'Errore nella rimozione dai preferiti';
        }
      } else {
        final response = await _apiService!.addToFavorite(widget.beer.id);
        if (!response.isSuccess) {
          throw response.error ?? 'Errore nell\'aggiunta ai preferiti';
        }
      }
      setState(() {
        _isFavorite = !_isFavorite;
      });
      widget.onFavoriteChanged?.call(widget.beer, _isFavorite);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nel cambiare preferito: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isToggling = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.beer.name),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: Colors.red,
              ),
              onPressed: _toggleFavorite,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BeerImageWidget(imageUrl: widget.beer.imageUrl),
            const SizedBox(height: 24),
            BeerTitleWidget(
              title: widget.beer.name,
              subtitle: widget.beer.subtitle,
            ),
            const SizedBox(height: 20),

            // Descrizione
            BeerInfoCard(
              title: 'Descrizione',
              icon: Icons.description,
              iconColor: Colors.grey[400],
              borderColor: Colors.grey[800],
              child: Text(
                widget.beer.description,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.white,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
            const SizedBox(height: 16),

            // Caratteristiche
            BeerInfoCard(
              title: 'Caratteristiche',
              icon: Icons.info,
              iconColor: Colors.grey[400],
              borderColor: Colors.grey[800],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CharacteristicRow(
                    icon: Icons.water_drop,
                    iconColor: Colors.grey[400]!,
                    text: 'Gradazione alcolica: ${widget.beer.alcoholContent.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 8),
                  _CharacteristicRow(
                    icon: Icons.color_lens,
                    iconColor: Colors.grey[400]!,
                    text: 'Colore: ${widget.beer.color}',
                  ),
                  const SizedBox(height: 8),
                  _CharacteristicRow(
                    icon: Icons.bubble_chart,
                    iconColor: Colors.grey[400]!,
                    text: 'Schiuma: ${widget.beer.foam}',
                  ),
                  const SizedBox(height: 8),
                  _CharacteristicRow(
                    icon: Icons.location_on,
                    iconColor: Colors.grey[400]!,
                    text: 'Origine: ${widget.beer.origin}',
                  ),
                  const SizedBox(height: 8),
                  _CharacteristicRow(
                    icon: Icons.factory,
                    iconColor: Colors.grey[400]!,
                    text: 'Fabbrica: ${widget.beer.brewery}',
                  ),
                  const SizedBox(height: 8),
                  _CharacteristicRow(
                    icon: Icons.thermostat,
                    iconColor: Colors.grey[400]!,
                    text: 'Temperatura di servizio: ${widget.beer.servingTemperature}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Istruzioni di spillatura
            BeerInfoCard(
              title: 'Come Spillare',
              icon: Icons.local_bar,
              iconColor: Colors.grey[400],
              borderColor: Colors.grey[800],
              child: Text(
                widget.beer.pouringInstructions,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Note di degustazione
            BeerInfoCard(
              title: 'Note di Degustazione',
              icon: Icons.emoji_food_beverage,
              iconColor: Colors.grey[400],
              borderColor: Colors.grey[800],
              child: Text(
                widget.beer.tastingNotes,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Riga caratteristica riutilizzabile
class _CharacteristicRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _CharacteristicRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}