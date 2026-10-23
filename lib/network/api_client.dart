import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'models/room.dart';
import 'models/user_profile.dart';

/// Exception thrown when a backend API request fails.
class ApiException implements Exception {
  final int statusCode;
  final String error;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.error,
    required this.message,
  });

  @override
  String toString() => 'ApiException ($statusCode $error): $message';
}

/// HTTP client for interacting with the backend REST endpoints.
class ApiClient {
  final AuthService _authService;
  final http.Client _httpClient;

  ApiClient({
    AuthService? authService,
    http.Client? httpClient,
  })  : _authService = authService ?? AuthService(),
        _httpClient = httpClient ?? http.Client();

  /// Builds authorization headers using the current Firebase ID token.
  Future<Map<String, String>> _headers() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Parses error responses or throws an [ApiException].
  ApiException _parseError(int statusCode, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return ApiException(
        statusCode: statusCode,
        error: json['error'] as String? ?? 'Error',
        message: json['message'] as String? ?? body,
      );
    } catch (_) {
      return ApiException(
        statusCode: statusCode,
        error: 'HttpError',
        message: body.isNotEmpty ? body : 'Request failed with status $statusCode',
      );
    }
  }

  // --- Profile & Authentication ---

  /// Registers or retrieves a guest profile on the backend (`POST /v1/auth/guest`).
  Future<UserProfile> authenticateGuest() async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.guestAuthUrl),
      headers: headers,
      body: jsonEncode({}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(json);
      _authService.setProfile(profile);
      return profile;
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Fetches the authenticated user's profile (`GET /v1/me`).
  Future<UserProfile> getProfile() async {
    final headers = await _headers();
    final response = await _httpClient.get(
      Uri.parse(ApiConfig.meUrl),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(json);
      _authService.setProfile(profile);
      return profile;
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Updates the authenticated user's nickname and/or avatar (`PATCH /v1/me`).
  Future<UserProfile> updateProfile({String? nickname, String? avatar}) async {
    final headers = await _headers();
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (avatar != null) body['avatar'] = avatar;

    final response = await _httpClient.patch(
      Uri.parse(ApiConfig.meUrl),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(json);
      _authService.setProfile(profile);
      return profile;
    }

    throw _parseError(response.statusCode, response.body);
  }

  // --- Room Operations ---

  /// Creates a new room with a short code (`POST /v1/rooms`).
  Future<Room> createRoom({int maxPlayers = 4}) async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.roomsUrl),
      headers: headers,
      body: jsonEncode({'maxPlayers': maxPlayers}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Room.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Joins an existing room by code (`POST /v1/rooms/join`).
  Future<Room> joinRoom(String code) async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.joinRoomUrl),
      headers: headers,
      body: jsonEncode({'code': code.trim()}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Room.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Fetches the details and player list for a room (`GET /v1/rooms/:code`).
  Future<Room> getRoom(String code) async {
    final headers = await _headers();
    final response = await _httpClient.get(
      Uri.parse(ApiConfig.roomDetailsUrl(code.trim().toUpperCase())),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Room.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Updates the player's readiness state in a room (`POST /v1/rooms/:code/ready`).
  Future<Room> setReady(String code, bool ready) async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.roomReadyUrl(code.trim().toUpperCase())),
      headers: headers,
      body: jsonEncode({'ready': ready}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Room.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Leaves a room (`POST /v1/rooms/:code/leave`).
  Future<LeaveRoomResult> leaveRoom(String code) async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.roomLeaveUrl(code.trim().toUpperCase())),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return LeaveRoomResult.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Starts the game in the room (Host only, `POST /v1/rooms/:code/start`).
  Future<Room> startRoom(String code) async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.roomStartUrl(code.trim().toUpperCase())),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Room.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }
}
