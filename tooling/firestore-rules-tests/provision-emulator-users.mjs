import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const projectId = process.env.GCLOUD_PROJECT;
const authEmulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;

if (projectId !== 'demo-myyatra') {
  throw new Error(
    'Refusing to provision users unless GCLOUD_PROJECT is demo-myyatra.',
  );
}
if (!['127.0.0.1:9099', 'localhost:9099'].includes(authEmulatorHost)) {
  throw new Error(
    'Refusing to provision users unless Auth Emulator host is local port 9099.',
  );
}
if (!['127.0.0.1:8080', 'localhost:8080'].includes(firestoreEmulatorHost)) {
  throw new Error(
    'Refusing to provision users unless Firestore Emulator host is local port 8080.',
  );
}

const requiredEnvironment = [
  'MYYATRA_EMULATOR_ADMIN_EMAIL',
  'MYYATRA_EMULATOR_ADMIN_PASSWORD',
  'MYYATRA_EMULATOR_USER_EMAIL',
  'MYYATRA_EMULATOR_USER_PASSWORD',
];
for (const name of requiredEnvironment) {
  if (!process.env[name]) throw new Error(`Set ${name} for local test users.`);
}

if (getApps().length > 0) {
  throw new Error('Start this provisioning script in a fresh Node process.');
}

const app = initializeApp({ projectId: 'demo-myyatra' });
const auth = getAuth(app);

async function ensureEmulatorUser(email, password, isAdministrator) {
  let user;
  try {
    user = await auth.getUserByEmail(email);
    user = await auth.updateUser(user.uid, { password, disabled: false });
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    user = await auth.createUser({ email, password, emailVerified: true });
  }

  await auth.setCustomUserClaims(
    user.uid,
    isAdministrator ? { admin: true } : {},
  );
  console.log(
    `${isAdministrator ? 'Admin' : 'Non-admin'} test user ready in ` +
      `demo-myyatra Auth Emulator: ${email}`,
  );
}

await ensureEmulatorUser(
  process.env.MYYATRA_EMULATOR_ADMIN_EMAIL,
  process.env.MYYATRA_EMULATOR_ADMIN_PASSWORD,
  true,
);
await ensureEmulatorUser(
  process.env.MYYATRA_EMULATOR_USER_EMAIL,
  process.env.MYYATRA_EMULATOR_USER_PASSWORD,
  false,
);

await app.delete();
