class HistoryRecord {
  final String storyId;
  final String title;
  final String synopsis;
  final DateTime? completedDate;
  final String region;
  final List<String> routeSummary;
  final String? vlogId;
  final String? postcardReviewUrl;

  const HistoryRecord({
    required this.storyId,
    required this.title,
    required this.synopsis,
    required this.completedDate,
    required this.region,
    required this.routeSummary,
    required this.vlogId,
    required this.postcardReviewUrl,
  });

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      storyId: json['story_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      synopsis: json['synopsis']?.toString() ?? '',
      completedDate: DateTime.tryParse(
        json['completed_date']?.toString() ?? '',
      ),
      region: json['region']?.toString() ?? '',
      routeSummary: json['route_summary'] is List
          ? (json['route_summary'] as List)
                .map((item) => item.toString())
                .toList()
          : const [],
      vlogId: json['vlog_id']?.toString(),
      postcardReviewUrl: json['postcard_review_url']?.toString(),
    );
  }
}
