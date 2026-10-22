import { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import { firebaseAuth } from './firebase';
import { pool } from './db';
import { getRoomDetailsById, DbUser, RoomResponse } from './rooms';

export let io: SocketIOServer | null = null;

export function broadcastRoomUpdated(roomCode: string, room: RoomResponse): void {
  if (io) {
    io.to(roomCode.toUpperCase()).emit('room:updated', room);
  }
}

export function broadcastRoomStarted(roomCode: string, room: RoomResponse): void {
  if (io) {
    io.to(roomCode.toUpperCase()).emit('room:started', room);
  }
}

export function setupSocketIO(httpServer: HttpServer): SocketIOServer {
  io = new SocketIOServer(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
  });

  // Authentication middleware: verify Firebase token in handshake.auth.token
  io.use(async (socket: Socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token || typeof token !== 'string') {
        return next(new Error('Authentication token is missing.'));
      }

      let decoded;
      try {
        decoded = await firebaseAuth.verifyIdToken(token);
      } catch (err: any) {
        return next(new Error('Invalid or expired authentication token.'));
      }

      // Check if user exists in database
      const userRes = await pool.query(
        'SELECT id, firebase_uid, nickname, avatar, created_at FROM users WHERE firebase_uid = $1',
        [decoded.uid]
      );

      if (userRes.rows.length === 0) {
        return next(new Error('User profile not found. Please register as guest first.'));
      }

      socket.data.user = userRes.rows[0] as DbUser;
      return next();
    } catch (err: any) {
      return next(new Error('Authentication failed.'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const user = socket.data.user as DbUser;

    // Event: room:subscribe
    socket.on('room:subscribe', async (data: any, callback?: (res: any) => void) => {
      try {
        const code = typeof data?.code === 'string' ? data.code.trim().toUpperCase() : '';
        if (!code) {
          if (typeof callback === 'function') {
            callback({ error: 'Bad Request', message: 'Room code is required.' });
          }
          return;
        }

        // Check if room exists
        const roomRes = await pool.query(
          'SELECT id, code FROM rooms WHERE UPPER(code) = $1',
          [code]
        );

        if (roomRes.rows.length === 0) {
          if (typeof callback === 'function') {
            callback({ error: 'Not Found', message: 'Room not found.' });
          }
          return;
        }

        const room = roomRes.rows[0];

        // Check if user is a member of that room
        const memberRes = await pool.query(
          'SELECT 1 FROM room_players WHERE room_id = $1 AND user_id = $2',
          [room.id, user.id]
        );

        if (memberRes.rows.length === 0) {
          if (typeof callback === 'function') {
            callback({ error: 'Forbidden', message: 'You are not a member of this room.' });
          }
          return;
        }

        // Join the Socket.IO room named for that code
        socket.join(room.code.toUpperCase());

        // Send current room state in acknowledgement
        const roomDetails = await getRoomDetailsById(room.id);
        if (typeof callback === 'function') {
          callback({
            success: true,
            room: roomDetails,
            ...roomDetails,
          });
        }
      } catch (err: any) {
        if (typeof callback === 'function') {
          callback({ error: 'Internal Server Error', message: 'Failed to subscribe to room.' });
        }
      }
    });

    // Event: room:unsubscribe
    socket.on('room:unsubscribe', (data: any, callback?: (res: any) => void) => {
      const code = typeof data?.code === 'string' ? data.code.trim().toUpperCase() : '';
      if (code) {
        socket.leave(code);
      }
      if (typeof callback === 'function') {
        callback({ success: true });
      }
    });

    // Clean up on disconnect
    socket.on('disconnect', () => {
      // Socket.IO leaves all joined rooms automatically
    });
  });

  return io;
}
