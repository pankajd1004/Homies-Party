import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../network/network.dart';
import '../ui/app_card.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';

/// Minimal standalone Online Lobby screen establishing the Flutter-to-backend foundation.
/// Provides room creation, joining, ready states, and live Socket.IO room sync.
class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _apiClient = ApiClient();
  final _authService = AuthService();
  final _socketService = SocketService();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  UserProfile? _userProfile;
  Room? _currentRoom;
  int _selectedMaxPlayers = 4;

  StreamSubscription<Room>? _roomUpdatedSub;
  StreamSubscription<Room>? _roomStartedSub;
  StreamSubscription<bool>? _socketConnSub;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _roomUpdatedSub?.cancel();
    _roomStartedSub?.cancel();
    _socketConnSub?.cancel();
    _codeController.dispose();
    if (_currentRoom != null) {
      _socketService.unsubscribeFromRoom(_currentRoom!.code);
    }
    super.dispose();
  }

  void _setupSocketListeners() {
    _roomUpdatedSub = _socketService.onRoomUpdated.listen((updatedRoom) {
      if (!mounted) return;
      if (_currentRoom != null && _currentRoom!.code == updatedRoom.code) {
        setState(() {
          _currentRoom = updatedRoom;
        });
      }
    });

    _roomStartedSub = _socketService.onRoomStarted.listen((startedRoom) {
      if (!mounted) return;
      if (_currentRoom != null && _currentRoom!.code == startedRoom.code) {
        setState(() {
          _currentRoom = startedRoom;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The host has started the game!'),
            backgroundColor: AppPalette.success,
          ),
        );
      }
    });

    _socketConnSub = _socketService.onConnectionStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _apiClient.authenticateGuest();
      final token = await _authService.getIdToken();
      await _socketService.connect(token);

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createRoom() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final room = await _apiClient.createRoom(maxPlayers: _selectedMaxPlayers);
      await _socketService.subscribeToRoom(room.code);

      if (mounted) {
        setState(() {
          _currentRoom = room;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid room code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final room = await _apiClient.joinRoom(code);
      await _socketService.subscribeToRoom(room.code);

      if (mounted) {
        _codeController.clear();
        setState(() {
          _currentRoom = room;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleReady() async {
    if (_currentRoom == null || _userProfile == null) return;
    final myPlayer = _currentRoom!.getPlayer(_userProfile!.id);
    final nextReady = !(myPlayer?.isReady ?? false);

    setState(() => _isLoading = true);
    try {
      final updatedRoom = await _apiClient.setReady(_currentRoom!.code, nextReady);
      if (mounted) {
        setState(() {
          _currentRoom = updatedRoom;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _leaveRoom() async {
    if (_currentRoom == null) return;
    final code = _currentRoom!.code;

    setState(() => _isLoading = true);
    try {
      await _socketService.unsubscribeFromRoom(code);
      await _apiClient.leaveRoom(code);

      if (mounted) {
        setState(() {
          _currentRoom = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentRoom = null;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startRoom() async {
    if (_currentRoom == null) return;

    setState(() => _isLoading = true);
    try {
      final updatedRoom = await _apiClient.startRoom(_currentRoom!.code);
      if (mounted) {
        setState(() {
          _currentRoom = updatedRoom;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showConfigDialog() {
    final controller = TextEditingController(text: ApiConfig.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.backgroundElevated,
        title: const Text('Backend URL Configuration', style: AppTextStyles.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure the server IP or tunnel address:',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: AppTextStyles.bodyBold,
              decoration: const InputDecoration(
                hintText: 'e.g. http://192.168.1.100:3000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Windows: http://127.0.0.1:3000\n'
              'Android Emulator: http://10.0.2.2:3000\n'
              'Physical Device: LAN IP (e.g. 192.168.x.x:3000)',
              style: AppTextStyles.caption.copyWith(color: AppPalette.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ApiConfig.setBaseUrl(controller.text);
              Navigator.of(ctx).pop();
              _initializeUser();
            },
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.backgroundTop,
      appBar: AppBar(
        backgroundColor: AppPalette.backgroundTop,
        elevation: 0,
        title: const Text('Online Multiplayer Lobby', style: AppTextStyles.heading),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppPalette.textSecondary),
            tooltip: 'Configure Backend URL',
            onPressed: _showConfigDialog,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppPalette.backgroundGradient),
        child: SafeArea(
          child: _currentRoom != null ? _buildRoomView() : _buildLobbyOverview(),
        ),
      ),
    );
  }

  Widget _buildLobbyOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection & Profile Status Card
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppPalette.ludo.withValues(alpha: 0.2),
                  child: const Text('🎮', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userProfile?.nickname ?? 'Connecting...',
                        style: AppTextStyles.heading,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _socketService.isConnected
                                  ? AppPalette.success
                                  : AppPalette.warning,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _socketService.isConnected
                                ? 'Real-time connected'
                                : 'Offline / Connecting',
                            style: AppTextStyles.caption.copyWith(color: AppPalette.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppPalette.textSecondary),
                    tooltip: 'Reconnect Profile',
                    onPressed: _initializeUser,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppPalette.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_errorMessage!, style: AppTextStyles.body.copyWith(color: AppPalette.danger)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 1. Create Room Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('✨', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Create a Room', style: AppTextStyles.heading),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start a private room and share the 6-character code with your friends.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 14),
                const Text('Max Players:', style: AppTextStyles.subheading),
                const SizedBox(height: 8),
                Row(
                  children: [2, 3, 4].map((count) {
                    final selected = _selectedMaxPlayers == count;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$count Players'),
                        selected: selected,
                        selectedColor: AppPalette.ludo,
                        onSelected: (val) {
                          if (val) setState(() => _selectedMaxPlayers = count);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.ludo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Room', style: AppTextStyles.button),
                    onPressed: _isLoading ? null : _createRoom,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Join Room Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🔑', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Join Room', style: AppTextStyles.heading),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter the 6-character code shared by the host to join.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: AppTextStyles.title.copyWith(letterSpacing: 4),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'e.g. ABC234',
                    hintStyle: AppTextStyles.title.copyWith(
                      color: AppPalette.textMuted.withValues(alpha: 0.4),
                      letterSpacing: 4,
                    ),
                    filled: true,
                    fillColor: AppPalette.backgroundElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.snl,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.login),
                    label: const Text('Join Room', style: AppTextStyles.button),
                    onPressed: _isLoading ? null : _joinRoom,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Backend connection info footer
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.wifi, size: 16, color: AppPalette.textMuted),
              label: Text(
                'Server: ${ApiConfig.baseUrl}',
                style: AppTextStyles.caption.copyWith(color: AppPalette.textMuted),
              ),
              onPressed: _showConfigDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomView() {
    final room = _currentRoom!;
    final myUserId = _userProfile?.id ?? '';
    final isHost = room.isUserHost(myUserId);
    final myPlayer = room.getPlayer(myUserId);
    final isReady = myPlayer?.isReady ?? false;
    final canStart = isHost && room.players.length >= 2 && room.players.every((p) => p.isReady);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Room Header Card
          AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ROOM CODE', style: AppTextStyles.caption.copyWith(letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              room.code,
                              style: AppTextStyles.title.copyWith(fontSize: 32, letterSpacing: 4),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: 'Copy Code',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: room.code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Room code copied to clipboard')),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: room.isPlaying
                            ? AppPalette.success.withValues(alpha: 0.2)
                            : AppPalette.ludo.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: room.isPlaying ? AppPalette.success : AppPalette.ludo,
                        ),
                      ),
                      child: Text(
                        room.status.toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          color: room.isPlaying ? AppPalette.success : AppPalette.ludoLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Players (${room.players.length}/${room.maxPlayers}):',
                        style: AppTextStyles.subheading),
                    if (isHost)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppPalette.carrom.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('👑 You are Host',
                            style: TextStyle(color: AppPalette.carrom, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Player list
          Expanded(
            child: ListView.separated(
              itemCount: room.players.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final player = room.players[index];
                final isMe = player.userId == myUserId;

                return AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isMe ? AppPalette.ludo : AppPalette.backgroundElevated,
                        child: Text(
                          player.nickname.isNotEmpty ? player.nickname[0].toUpperCase() : 'P',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(player.nickname, style: AppTextStyles.bodyBold),
                                if (isMe) ...[
                                  const SizedBox(width: 6),
                                  Text('(You)', style: AppTextStyles.caption.copyWith(color: AppPalette.ludoLight)),
                                ],
                                if (player.isHost) ...[
                                  const SizedBox(width: 6),
                                  const Text('👑', style: TextStyle(fontSize: 12)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: player.isReady
                              ? AppPalette.success.withValues(alpha: 0.2)
                              : AppPalette.danger.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          player.isReady ? 'READY' : 'NOT READY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: player.isReady ? AppPalette.success : AppPalette.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          if (_errorMessage != null) ...[
            Text(_errorMessage!, style: const TextStyle(color: AppPalette.danger, fontSize: 13)),
            const SizedBox(height: 10),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppPalette.danger),
                  ),
                  icon: const Icon(Icons.exit_to_app, color: AppPalette.danger),
                  label: const Text('Leave', style: TextStyle(color: AppPalette.danger)),
                  onPressed: _isLoading ? null : _leaveRoom,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReady ? AppPalette.warning : AppPalette.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(isReady ? Icons.close : Icons.check),
                  label: Text(
                    isReady ? 'Not Ready' : 'Ready Up',
                    style: AppTextStyles.button,
                  ),
                  onPressed: _isLoading ? null : _toggleReady,
                ),
              ),
            ],
          ),

          if (isHost) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: canStart ? AppPalette.ludo : AppPalette.textMuted.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Game', style: AppTextStyles.button),
              onPressed: canStart && !_isLoading ? _startRoom : null,
            ),
          ],
        ],
      ),
    );
  }
}
