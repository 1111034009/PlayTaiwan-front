class Postcard {
  final String postcardId;
  final String storyId;
  final String postcardName;
  final String summary;
  final String imageUrl;
  final bool isNightEditionDefault;
  final String category;
  final int sortOrder;
  final bool isActive;

  const Postcard({
    required this.postcardId,
    required this.storyId,
    required this.postcardName,
    required this.summary,
    required this.imageUrl,
    required this.isNightEditionDefault,
    required this.category,
    required this.sortOrder,
    required this.isActive,
  });

  factory Postcard.fromJson(Map<String, dynamic> json) {
    return Postcard(
      postcardId: json['PostcardId'] ?? '',
      storyId: json['StoryId'] ?? '',
      postcardName: json['PostcardName'] ?? '',
      summary: json['Summary'] ?? '',
      imageUrl: json['ImageUrl'] ?? '',
      isNightEditionDefault: json['IsNightEditionDefault'] ?? false,
      category: json['Category'] ?? '',
      sortOrder: json['SortOrder'] ?? 0,
      isActive: json['IsActive'] ?? false,
    );
  }
}
