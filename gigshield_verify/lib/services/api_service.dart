import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../app/constants.dart';

class ApiService {
  static final String _baseUrl = AppConstants.baseUrl;

  /// POST /verification/start
  Future<Map<String, dynamic>> startVerification({
    required String sessionId,
    required String nonce,
    required String timestamp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/verification/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'nonce': nonce,
          'timestamp': timestamp,
          'device_platform': 'android',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException('Start failed: ${response.statusCode} ${response.body}');
    } on SocketException {
      throw ApiException('No network connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Unknown error: $e');
    }
  }

  /// POST /verification/upload — multipart with video + JSON metadata
  Future<Map<String, dynamic>> uploadVerification({
    required String sessionId,
    required String videoPath,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/verification/upload'),
      );
      request.fields['session_id'] = sessionId;
      request.fields['metadata'] = jsonEncode(metadata);

      final videoFile = File(videoPath);
      if (await videoFile.exists()) {
        request.files.add(await http.MultipartFile.fromPath(
          'video',
          videoPath,
          filename: 'session_$sessionId.mp4',
        ));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException('Upload failed: ${response.statusCode}');
    } on SocketException {
      throw ApiException('No network connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Upload error: $e');
    }
  }

  /// POST /verification/validate — get fraud score + status
  Future<Map<String, dynamic>> validateVerification({
    required String sessionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/verification/validate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': sessionId}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException('Validate failed: ${response.statusCode}');
    } on SocketException {
      throw ApiException('No network connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Validate error: $e');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
