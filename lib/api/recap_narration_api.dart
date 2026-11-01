import 'job_api.dart';

/// 回顧旁白語音（Job 模式）：
///   POST /api/History/{story_id}/Recap/NarrationJob            送出，拿 job_id
///   GET  /api/History/Recap/NarrationJob/{job_id}              每 3 秒查一次，done 的 result 是旁白語音
///   POST /api/History/Recap/NarrationJob/{job_id}/Cancel       取消／離開頁面時呼叫
///
/// result 的欄位後端沒有寫明，這裡原樣回傳 Map（有音檔網址的話通常是 audio_url），
/// 由使用的畫面自己取。
class RecapNarrationApi {
  RecapNarrationApi._();

  static Future<Map<String, dynamic>> generate({
    required String storyId,
    void Function(JobInfo job)? onProgress,
    void Function(String jobId)? onJobId,
  }) async {
    const String failMessage = '回顧旁白產生失敗';

    final String id = storyId.trim();

    if (id.isEmpty) throw Exception('缺少劇本 ID');

    final JobInfo first = await JobApi.startJson(
      '/api/History/${Uri.encodeComponent(id)}/Recap/NarrationJob',
      const {},
      failMessage: failMessage,
    );

    final dynamic result = await JobApi.waitForResult(
      first,
      pollPath: (jobId) =>
          '/api/History/Recap/NarrationJob/${Uri.encodeComponent(jobId)}',
      failMessage: failMessage,
      onProgress: onProgress,
      onJobId: onJobId,
    );

    if (result is Map) return Map<String, dynamic>.from(result);

    // result 直接是音檔網址字串的情況
    if (result is String && result.trim().isNotEmpty) {
      return {'audio_url': result.trim()};
    }

    throw Exception(failMessage);
  }

  static Future<void> cancel(String jobId) => JobApi.cancel(
    '/api/History/Recap/NarrationJob/${Uri.encodeComponent(jobId)}/Cancel',
  );
}
