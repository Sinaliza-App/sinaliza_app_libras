class Sign {
  final int? id;
  final String word;
  final String description;
  final String? videoUrl;
  final String? imageUrl;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;

  Sign({
    this.id,
    required this.word,
    required this.description,
    this.videoUrl,
    this.imageUrl,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Sign.fromMap(Map<String, dynamic> map) {
    return Sign(
      id: map['id'],
      word: map['word'],
      description: map['description'],
      videoUrl: map['video_url'],
      imageUrl: map['image_url'],
      category: map['category'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'description': description,
      'video_url': videoUrl,
      'image_url': imageUrl,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Sign copyWith({
    int? id,
    String? word,
    String? description,
    String? videoUrl,
    String? imageUrl,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Sign(
      id: id ?? this.id,
      word: word ?? this.word,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Sign(id: $id, word: $word, description: $description, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Sign && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}