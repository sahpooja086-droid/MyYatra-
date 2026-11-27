const [action, applyFlag] = process.argv.slice(2);
const projectId = process.env.MYYATRA_FIREBASE_PROJECT_ID;
const uid = process.env.MYYATRA_ADMIN_UID;

if (!['grant', 'revoke'].includes(action)) {
  console.error('Usage: node set-admin-claim.mjs <grant|revoke> [--apply]');
  process.exitCode = 2;
} else if (!projectId || !uid) {
  console.error(
    'Set MYYATRA_FIREBASE_PROJECT_ID and MYYATRA_ADMIN_UID before continuing.',
  );
  process.exitCode = 2;
} else if (applyFlag !== '--apply') {
  console.log(
    `Dry run only: would ${action} the admin claim for UID ${uid} ` +
      `in project ${projectId}. No account was changed.`,
  );
  console.log('Add --apply only after verifying the project and UID.');
} else {
  try {
    const { applicationDefault, initializeApp } = await import(
      'firebase-admin/app'
    );
    const { getAuth } = await import('firebase-admin/auth');
    const app = initializeApp({
      credential: applicationDefault(),
      projectId,
    });
    const auth = getAuth(app);
    const user = await auth.getUser(uid);
    const claims = { ...user.customClaims };

    if (action === 'grant') {
      claims.admin = true;
    } else {
      delete claims.admin;
    }

    await auth.setCustomUserClaims(uid, claims);
    console.log(`Admin claim ${action}ed for UID ${uid} in ${projectId}.`);
    console.log(
      'The user must refresh their Firebase ID token before the app sees the change.',
    );
  } catch (error) {
    console.error(`Could not ${action} the admin claim:`, error.message);
    process.exitCode = 1;
  }
}
