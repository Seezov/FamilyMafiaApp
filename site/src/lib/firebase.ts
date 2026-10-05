// One Firebase app per page for /host/ and /account/. Access control lives in firestore.rules.
import { initializeApp } from 'firebase/app';
import { GoogleAuthProvider, getAuth, signInWithPopup, signInWithRedirect, signOut } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { firebaseConfig } from './hosting/firebase-config';

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

export async function signIn() {
  const provider = new GoogleAuthProvider();
  try {
    await signInWithPopup(auth, provider);
  } catch (e) {
    if ((e as { code?: string }).code === 'auth/popup-blocked') await signInWithRedirect(auth, provider);
    else throw e;
  }
}

export const signOutUser = () => signOut(auth);
