import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import 'api_request.dart';

String resolveProfilePhotoUrl(String? photoPath) {
  if (photoPath == null || photoPath.isEmpty) return '';
  if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) return photoPath;
  final base = Uri.parse(ApiConfig.baseUrl);
  return base.replace(path: photoPath).toString();
}

class ProfileService {
  ProfileService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> fetchProfile(int userId) async {
    final response = await sendRequest(
      () => _client.get(Uri.parse('${ApiConfig.baseUrl}/users/$userId/profile')),
    );
    return Map<String, dynamic>.from(readData(response) as Map);
  }

  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String firstName,
    required String lastName,
    required String contactNumber,
    required String bio,
  }) async {
    final response = await sendRequest(
      () => _client.patch(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'contact_number': contactNumber,
          'bio': bio,
        }),
      ),
    );
    return Map<String, dynamic>.from(readData(response) as Map);
  }

  Future<Map<String, dynamic>> uploadPhoto({
    required int userId,
    required File file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/users/$userId/profile/photo'),
    )..files.add(await http.MultipartFile.fromPath('photo', file.path));
    final response = await sendRequest(() async => http.Response.fromStream(await request.send()));
    return Map<String, dynamic>.from(readData(response) as Map);
  }

  Future<Map<String, dynamic>> deletePhoto(int userId) async {
    final response = await sendRequest(
      () => _client.delete(Uri.parse('${ApiConfig.baseUrl}/users/$userId/profile/photo')),
    );
    return Map<String, dynamic>.from(readData(response) as Map);
  }

  void dispose() => _client.close();
}
