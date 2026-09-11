import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dio_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

class ApiClient {
  final Dio _dio;
  ApiClient(this._dio);

  // --- Auth ---
  Future<Map<String, dynamic>> verifyAuth() async {
    final resp = await _dio.post('/auth/verify');
    return resp.data as Map<String, dynamic>;
  }

  // --- User ---
  Future<Map<String, dynamic>> getMe() async {
    final resp = await _dio.get('/me');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> updateMe(Map<String, dynamic> data) async {
    await _dio.patch('/me', data: data);
  }

  Future<Map<String, dynamic>> uploadTryOnPhoto(String filePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    final resp = await _dio.post(
      '/me/try-on-photo',
      data: formData,
      options: Options(receiveTimeout: const Duration(minutes: 1)),
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteTryOnPhoto() async {
    await _dio.delete('/me/try-on-photo');
  }

  Future<Map<String, dynamic>> getAvatarProfile() async {
    final resp = await _dio.get('/me/avatar-profile');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> renderAvatar(
    Map<String, String> slots, {
    String pose = 'natural',
    String style = 'studio',
    String quality = 'hd',
    bool force = false,
  }) async {
    final resp = await _dio.post(
      '/avatar/render',
      data: {
        'slots': slots,
        'pose': pose,
        'style': style,
        'quality': quality,
        'force': force,
      },
      options: Options(receiveTimeout: const Duration(minutes: 2)),
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> avatarRenderStatus(
    String outfitId, {
    String? jobId,
  }) async {
    final resp = await _dio.get(
      '/avatar/render/$outfitId/status',
      queryParameters: {if (jobId != null) 'job_id': jobId},
    );
    return resp.data as Map<String, dynamic>;
  }

  /// Previously rendered Avatar Studio looks (saved previews).
  Future<Map<String, dynamic>> avatarLookHistory({int limit = 24}) async {
    final resp = await _dio.get(
      '/avatar/history',
      queryParameters: {'limit': limit},
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteAvatarLook(String outfitId) async {
    await _dio.delete('/avatar/history/$outfitId');
  }

  Future<Map<String, dynamic>> externalTryOn(String filePath) async {
    final formData = FormData.fromMap({
      'reference_image': await MultipartFile.fromFile(filePath),
    });
    final resp = await _dio.post(
      '/try-on/external',
      data: formData,
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> externalTryOnStatus(String sessionId) async {
    final resp = await _dio.get('/try-on/external/$sessionId');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> tryOnHistory({int limit = 20}) async {
    final resp = await _dio.get(
      '/try-on/history',
      queryParameters: {'limit': limit},
    );
    return resp.data as Map<String, dynamic>;
  }

  // --- Preferences ---
  Future<void> savePreferences(Map<String, dynamic> prefs) async {
    await _dio.put('/me/preferences', data: prefs);
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final resp = await _dio.get('/me/preferences');
    return resp.data as Map<String, dynamic>;
  }

  // --- Items ---
  Future<Map<String, dynamic>> uploadItem(String filePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    final resp = await _dio.post(
      '/items/upload',
      data: formData,
      options: Options(receiveTimeout: const Duration(seconds: 45)),
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getItems({
    String? category,
    String? color,
    String? search,
    String sort = 'newest',
    int limit = 50,
    int offset = 0,
  }) async {
    final resp = await _dio.get('/items', queryParameters: {
      if (category != null) 'category': category,
      if (color != null) 'color': color,
      if (search != null && search.isNotEmpty) 'search': search,
      'sort': sort,
      'limit': limit,
      'offset': offset,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getItem(String id) async {
    final resp = await _dio.get('/items/$id');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> updateItem(String id, Map<String, dynamic> updates) async {
    await _dio.patch('/items/$id', data: updates);
  }

  Future<void> deleteItem(String id) async {
    await _dio.delete('/items/$id');
  }

  // --- Outfits ---
  Future<Map<String, dynamic>> generateOutfits(String occasion) async {
    final resp = await _dio.post(
      '/outfits/generate',
      data: {'occasion': occasion},
      options: Options(receiveTimeout: const Duration(minutes: 2)),
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> shuffleOutfit(String occasion) async {
    final resp =
        await _dio.post('/outfits/shuffle', data: {'occasion': occasion});
    return resp.data as Map<String, dynamic>;
  }

  Future<void> submitFeedback(String outfitId, String action) async {
    await _dio.post('/outfits/$outfitId/feedback', data: {'action': action});
  }

  Future<Map<String, dynamic>> getTodayOutfits() async {
    final resp = await _dio.get('/outfits/today');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> visualizeOutfit(String outfitId,
      {bool force = false}) async {
    final resp = await _dio.post(
      '/outfits/$outfitId/visualize',
      queryParameters: {if (force) 'force': true},
      options: Options(receiveTimeout: const Duration(minutes: 2)),
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> visualizeOutfitStatus(
    String outfitId, {
    String? jobId,
  }) async {
    final resp = await _dio.get(
      '/outfits/$outfitId/visualize/status',
      queryParameters: {if (jobId != null) 'job_id': jobId},
    );
    return resp.data as Map<String, dynamic>;
  }

  /// Post-result freeform refine of the latest try-on preview (pose, background, etc.).
  Future<Map<String, dynamic>> refineVisualize(
    String outfitId,
    String message,
  ) async {
    final resp = await _dio.post(
      '/outfits/$outfitId/visualize/refine',
      data: {'message': message},
      options: Options(receiveTimeout: const Duration(minutes: 2)),
    );
    return resp.data as Map<String, dynamic>;
  }

  // --- Lookbooks ---
  Future<Map<String, dynamic>> getLookbooks() async {
    final resp = await _dio.get('/lookbooks');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLookbook(String name) async {
    final resp = await _dio.post('/lookbooks', data: {'name': name});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLookbook(String id) async {
    final resp = await _dio.get('/lookbooks/$id');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> saveOutfitToLookbook(String lookbookId, String outfitId) async {
    await _dio.post('/lookbooks/$lookbookId/outfits/$outfitId');
  }

  Future<void> removeOutfitFromLookbook(
      String lookbookId, String outfitId) async {
    await _dio.delete('/lookbooks/$lookbookId/outfits/$outfitId');
  }

  Future<void> renameLookbook(String id, String name) async {
    await _dio.patch('/lookbooks/$id', data: {'name': name});
  }

  Future<void> deleteLookbook(String id) async {
    await _dio.delete('/lookbooks/$id');
  }

  // --- Outfit chat refinement ---
  Future<Map<String, dynamic>> refineOutfit(
      String outfitId, String message) async {
    final resp = await _dio.post(
      '/outfits/$outfitId/refine',
      data: {'message': message},
      options: Options(receiveTimeout: const Duration(minutes: 1)),
    );
    return resp.data as Map<String, dynamic>;
  }

  // --- Item pairings ---
  Future<Map<String, dynamic>> getPairings(String itemId,
      {int limit = 5}) async {
    final resp = await _dio
        .get('/items/$itemId/pairings', queryParameters: {'limit': limit});
    return resp.data as Map<String, dynamic>;
  }

  // --- Wardrobe gap analysis ---
  Future<Map<String, dynamic>> getWardrobeGaps() async {
    final resp = await _dio.get(
      '/wardrobe/gaps',
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );
    return resp.data as Map<String, dynamic>;
  }

  // --- User stats ---
  Future<Map<String, dynamic>> getProfileStats() async {
    final resp = await _dio.get('/me/stats');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteMe() async {
    await _dio.delete('/me');
  }

  // --- Weather ---
  Future<Map<String, dynamic>> getWeather({String? city}) async {
    final resp = await _dio.get('/weather', queryParameters: {
      if (city != null) 'city': city,
    });
    return resp.data as Map<String, dynamic>;
  }

  // --- Push ---
  Future<void> registerPushToken(String token, String platform) async {
    await _dio
        .post('/push/register', data: {'token': token, 'platform': platform});
  }

  Future<void> unregisterPushToken() async {
    await _dio.delete('/push/unregister');
  }

  // --- Calendar ---
  Future<Map<String, dynamic>> getCalendarMonth(String month) async {
    final resp = await _dio.get('/calendar', queryParameters: {'month': month});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> assignOutfitToDate(
      String date, String outfitId) async {
    final resp =
        await _dio.post('/calendar/$date', data: {'outfit_id': outfitId});
    return resp.data as Map<String, dynamic>;
  }

  // --- Notifications ---
  Future<Map<String, dynamic>> getNotifications(
      {int limit = 50, int offset = 0}) async {
    final resp = await _dio.get('/notifications',
        queryParameters: {'limit': limit, 'offset': offset});
    return resp.data as Map<String, dynamic>;
  }

  Future<int> getUnreadCount() async {
    final resp = await _dio.get('/notifications/unread-count');
    return resp.data['unread_count'] as int;
  }

  Future<void> markNotificationRead(String id) async {
    await _dio.put('/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.put('/notifications/read-all');
  }

  // --- Analytics ---
  Future<Map<String, dynamic>> getAnalyticsOverview() async {
    final resp = await _dio.get('/analytics/overview');
    return resp.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getCategoryBreakdown() async {
    final resp = await _dio.get('/analytics/category-breakdown');
    return resp.data as List<dynamic>;
  }

  Future<List<dynamic>> getWearHistory({int days = 30}) async {
    final resp = await _dio.get(
      '/analytics/wear-history',
      queryParameters: {'days': days},
    );
    return resp.data as List<dynamic>;
  }
}
