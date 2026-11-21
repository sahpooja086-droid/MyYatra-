import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

const rulesPath = fileURLToPath(new URL('../../firestore.rules', import.meta.url));
const projectId = 'demo-myyatra';
let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: process.env.FIRESTORE_EMULATOR_HOST?.split(':')[0] ?? '127.0.0.1',
      port: Number(process.env.FIRESTORE_EMULATOR_HOST?.split(':')[1] ?? 8080),
      rules: readFileSync(rulesPath, 'utf8'),
    },
  });
});

after(async () => {
  await testEnvironment?.cleanup();
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
});

test('unauthenticated users can read public districts', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  const context = testEnvironment.unauthenticatedContext();
  const snapshot = await assertSucceeds(
    getDocs(collection(context.firestore(), 'districts')),
  );
  assert.equal(snapshot.size, 1);
});

test('normal authenticated users can read public districts', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  const context = testEnvironment.authenticatedContext('traveler-uid');
  const snapshot = await assertSucceeds(
    getDocs(collection(context.firestore(), 'districts')),
  );
  assert.equal(snapshot.size, 1);
});

test('admin users can read public districts', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  const context = testEnvironment.authenticatedContext('admin-uid', {
    admin: true,
  });
  const snapshot = await assertSucceeds(
    getDocs(collection(context.firestore(), 'districts')),
  );
  assert.equal(snapshot.size, 1);
});

test('non-admin users cannot create, update, or delete districts', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  const context = testEnvironment.authenticatedContext('traveler-uid');
  const database = context.firestore();

  await assertFails(
    setDoc(doc(database, 'districts', 'kathmandu'),
      districtData('Kathmandu', 'Bagmati')),
  );
  await assertFails(
    updateDoc(doc(database, 'districts', 'kaski'), {
      description: 'Changed by traveler',
      updatedAt: Timestamp.now(),
    }),
  );
  await assertFails(deleteDoc(doc(database, 'districts', 'kaski')));

  const unauthenticated = testEnvironment.unauthenticatedContext().firestore();
  await assertFails(
    setDoc(
      doc(unauthenticated, 'districts', 'kathmandu'),
      districtData('Kathmandu', 'Bagmati'),
    ),
  );
});

test('admin can create, update, and delete a valid district', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  const context = testEnvironment.authenticatedContext('admin-uid', {
    admin: true,
  });
  const database = context.firestore();

  await assertSucceeds(
    setDoc(
      doc(database, 'districts', 'kathmandu'),
      districtData('Kathmandu', 'Bagmati'),
    ),
  );
  await assertSucceeds(
    updateDoc(doc(database, 'districts', 'kaski'), {
      description: 'Updated by admin',
      updatedAt: Timestamp.now(),
    }),
  );
  await assertSucceeds(deleteDoc(doc(database, 'districts', 'kaski')));
});

test('admin can create canonical districts with special stable IDs', async () => {
  const context = testEnvironment.authenticatedContext('admin-uid', {
    admin: true,
  });
  const database = context.firestore();

  await assertSucceeds(
    setDoc(
      doc(database, 'districts', 'nawalparasi-east'),
      districtData('Nawalpur', 'Gandaki'),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(database, 'districts', 'nawalparasi-west'),
      districtData('Parasi', 'Lumbini'),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(database, 'districts', 'rukum-east'),
      districtData('Rukum East', 'Lumbini'),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(database, 'districts', 'rukum-west'),
      districtData('Rukum West', 'Karnali'),
    ),
  );
});

test('admin cannot write invalid district, province, category, or extra fields',
  async () => {
    const context = testEnvironment.authenticatedContext('admin-uid', {
      admin: true,
    });
    const database = context.firestore();

    await assertFails(
      setDoc(
        doc(database, 'districts', 'kaski'),
        districtData('Kaski', 'Bagmati'),
      ),
    );
    await assertFails(
      setDoc(
        doc(database, 'districts', 'unknown-district'),
        districtData('Unknown District', 'Gandaki'),
      ),
    );

    const invalidCategory = districtData('Kaski', 'Gandaki');
    invalidCategory.experienceTypes = ['Nature', 'Other'];
    await assertFails(
      setDoc(doc(database, 'districts', 'kaski'), invalidCategory),
    );

    const extraField = districtData('Kaski', 'Gandaki');
    extraField.internalNote = 'Must not be public';
    await assertFails(setDoc(doc(database, 'districts', 'kaski'), extraField));
  },
);

test('admin cannot create a district with a whitespace-only description',
  async () => {
    const context = testEnvironment.authenticatedContext('admin-uid', {
      admin: true,
    });
    const data = districtData('Kaski', 'Gandaki');
    data.description = '  \t\n  ';

    await assertFails(
      setDoc(doc(context.firestore(), 'districts', 'kaski'), data),
    );
  },
);

test('admin cannot create a district with duplicate experience categories',
  async () => {
    const context = testEnvironment.authenticatedContext('admin-uid', {
      admin: true,
    });
    const data = districtData('Kaski', 'Gandaki');
    data.experienceTypes = ['Nature', 'Nature'];

    await assertFails(
      setDoc(doc(context.firestore(), 'districts', 'kaski'), data),
    );
  },
);

test('admin cannot change a district document to another canonical identity',
  async () => {
    await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
    const context = testEnvironment.authenticatedContext('admin-uid', {
      admin: true,
    });

    await assertFails(
      updateDoc(doc(context.firestore(), 'districts', 'kaski'), {
        name: 'Kathmandu',
        province: 'Bagmati',
        description: 'Reassigned record',
        experienceTypes: ['Culture'],
        updatedAt: Timestamp.now(),
      }),
    );
  },
);

test('admin cannot update a legacy record with a non-canonical document ID',
  async () => {
    // Existing records are never migrated implicitly. Admin updates are
    // blocked until a legacy ID has been reviewed through a separate process.
    await seedDistrict('legacy-kaski-id', districtData('Kaski', 'Gandaki'));
    const context = testEnvironment.authenticatedContext('admin-uid', {
      admin: true,
    });

    await assertFails(
      updateDoc(doc(context.firestore(), 'districts', 'legacy-kaski-id'), {
        description: 'Updated by admin',
        updatedAt: Timestamp.now(),
      }),
    );
  },
);

test('admin cannot delete a legacy record with a non-canonical document ID',
  async () => {
    // Legacy records stay readable and require a separate review process.
    await seedDistrict('legacy-kaski-id', districtData('Kaski', 'Gandaki'));
    const context = testEnvironment.authenticatedContext('admin-uid', {
      admin: true,
    });

    await assertFails(
      deleteDoc(doc(context.firestore(), 'districts', 'legacy-kaski-id')),
    );
  },
);

async function seedDistrict(id, data) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'districts', id), data);
  });
}

function districtData(name, province) {
  return {
    name,
    province,
    description: `${name} travel information`,
    experienceTypes: ['Nature'],
    updatedAt: Timestamp.now(),
  };
}
