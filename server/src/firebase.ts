import dotenv from 'dotenv';
dotenv.config();

import { initializeApp, getApps, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import path from 'path';
import fs from 'fs';

if (getApps().length === 0) {
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (credPath && !path.isAbsolute(credPath)) {
    const candidateFromCwd = path.resolve(process.cwd(), credPath);
    const candidateFromServerRoot = path.resolve(__dirname, '..', credPath);
    if (fs.existsSync(candidateFromCwd)) {
      process.env.GOOGLE_APPLICATION_CREDENTIALS = candidateFromCwd;
    } else if (fs.existsSync(candidateFromServerRoot)) {
      process.env.GOOGLE_APPLICATION_CREDENTIALS = candidateFromServerRoot;
    }
  }

  initializeApp({
    credential: applicationDefault(),
  });
}

export const firebaseAuth = getAuth();
