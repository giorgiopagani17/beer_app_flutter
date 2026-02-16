class Beer {
  final int id;
  final String name;
  final String subtitle;
  final String imageUrl;
  final String description;
  final double alcoholContent;
  final String color;
  final String foam;
  final String origin;
  final String brewery;
  final String tastingNotes;
  final String servingTemperature;
  final String pouringInstructions;
  final bool isFavorite;

  Beer({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.imageUrl,
    required this.description,
    required this.alcoholContent,
    required this.color,
    required this.foam,
    required this.origin,
    required this.brewery,
    required this.tastingNotes,
    required this.servingTemperature,
    required this.pouringInstructions,
    this.isFavorite = false,
  });

  factory Beer.fromJson(Map<String, dynamic> json) {
    return Beer(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      subtitle: json['subtitle'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      description: json['description'] ?? '',
      alcoholContent: (json['alcoholContent'] ?? 0.0).toDouble(),
      color: json['color'] ?? '',
      foam: json['foam'] ?? '',
      origin: json['origin'] ?? '',
      brewery: json['brewery'] ?? '',
      tastingNotes: json['tastingNotes'] ?? '',
      servingTemperature: json['servingTemperature'] ?? '',
      pouringInstructions: json['pouringInstructions'] ?? '',
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'description': description,
      'alcoholContent': alcoholContent,
      'color': color,
      'foam': foam,
      'origin': origin,
      'brewery': brewery,
      'tastingNotes': tastingNotes,
      'servingTemperature': servingTemperature,
      'pouringInstructions': pouringInstructions,
      'isFavorite': isFavorite,
    };
  }
}