import 'package:flutter/material.dart';

class BeerInfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;
  final Color? cardColor;
  final Color? titleColor;
  final Color? borderColor;

  const BeerInfoCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.iconColor,
    this.cardColor,
    this.titleColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveTitleColor = titleColor ?? Colors.deepPurple[200]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Material(
        color: cardColor ?? Colors.transparent, // sfondo trasparente
        elevation: 0,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor ?? Colors.grey[850]!,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null)
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        icon,
                        color: effectiveTitleColor, // stessa tinta del titolo
                        size: 24,
                      ),
                    ),
                  if (icon != null) const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: effectiveTitleColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}