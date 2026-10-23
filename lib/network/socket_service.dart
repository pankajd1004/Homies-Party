import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';
import 'api_config.dart';
import 'models/room.dart';

/// Service managing real-time Socket.IO communication with the backend.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;

  final _connectionStateController = StreamController<bool>.broadcast();
  final _roomUpdatedController = StreamController<Room>.broadcast();
  final _roomStartedController = StreamController<Room>.broadcast();

  bool get isConnected => _isConnected;
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;
  Stream<Room> get onRoomUpdated => _roomUpdatedController.stream;
  Stream<Room> get onRoomStarted => _roomStartedController.stream;

  /// Connects to the backend Socket.IO server using the provided Firebase ID token.
  Future<void> connect(String token) async {
    if (_socket != null && _isConnected) {
      return;
    }

    disconnect();

    final completer = Completer<void>();

    final options = io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .setReconnectionAttempts(5)
        .setAuth({'token': token})
        .build();

    _socket = io.io(ApiConfig.baseUrl, options);

    _socket!.onConnect((_) {
      _isConnected = true;
      _connectionStateController.add(true);
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _connectionStateController.add(false);
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      _connectionStateController.add(false);
      if (!completer.isCompleted) {
        completer.completeError(
          ApiException(
            statusCode: 401,
            error: 'SocketConnectError',
            message: err.toString(),
          ),
        );
      }
    });

    // Listen for room updates
    _socket!.on('room:updated', (data) {
      if (data is Map<String, dynamic>) {
        final room = Room.fromJson(data);
        _roomUpdatedController.add(room);
      }
    });

    // Listen for game start
    _socket!.on('room:started', (data) {
      if (data is Map<String, dynamic>) {
        final room = Room.fromJson(data);
        _roomStartedController.add(room);
      }
    });

    // Timeout if connection doesn't establish
    Future.delayed(const Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        completer.completeError(
          const ApiException(
            statusCode: 408,
            error: 'ConnectionTimeout',
            message: 'Timed out connecting to real-time server.',
          ),
        );
      }
    });

    return completer.future;
  }

  /// Subscribes to room updates via Socket.IO for the given room [code].
  ///
  /// Returns the current [Room] state received in the server acknowledgement.
  Future<Room> subscribeToRoom(String code) {
    final completer = Completer<Room>();
    if (_socket == null || !_isConnected) {
      completer.completeError(
        const ApiException(
          statusCode: 503,
          error: 'NotConnected',
          message: 'Socket is not connected to the real-time server.',
        ),
      );
      return completer.future;
    }

    _socket!.emitWithAck(
      'room:subscribe',
      {'code': code.trim().toUpperCase()},
      ack: (response) {
        if (response is Map) {
          final map = Map<String, dynamic>.from(response);
          if (map.containsKey('error')) {
            completer.completeError(
              ApiException(
                statusCode: map['error'] == 'Forbidden'
                    ? 403
                    : (map['error'] == 'Not Found' ? 404 : 400),
                error: map['error'].toString(),
                message: map['message']?.toString() ?? 'Subscription failed',
              ),
            );
            return;
          }

          final roomData = map['room'] is Map<String, dynamic>
              ? map['room'] as Map<String, dynamic>
              : map;

          completer.complete(Room.fromJson(roomData));
        } else {
          completer.completeError(
            const ApiException(
              statusCode: 500,
              error: 'InvalidResponse',
              message: 'Invalid room:subscribe acknowledgement response.',
            ),
          );
        }
      },
    );

    return completer.future;
  }

  /// Unsubscribes from room events for [code].
  Future<void> unsubscribeFromRoom(String code) {
    final completer = Completer<void>();
    if (_socket == null || !_isConnected) {
      completer.complete();
      return completer.future;
    }

    _socket!.emitWithAck(
      'room:unsubscribe',
      {'code': code.trim().toUpperCase()},
      ack: (_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    // Ensure future completes even if server doesn't ack
    Future.delayed(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    return completer.future;
  }

  /// Disconnects the socket and resets connection state.
  void disconnect() {
    if (_socket != null) {
      try {
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }
    _isConnected = false;
    _connectionStateController.add(false);
  }
}
