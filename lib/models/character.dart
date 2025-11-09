class Character {
  final int id;
  final String name;
  final String? imageUrl;

  Character({required this.id, required this.name, this.imageUrl});

  factory Character.fromJson(Map<String, dynamic> json) {
    final image = json['image'];
    String? imageUrl;
    if (image != null) {
      imageUrl = image['original'] ?? image['preview'];
      if (imageUrl != null && !imageUrl.startsWith('https')) {
        imageUrl = 'https://shikimori.one$imageUrl';
      }
    }

    return Character(
      id: json['id'],
      name: json['russian'] ?? json['name'],
      imageUrl: imageUrl,
    );
  }
}
