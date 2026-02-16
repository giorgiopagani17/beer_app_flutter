import 'package:flutter/material.dart';
import '../../models/beer.dart';

class RecommendedBeerCard extends StatelessWidget {
  final Beer beer;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onRemove;

  const RecommendedBeerCard({
    super.key,
    required this.beer,
    this.onTap,
    this.onFavorite,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: beer.imageUrl != null
                          ? Image.network(
                              beer.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.sports_bar, size: 48),
                            )
                          : const Icon(Icons.sports_bar, size: 48),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (beer.brewery != null)
                          Text(
                            beer.brewery!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.red,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.favorite_border, color: Colors.white),
                  onPressed: onFavorite,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onRemove,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
