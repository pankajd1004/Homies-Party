import { FastifyRequest, FastifyReply } from 'fastify';
import { firebaseAuth } from './firebase';

export interface FirebaseUserData {
  uid: string;
  email?: string;
}

declare module 'fastify' {
  interface FastifyRequest {
    firebaseUser?: FirebaseUserData;
  }
}

export async function authenticate(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const authHeader = request.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    await reply.status(401).send({
      error: 'Unauthorized',
      message: 'Missing or invalid Authorization header. Format must be Bearer <token>.',
    });
    return;
  }

  const token = authHeader.substring(7).trim();
  if (!token) {
    await reply.status(401).send({
      error: 'Unauthorized',
      message: 'Authentication token is missing.',
    });
    return;
  }

  try {
    const decoded = await firebaseAuth.verifyIdToken(token);
    request.firebaseUser = {
      uid: decoded.uid,
      email: decoded.email,
    };
  } catch (err: any) {
    await reply.status(401).send({
      error: 'Unauthorized',
      message: 'Invalid or expired authentication token.',
    });
    return;
  }
}
