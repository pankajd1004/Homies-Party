import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { Pool, PoolClient } from 'pg';
import { pool } from './db';
import { authenticate } from './auth';
import { broadcastRoomUpdated, broadcastRoomStarted } from './socket';

// 32-character set: A-Z and 2-9, excluding O, I, 0, 1
const ROOM_CODE_CHARSET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function generateRoomCode(): string {
  let code = '';
  for (let i = 0; i < 6; i++) {
    const randomIndex = Math.floor(Math.random() * ROOM_CODE_CHARSET.length);
    code += ROOM_CODE_CHARSET[randomIndex];
  }
  return code;
}

export interface DbUser {
  id: string;
  firebase_uid: string;
  nickname: string;
  avatar: string | null;
  created_at: string;
}

export interface RoomPlayerResponse {
  id: string;
  userId: string;
  user_id: string;
  nickname: string;
  avatar: string | null;
  isReady: boolean;
  is_ready: boolean;
  isHost: boolean;
  is_host: boolean;
  joinedAt: string;
  joined_at: string;
}

export interface RoomResponse {
  id: string;
  code: string;
  hostUserId: string;
  host_user_id: string;
  status: string;
  maxPlayers: number;
  max_players: number;
  createdAt: string;
  created_at: string;
  players: RoomPlayerResponse[];
}

export async function getDbUser(request: FastifyRequest, reply: FastifyReply): Promise<DbUser | null> {
  const uid = request.firebaseUser?.uid;
  if (!uid) {
    await reply.status(401).send({
      error: 'Unauthorized',
      message: 'Authentication token missing or invalid.',
    });
    return null;
  }

  const userRes = await pool.query(
    'SELECT id, firebase_uid, nickname, avatar, created_at FROM users WHERE firebase_uid = $1',
    [uid]
  );

  if (userRes.rows.length === 0) {
    await reply.status(404).send({
      error: 'Not Found',
      message: 'User profile not found. Please register as guest first.',
    });
    return null;
  }

  return userRes.rows[0];
}

export async function getRoomDetailsById(
  roomId: string,
  clientOrPool: Pool | PoolClient = pool
): Promise<RoomResponse | null> {
  const query = `
    SELECT
      r.id AS room_id,
      r.code,
      r.host_user_id,
      r.status,
      r.max_players,
      r.created_at AS room_created_at,
      rp.user_id,
      rp.is_ready,
      rp.joined_at,
      u.nickname,
      u.avatar
    FROM rooms r
    LEFT JOIN room_players rp ON rp.room_id = r.id
    LEFT JOIN users u ON u.id = rp.user_id
    WHERE r.id = $1
    ORDER BY rp.joined_at ASC
  `;

  const res = await clientOrPool.query(query, [roomId]);
  if (res.rows.length === 0) return null;

  const first = res.rows[0];
  const players: RoomPlayerResponse[] = res.rows
    .filter((row: any) => row.user_id !== null)
    .map((row: any) => ({
      id: row.user_id,
      userId: row.user_id,
      user_id: row.user_id,
      nickname: row.nickname || 'Unknown Player',
      avatar: row.avatar,
      isReady: row.is_ready,
      is_ready: row.is_ready,
      isHost: row.user_id === first.host_user_id,
      is_host: row.user_id === first.host_user_id,
      joinedAt: row.joined_at,
      joined_at: row.joined_at,
    }));

  return {
    id: first.room_id,
    code: first.code,
    hostUserId: first.host_user_id,
    host_user_id: first.host_user_id,
    status: first.status,
    maxPlayers: first.max_players,
    max_players: first.max_players,
    createdAt: first.room_created_at,
    created_at: first.room_created_at,
    players,
  };
}

export async function roomRoutes(server: FastifyInstance): Promise<void> {
  // 1. POST /v1/rooms - Create a room
  server.post('/v1/rooms', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      const body = request.body as any;
      let maxPlayers = 4;

      if (body !== undefined && body !== null) {
        if (typeof body !== 'object' || Array.isArray(body)) {
          return reply.status(400).send({
            error: 'Bad Request',
            message: 'Request body must be a JSON object.',
          });
        }

        if (body.maxPlayers !== undefined) {
          if (
            typeof body.maxPlayers !== 'number' ||
            !Number.isInteger(body.maxPlayers) ||
            body.maxPlayers < 2 ||
            body.maxPlayers > 4
          ) {
            return reply.status(400).send({
              error: 'Bad Request',
              message: 'maxPlayers must be an integer between 2 and 4.',
            });
          }
          maxPlayers = body.maxPlayers;
        }
      }

      const client = await pool.connect();
      let createdRoomId: string | null = null;

      try {
        for (let attempt = 0; attempt < 10; attempt++) {
          const code = generateRoomCode();
          try {
            await client.query('BEGIN');
            const insertRoomRes = await client.query(
              `INSERT INTO rooms (code, host_user_id, status, max_players)
               VALUES ($1, $2, 'lobby', $3)
               RETURNING id`,
              [code, user.id, maxPlayers]
            );

            createdRoomId = insertRoomRes.rows[0].id;

            await client.query(
              `INSERT INTO room_players (room_id, user_id, is_ready)
               VALUES ($1, $2, false)`,
              [createdRoomId, user.id]
            );

            await client.query('COMMIT');
            break;
          } catch (err: any) {
            await client.query('ROLLBACK');
            if (err.code === '23505' && err.constraint === 'rooms_code_key') {
              // Code collision, retry
              continue;
            }
            throw err;
          }
        }
      } finally {
        client.release();
      }

      if (!createdRoomId) {
        return reply.status(500).send({
          error: 'Internal Server Error',
          message: 'Failed to generate a unique room code. Please try again.',
        });
      }

      const room = await getRoomDetailsById(createdRoomId);
      return reply.status(201).send(room);
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to create room.',
      });
    }
  });

  // 2. POST /v1/rooms/join - Join a room
  server.post('/v1/rooms/join', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      const body = request.body as any;
      if (!body || typeof body !== 'object' || Array.isArray(body)) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Request body must be a JSON object.',
        });
      }

      const { code } = body;
      if (typeof code !== 'string' || !code.trim()) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Room code is required.',
        });
      }

      const normalizedCode = code.trim().toUpperCase();

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        // Row lock on rooms table
        const roomRes = await client.query(
          `SELECT id, code, host_user_id, status, max_players
           FROM rooms
           WHERE UPPER(code) = $1
           FOR UPDATE`,
          [normalizedCode]
        );

        if (roomRes.rows.length === 0) {
          await client.query('ROLLBACK');
          return reply.status(404).send({
            error: 'Not Found',
            message: 'Room not found.',
          });
        }

        const room = roomRes.rows[0];

        // Check if user is already a member
        const memberRes = await client.query(
          `SELECT room_id, user_id FROM room_players WHERE room_id = $1 AND user_id = $2`,
          [room.id, user.id]
        );

        if (memberRes.rows.length > 0) {
          await client.query('COMMIT');
          const roomDetails = await getRoomDetailsById(room.id);
          return reply.status(200).send(roomDetails);
        }

        // Room must be in lobby
        if (room.status !== 'lobby') {
          await client.query('ROLLBACK');
          return reply.status(409).send({
            error: 'Conflict',
            message: `Cannot join room with status '${room.status}'. Only lobby rooms can be joined.`,
          });
        }

        // Check player count
        const countRes = await client.query(
          `SELECT COUNT(*)::int AS count FROM room_players WHERE room_id = $1`,
          [room.id]
        );
        const playerCount = countRes.rows[0].count;

        if (playerCount >= room.max_players) {
          await client.query('ROLLBACK');
          return reply.status(409).send({
            error: 'Conflict',
            message: 'Room is full.',
          });
        }

        // Add player to room
        await client.query(
          `INSERT INTO room_players (room_id, user_id, is_ready)
           VALUES ($1, $2, false)`,
          [room.id, user.id]
        );

        await client.query('COMMIT');

        const roomDetails = await getRoomDetailsById(room.id);
        if (roomDetails) {
          broadcastRoomUpdated(roomDetails.code, roomDetails);
        }
        return reply.status(200).send(roomDetails);
      } catch (err: any) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to join room.',
      });
    }
  });

  // 3. GET /v1/rooms/:code - Room details & players (members only)
  server.get('/v1/rooms/:code', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      const { code } = request.params as any;
      if (typeof code !== 'string' || !code.trim()) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Room code is required.',
        });
      }

      const normalizedCode = code.trim().toUpperCase();

      const roomRes = await pool.query(
        `SELECT id, code, host_user_id, status, max_players, created_at
         FROM rooms
         WHERE UPPER(code) = $1`,
        [normalizedCode]
      );

      if (roomRes.rows.length === 0) {
        return reply.status(404).send({
          error: 'Not Found',
          message: 'Room not found.',
        });
      }

      const room = roomRes.rows[0];

      // Check membership
      const memberRes = await pool.query(
        `SELECT 1 FROM room_players WHERE room_id = $1 AND user_id = $2`,
        [room.id, user.id]
      );

      if (memberRes.rows.length === 0) {
        return reply.status(403).send({
          error: 'Forbidden',
          message: 'Access denied. You are not a member of this room.',
        });
      }

      const roomDetails = await getRoomDetailsById(room.id);
      return reply.status(200).send(roomDetails);
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to retrieve room details.',
      });
    }
  });

  // 4. POST /v1/rooms/:code/ready - Mark ready/not ready (members only)
  server.post('/v1/rooms/:code/ready', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      const { code } = request.params as any;
      if (typeof code !== 'string' || !code.trim()) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Room code is required.',
        });
      }

      const body = request.body as any;
      if (!body || typeof body !== 'object' || Array.isArray(body) || typeof body.ready !== 'boolean') {
        return reply.status(400).send({
          error: 'Bad Request',
          message: "Field 'ready' is required and must be a boolean.",
        });
      }

      const { ready } = body;
      const normalizedCode = code.trim().toUpperCase();

      const roomRes = await pool.query(
        `SELECT id, status FROM rooms WHERE UPPER(code) = $1`,
        [normalizedCode]
      );

      if (roomRes.rows.length === 0) {
        return reply.status(404).send({
          error: 'Not Found',
          message: 'Room not found.',
        });
      }

      const room = roomRes.rows[0];

      // Check membership
      const memberRes = await pool.query(
        `SELECT 1 FROM room_players WHERE room_id = $1 AND user_id = $2`,
        [room.id, user.id]
      );

      if (memberRes.rows.length === 0) {
        return reply.status(403).send({
          error: 'Forbidden',
          message: 'Access denied. You are not a member of this room.',
        });
      }

      if (room.status !== 'lobby') {
        return reply.status(409).send({
          error: 'Conflict',
          message: 'Cannot change ready state after the game has started.',
        });
      }

      await pool.query(
        `UPDATE room_players SET is_ready = $1 WHERE room_id = $2 AND user_id = $3`,
        [ready, room.id, user.id]
      );

      const roomDetails = await getRoomDetailsById(room.id);
      if (roomDetails) {
        broadcastRoomUpdated(roomDetails.code, roomDetails);
      }
      return reply.status(200).send(roomDetails);
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to update ready state.',
      });
    }
  });

  // 5. POST /v1/rooms/:code/leave - Leave room
  server.post('/v1/rooms/:code/leave', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      const { code } = request.params as any;
      if (typeof code !== 'string' || !code.trim()) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Room code is required.',
        });
      }

      const normalizedCode = code.trim().toUpperCase();

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        const roomRes = await client.query(
          `SELECT id, code, host_user_id, status FROM rooms WHERE UPPER(code) = $1 FOR UPDATE`,
          [normalizedCode]
        );

        if (roomRes.rows.length === 0) {
          await client.query('ROLLBACK');
          return reply.status(404).send({
            error: 'Not Found',
            message: 'Room not found.',
          });
        }

        const room = roomRes.rows[0];

        // Check membership
        const memberRes = await client.query(
          `SELECT 1 FROM room_players WHERE room_id = $1 AND user_id = $2`,
          [room.id, user.id]
        );

        if (memberRes.rows.length === 0) {
          await client.query('ROLLBACK');
          return reply.status(403).send({
            error: 'Forbidden',
            message: 'Access denied. You are not a member of this room.',
          });
        }

        // Delete player from room_players
        await client.query(
          `DELETE FROM room_players WHERE room_id = $1 AND user_id = $2`,
          [room.id, user.id]
        );

        // Check remaining players
        const remainingRes = await client.query(
          `SELECT user_id, joined_at FROM room_players WHERE room_id = $1 ORDER BY joined_at ASC`,
          [room.id]
        );

        if (remainingRes.rows.length === 0) {
          // Room became empty, delete room
          await client.query(`DELETE FROM rooms WHERE id = $1`, [room.id]);
          await client.query('COMMIT');
          return reply.status(200).send({
            message: 'Left room successfully. Room was deleted because it became empty.',
            roomDeleted: true,
          });
        }

        // If host left, elect the earliest-joined remaining player as new host
        let newHostAssigned = false;
        if (room.host_user_id === user.id) {
          const newHostId = remainingRes.rows[0].user_id;
          await client.query(
            `UPDATE rooms SET host_user_id = $1 WHERE id = $2`,
            [newHostId, room.id]
          );
          newHostAssigned = true;
        }

        await client.query('COMMIT');

        const updatedRoom = await getRoomDetailsById(room.id);
        if (updatedRoom) {
          broadcastRoomUpdated(updatedRoom.code, updatedRoom);
        }
        return reply.status(200).send({
          message: 'Left room successfully.',
          roomDeleted: false,
          newHostAssigned,
          room: updatedRoom,
        });
      } catch (err: any) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to leave room.',
      });
    }
  });

  // 6. POST /v1/rooms/:code/start - Start game (host only)
  server.post('/v1/rooms/:code/start', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      const { code } = request.params as any;
      if (typeof code !== 'string' || !code.trim()) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Room code is required.',
        });
      }

      const normalizedCode = code.trim().toUpperCase();

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        const roomRes = await client.query(
          `SELECT id, code, host_user_id, status FROM rooms WHERE UPPER(code) = $1 FOR UPDATE`,
          [normalizedCode]
        );

        if (roomRes.rows.length === 0) {
          await client.query('ROLLBACK');
          return reply.status(404).send({
            error: 'Not Found',
            message: 'Room not found.',
          });
        }

        const room = roomRes.rows[0];

        // Check membership
        const memberRes = await client.query(
          `SELECT 1 FROM room_players WHERE room_id = $1 AND user_id = $2`,
          [room.id, user.id]
        );

        if (memberRes.rows.length === 0) {
          await client.query('ROLLBACK');
          return reply.status(403).send({
            error: 'Forbidden',
            message: 'Access denied. You are not a member of this room.',
          });
        }

        // Host only check
        if (room.host_user_id !== user.id) {
          await client.query('ROLLBACK');
          return reply.status(403).send({
            error: 'Forbidden',
            message: 'Only the host can start the game.',
          });
        }

        // Room status must be lobby
        if (room.status !== 'lobby') {
          await client.query('ROLLBACK');
          return reply.status(409).send({
            error: 'Conflict',
            message: `Cannot start room with status '${room.status}'.`,
          });
        }

        // Check players
        const playersRes = await client.query(
          `SELECT user_id, is_ready FROM room_players WHERE room_id = $1`,
          [room.id]
        );

        if (playersRes.rows.length < 2) {
          await client.query('ROLLBACK');
          return reply.status(409).send({
            error: 'Conflict',
            message: 'At least 2 players are required to start the game.',
          });
        }

        const notReady = playersRes.rows.some((p: any) => !p.is_ready);
        if (notReady) {
          await client.query('ROLLBACK');
          return reply.status(409).send({
            error: 'Conflict',
            message: 'All players must be ready to start the game.',
          });
        }

        // Update status to 'playing'
        await client.query(
          `UPDATE rooms SET status = 'playing' WHERE id = $1`,
          [room.id]
        );

        await client.query('COMMIT');

        const updatedRoom = await getRoomDetailsById(room.id);
        if (updatedRoom) {
          broadcastRoomStarted(updatedRoom.code, updatedRoom);
        }
        return reply.status(200).send(updatedRoom);
      } catch (err: any) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to start game.',
      });
    }
  });
}
