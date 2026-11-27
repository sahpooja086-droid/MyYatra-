import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const projectId = process.env.GCLOUD_PROJECT;
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!/^demo-myyatra(?:-[a-z0-9-]+)?$/.test(projectId ?? '') ||
    !/^(?:127\.0\.0\.1|localhost):[0-9]{1,5}$/.test(host ?? '')) {
  throw new Error('Use a demo-myyatra project and a local Firestore Emulator.');
}

const app = initializeApp({ projectId });
const firestore = getFirestore(app);
const ready = firestore.doc('internal/placeReferenceIndex');
const counts = firestore.collection('districtPlaceCounts');
try {
  const initialized = await firestore.runTransaction(async (transaction) => {
    if ((await transaction.get(ready)).exists) return false;
    if (!(await transaction.get(counts.limit(1))).empty) {
      throw new Error('Existing counts require review before initialization.');
    }

    const places = await transaction.get(firestore.collection('places'));
    const totals = new Map();
    for (const place of places.docs) {
      const districtId = place.get('districtId');
      // Only lowercase canonical district IDs can be deleted under the rules.
      if (typeof districtId !== 'string' || !/^[a-z]+(?:-[a-z]+)*$/.test(districtId)) {
        continue;
      }
      totals.set(districtId, (totals.get(districtId) ?? 0) + 1);
    }

    for (const [districtId, count] of totals) {
      transaction.create(counts.doc(districtId), { count });
    }
    transaction.create(ready, { initialized: true });
    return true;
  });
  console.log(initialized ? 'Place reference index initialized.' : 'Place reference index is already initialized.');
} finally {
  await firestore.terminate();
  await deleteApp(app);
}
