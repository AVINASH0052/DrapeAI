import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
};

export function isFirebaseConfigured() {
  return Boolean(
    firebaseConfig.apiKey &&
      firebaseConfig.authDomain &&
      firebaseConfig.projectId &&
      firebaseConfig.appId,
  );
}

let auth = null;

function getFirebaseAuth() {
  if (!isFirebaseConfigured()) {
    throw new Error('Firebase is not configured for the admin console');
  }
  if (!auth) {
    const app = initializeApp(firebaseConfig);
    auth = getAuth(app);
  }
  return auth;
}

export async function signInAdmin(email, password) {
  const credential = await signInWithEmailAndPassword(getFirebaseAuth(), email, password);
  return credential.user.getIdToken();
}
