import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { deleteApp, initializeApp } from 'firebase/app';
import {
  connectAuthEmulator,
  getAuth,
  getIdTokenResult,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  collection,
  connectFirestoreEmulator,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  onSnapshot,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = process.env.GCLOUD_PROJECT;
const authEmulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const adminEmail = process.env.MYYATRA_EMULATOR_ADMIN_EMAIL;
const adminPassword = process.env.MYYATRA_EMULATOR_ADMIN_PASSWORD;
const userEmail = process.env.MYYATRA_EMULATOR_USER_EMAIL;
const userPassword = process.env.MYYATRA_EMULATOR_USER_PASSWORD;

assert.equal(projectId, 'demo-myyatra');
assert.ok(['127.0.0.1:9099', 'localhost:9099'].includes(authEmulatorHost));
assert.ok(['127.0.0.1:8080', 'localhost:8080'].includes(firestoreEmulatorHost));
assert.ok(adminEmail && adminPassword && userEmail && userPassword);

const app = initializeApp(
  {
    apiKey: 'demo-api-key',
    appId: '1:123456789012:android:0123456789abcdef',
    authDomain: 'demo-myyatra.firebaseapp.com',
    projectId: 'demo-myyatra',
  },
  'myyatra-auth-firestore-integration',
);
const auth = getAuth(app);
connectAuthEmulator(auth, `http://${authEmulatorHost}`, {
  disableWarnings: true,
});
const firestore = getFirestore(app);
connectFirestoreEmulator(
  firestore,
  firestoreEmulatorHost.split(':')[0],
  8080,
);

const districtOptions = [
  { id: 'kaski', name: 'Kaski', province: 'Gandaki' },
  { id: 'manang', name: 'Manang', province: 'Gandaki' },
  { id: 'mustang', name: 'Mustang', province: 'Gandaki' },
  { id: 'dolpa', name: 'Dolpa', province: 'Karnali' },
  { id: 'achham', name: 'Achham', province: 'Sudurpashchim' },
];

let testDistrict;
let testDistrictReference;
let createdByThisTest = false;

before(async () => {
  await signInAsAdmin();
  const claims = await getIdTokenResult(auth.currentUser);
  assert.equal(claims.claims.admin, true);
});

after(async () => {
  if (createdByThisTest && testDistrictReference) {
    try {
      if (auth.currentUser) await signOut(auth);
      await signInAsAdmin();
      await deleteDoc(testDistrictReference);
    } catch (error) {
      console.error('Could not clean up the emulator test district:', error);
    }
  }
  if (auth.currentUser) await signOut(auth);
  await deleteApp(app);
});

test('demo Auth admin can Add/Edit/Delete; non-admin is denied; list refreshes',
  async () => {
    testDistrict = await findAvailableCanonicalDistrict();
    const deniedCreateDistrict = await findAvailableCanonicalDistrict({
      excludingId: testDistrict.id,
    });
    testDistrictReference = doc(firestore, 'districts', testDistrict.id);
    const deniedCreateReference = doc(
      firestore,
      'districts',
      deniedCreateDistrict.id,
    );

    const createdInList = waitForDistrictList((districts) =>
      districts.some((district) => district.id === testDistrict.id),
    );
    await setDoc(testDistrictReference, districtData(testDistrict));
    createdByThisTest = true;
    await createdInList;

    const created = await getDoc(testDistrictReference);
    assert.equal(created.data().name, testDistrict.name);
    assert.equal(created.data().province, testDistrict.province);

    const invalidDistrict = districtData(testDistrict);
    invalidDistrict.description = '  \t  ';
    await assertPermissionDenied(
      setDoc(testDistrictReference, invalidDistrict),
    );

    const duplicateReference = doc(
      firestore,
      'districts',
      `${testDistrict.id}-duplicate`,
    );
    await assertPermissionDenied(
      setDoc(duplicateReference, districtData(testDistrict)),
    );
    assert.equal((await getDoc(duplicateReference)).exists(), false);

    const updatedInList = waitForDistrictList((districts) =>
      districts.some(
        (district) =>
          district.id === testDistrict.id &&
          district.description === 'Updated by emulator admin',
      ),
    );
    await updateDoc(testDistrictReference, {
      description: 'Updated by emulator admin',
      experienceTypes: ['Culture', 'Food'],
      updatedAt: serverTimestamp(),
    });
    await updatedInList;

    await signOut(auth);
    await signInWithEmailAndPassword(auth, userEmail, userPassword);
    const userClaims = await getIdTokenResult(auth.currentUser);
    assert.notEqual(userClaims.claims.admin, true);

    await assertPermissionDenied(
      setDoc(deniedCreateReference, districtData(deniedCreateDistrict)),
    );
    assert.equal((await getDoc(deniedCreateReference)).exists(), false);
    await assertPermissionDenied(
      updateDoc(testDistrictReference, {
        description: 'Unauthorized update',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertPermissionDenied(deleteDoc(testDistrictReference));
    const unchanged = await getDoc(testDistrictReference);
    assert.equal(unchanged.data().description, 'Updated by emulator admin');

    await signOut(auth);
    await assertPermissionDenied(
      setDoc(deniedCreateReference, districtData(deniedCreateDistrict)),
    );
    await assertPermissionDenied(
      updateDoc(testDistrictReference, {
        description: 'Unauthenticated update',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertPermissionDenied(deleteDoc(testDistrictReference));
    assert.equal((await getDoc(testDistrictReference)).exists(), true);

    await signInAsAdmin();
    const deletedFromList = waitForDistrictList((districts) =>
      districts.every((district) => district.id !== testDistrict.id),
    );
    await deleteDoc(testDistrictReference);
    createdByThisTest = false;
    await deletedFromList;
    assert.equal((await getDoc(testDistrictReference)).exists(), false);
  },
);

async function signInAsAdmin() {
  await signInWithEmailAndPassword(auth, adminEmail, adminPassword);
  const claims = await getIdTokenResult(auth.currentUser);
  assert.equal(claims.claims.admin, true);
}

async function findAvailableCanonicalDistrict({ excludingId } = {}) {
  const existing = await getDocs(collection(firestore, 'districts'));
  const existingNames = new Set(
    existing.docs.map((snapshot) =>
      String(snapshot.data().name ?? '').trim().toLowerCase(),
    ),
  );
  const existingIds = new Set(existing.docs.map((snapshot) => snapshot.id));
  const candidate = districtOptions.find(
    ({ id, name }) =>
      id !== excludingId &&
      !existingIds.has(id) && !existingNames.has(name.toLowerCase()),
  );
  if (!candidate) {
    throw new Error(
      'No unused canonical test district is available in demo-myyatra. ' +
        'Clear only the local emulator data, then rerun this test.',
    );
  }
  return candidate;
}

function districtData(district) {
  return {
    name: district.name,
    province: district.province,
    description: `${district.name} local emulator test data`,
    experienceTypes: ['Nature'],
    updatedAt: serverTimestamp(),
  };
}

function assertPermissionDenied(operation) {
  return assert.rejects(operation, (error) => error.code === 'permission-denied');
}

function waitForDistrictList(predicate) {
  return new Promise((resolve, reject) => {
    let unsubscribe = () => {};
    const timeout = setTimeout(() => {
      unsubscribe();
      reject(new Error('Timed out waiting for the district list to refresh.'));
    }, 10000);

    unsubscribe = onSnapshot(
      collection(firestore, 'districts'),
      (snapshot) => {
        const districts = snapshot.docs.map((document) => ({
          id: document.id,
          ...document.data(),
        }));
        if (!predicate(districts)) return;
        clearTimeout(timeout);
        unsubscribe();
        resolve(districts);
      },
      (error) => {
        clearTimeout(timeout);
        unsubscribe();
        reject(error);
      },
    );
  });
}
