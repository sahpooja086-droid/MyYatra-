import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { deleteApp as deleteAdminApp, initializeApp as initializeAdminApp } from 'firebase-admin/app';
import { getAuth as getAdminAuth } from 'firebase-admin/auth';
import { deleteApp, initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import {
  collection, connectFirestoreEmulator, deleteDoc, deleteField, doc, getDoc,
  getFirestore, onSnapshot, serverTimestamp, setDoc, updateDoc, writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-myyatra-place-crud-qa';
assert.equal(process.env.GCLOUD_PROJECT, projectId);
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:19099');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:18082');

test('isolated demo Auth and Firestore exercise Place CRUD and district protection', async () => {
  const adminApp = initializeAdminApp({ projectId });
  const apps = [];
  try {
    async function signIn(isAdmin) {
      const email = `${randomUUID()}@myyatra.test`;
      const password = randomUUID();
      const provisioner = getAdminAuth(adminApp);
      const user = await provisioner.createUser({ email, password });
      if (isAdmin) await provisioner.setCustomUserClaims(user.uid, { admin: true });
      const app = initializeApp({ projectId, apiKey: 'demo-api-key' }, user.uid);
      apps.push(app);
      const auth = getAuth(app);
      connectAuthEmulator(auth, 'http://127.0.0.1:19099', { disableWarnings: true });
      const credential = await signInWithEmailAndPassword(auth, email, password);
      assert.equal((await credential.user.getIdTokenResult()).claims.admin === true, isAdmin);
      const firestore = getFirestore(app);
      connectFirestoreEmulator(firestore, '127.0.0.1', 18082);
      return firestore;
    }

    const admin = await signIn(true);
    const traveler = await signIn(false);
    const district = doc(admin, 'districts', 'kaski');
    const place = doc(admin, 'places', 'kaski--qa-viewpoint');
    const placeData = {
      name: 'QA Viewpoint', districtId: 'kaski', category: 'Viewpoint',
      description: 'Initial description', imageUrl: 'https://example.com/view.jpg',
      updatedAt: serverTimestamp(),
    };
    assert.equal((await getDoc(doc(admin, 'internal', 'placeReferenceIndex'))).data()?.initialized, true);
    assert.equal((await getDoc(district)).exists(), false, 'Expected a fresh isolated emulator');
    await setDoc(district, {
      name: 'Kaski', province: 'Gandaki', description: 'QA district',
      experienceTypes: ['Nature'], updatedAt: serverTimestamp(),
    });

    const nonAdminAdd = writeBatch(traveler);
    nonAdminAdd.set(doc(traveler, place.path), placeData);
    nonAdminAdd.set(doc(traveler, 'districtPlaceCounts', 'kaski'), {count: 1, placeId: place.id});
    await assert.rejects(nonAdminAdd.commit(), { code: 'permission-denied' });

    const added = waitForPlaces(admin, (docs) => docs.some((d) => d.id === place.id));
    const add = writeBatch(admin);
    add.set(place, placeData);
    add.set(doc(admin, 'districtPlaceCounts', 'kaski'), {count: 1, placeId: place.id});
    await add.commit();
    await added;

    await assert.rejects(deleteDoc(district), { code: 'permission-denied' });
    await assert.rejects(updateDoc(doc(traveler, place.path), { description: 'Unauthorized' }), { code: 'permission-denied' });
    const nonAdminDelete = writeBatch(traveler);
    nonAdminDelete.delete(doc(traveler, place.path));
    nonAdminDelete.set(doc(traveler, 'districtPlaceCounts', 'kaski'), {count: 0, placeId: place.id});
    await assert.rejects(nonAdminDelete.commit(), { code: 'permission-denied' });

    const edited = waitForPlaces(admin, (docs) => docs.some((d) => d.data().description === 'Edited description'));
    await updateDoc(place, { description: 'Edited description', imageUrl: deleteField(), updatedAt: serverTimestamp() });
    await edited;
    assert.equal(Object.hasOwn((await getDoc(place)).data(), 'imageUrl'), false);

    const deleted = waitForPlaces(admin, (docs) => docs.length === 0);
    const remove = writeBatch(admin);
    remove.delete(place);
    remove.set(doc(admin, 'districtPlaceCounts', 'kaski'), {count: 0, placeId: place.id});
    await remove.commit();
    await deleted;
    await deleteDoc(district);
    assert.equal((await getDoc(district)).exists(), false);
  } finally {
    await Promise.all(apps.map(deleteApp));
    await deleteAdminApp(adminApp);
  }
});

function waitForPlaces(firestore, matches) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => finish(new Error('Timed out waiting for Places')), 8000);
    const stop = onSnapshot(collection(firestore, 'places'), { includeMetadataChanges: true }, (snapshot) => {
      if (!snapshot.metadata.fromCache && !snapshot.metadata.hasPendingWrites && matches(snapshot.docs)) finish();
    }, finish);
    function finish(error) {
      clearTimeout(timer);
      stop();
      if (error) reject(error);
      else resolve();
    }
  });
}
