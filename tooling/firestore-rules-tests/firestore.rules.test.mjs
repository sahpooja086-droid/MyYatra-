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
  deleteField,
  doc,
  getDoc,
  getDocs,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const rulesPath = fileURLToPath(new URL('../../firestore.rules', import.meta.url));
const projectId =
  process.env.MYYATRA_RULES_TEST_PROJECT_ID ?? 'demo-myyatra';
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
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'internal', 'placeReferenceIndex'), {
      initialized: true,
    });
  });
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
  await assertFails(
    updateDoc(doc(unauthenticated, 'districts', 'kaski'), {
      description: 'Changed without authentication',
      updatedAt: Timestamp.now(),
    }),
  );
  await assertFails(deleteDoc(doc(unauthenticated, 'districts', 'kaski')));
});

test('admin can create, update, and delete a valid district', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  const context = testEnvironment.authenticatedContext('admin-uid', {
    admin: true,
  });
  const database = context.firestore();

  const kathmanduReference = doc(database, 'districts', 'kathmandu');
  await assertSucceeds(
    setDoc(kathmanduReference, districtData('Kathmandu', 'Bagmati')),
  );
  const created = await assertSucceeds(getDoc(kathmanduReference));
  assert.equal(created.data().name, 'Kathmandu');
  assert.equal(created.data().province, 'Bagmati');

  await assertSucceeds(
    updateDoc(doc(database, 'districts', 'kaski'), {
      description: 'Updated by admin',
      updatedAt: Timestamp.now(),
    }),
  );
  const updated = await assertSucceeds(
    getDoc(doc(database, 'districts', 'kaski')),
  );
  assert.equal(updated.data().description, 'Updated by admin');

  const kaskiReference = doc(database, 'districts', 'kaski');
  await assertSucceeds(deleteDoc(kaskiReference));
  const deleted = await assertSucceeds(getDoc(kaskiReference));
  assert.equal(deleted.exists(), false);
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

test('admin cannot create a second document for a canonical district name',
  async () => {
    const context = testEnvironment.authenticatedContext('admin-uid', {
      admin: true,
    });
    const database = context.firestore();
    await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));

    await assertFails(
      setDoc(
        doc(database, 'districts', 'another-kaski'),
        districtData('Kaski', 'Gandaki'),
      ),
    );
  },
);

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

test('admin cannot create districts missing required data or exceeding limits',
  async () => {
    const context = testEnvironment.authenticatedContext('admin-uid', {
      admin: true,
    });
    const database = context.firestore();
    const missingDescription = districtData('Kaski', 'Gandaki');
    delete missingDescription.description;

    await assertFails(
      setDoc(doc(database, 'districts', 'kaski'), missingDescription),
    );

    const tooLongDescription = districtData('Kaski', 'Gandaki');
    tooLongDescription.description = 'x'.repeat(2001);
    await assertFails(
      setDoc(doc(database, 'districts', 'kaski'), tooLongDescription),
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

test('admin cannot delete a malformed record at a canonical document ID',
  async () => {
    const malformed = districtData('Kaski', 'Gandaki');
    malformed.description = '   ';
    await seedDistrict('kaski', malformed);
    const context = testEnvironment.authenticatedContext('admin-uid', {
      admin: true,
    });

    await assertFails(
      deleteDoc(doc(context.firestore(), 'districts', 'kaski')),
    );
  },
);

test('unauthenticated users can read public places', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  await seedPlace(
    'kaski--sarangkot',
    placeData('Sarangkot', 'Viewpoint', 'kaski'),
  );
  const context = testEnvironment.unauthenticatedContext();
  const snapshot = await assertSucceeds(
    getDocs(collection(context.firestore(), 'places')),
  );
  assert.equal(snapshot.size, 1);
});

test('admin can create, update, and delete a canonical place', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  const context = testEnvironment.authenticatedContext('admin-uid', {
    admin: true,
  });
  const database = context.firestore();
  const placeReference = doc(database, 'places', 'kaski--sarangkot');

  await assertSucceeds(
    createPlace(placeReference, placeData('Sarangkot', 'Viewpoint', 'kaski')),
  );
  const created = await assertSucceeds(getDoc(placeReference));
  assert.equal(created.data().districtId, 'kaski');
  assert.equal(created.data().category, 'Viewpoint');

  await assertSucceeds(
    updateDoc(placeReference, {
      category: 'Viewpoint and hiking',
      description: 'Updated place details',
      imageUrl: 'https://example.com/sarangkot.jpg',
      updatedAt: Timestamp.now(),
    }),
  );
  const updated = await assertSucceeds(getDoc(placeReference));
  assert.equal(updated.data().category, 'Viewpoint and hiking');
  assert.equal(updated.data().imageUrl, 'https://example.com/sarangkot.jpg');

  await assertSucceeds(updateDoc(placeReference, { imageUrl: deleteField() }));
  const cleared = await assertSucceeds(getDoc(placeReference));
  assert.equal(Object.hasOwn(cleared.data(), 'imageUrl'), false);
  assert.equal(cleared.data().category, 'Viewpoint and hiking');

  const removal = writeBatch(database);
  removal.delete(placeReference);
  removal.set(doc(database, 'districtPlaceCounts', 'kaski'), {
    count: 0, placeId: placeReference.id,
  });
  await assertSucceeds(removal.commit());
  const deleted = await assertSucceeds(getDoc(placeReference));
  assert.equal(deleted.exists(), false);
});

test('normal authenticated and unauthenticated users cannot mutate places',
  async () => {
    await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
    await seedPlace(
      'kaski--sarangkot',
      placeData('Sarangkot', 'Viewpoint', 'kaski'),
    );
    const normalDatabase = testEnvironment
      .authenticatedContext('traveler-uid')
      .firestore();
    const signedOutDatabase = testEnvironment.unauthenticatedContext().firestore();

    for (const database of [normalDatabase, signedOutDatabase]) {
      await assertFails(
        createPlace(
          doc(database, 'places', 'kaski--devis-falls'),
          placeData('Devis Falls', 'Waterfall', 'kaski'),
          2,
        ),
      );
      await assertFails(
        updateDoc(doc(database, 'places', 'kaski--sarangkot'), {
          description: 'Unauthorized change',
          updatedAt: Timestamp.now(),
        }),
      );
      await assertFails(deleteDoc(doc(database, 'places', 'kaski--sarangkot')));
    }
  },
);

test('admin place writes reject invalid IDs, fields, URLs, and districts',
  async () => {
    await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
    const database = testEnvironment
      .authenticatedContext('admin-uid', { admin: true })
      .firestore();

    await assertFails(
      createPlace(
        doc(database, 'places', 'wrong-place-id'),
        placeData('Sarangkot', 'Viewpoint', 'kaski'),
      ),
    );

    const whitespaceCategory = placeData('Sarangkot', 'Viewpoint', 'kaski');
    whitespaceCategory.category = '   ';
    await assertFails(
      createPlace(doc(database, 'places', 'kaski--sarangkot'), whitespaceCategory),
    );

    const whitespaceDescription = placeData('Sarangkot', 'Viewpoint', 'kaski');
    whitespaceDescription.description = '   ';
    await assertFails(
      createPlace(
        doc(database, 'places', 'kaski--sarangkot'),
        whitespaceDescription,
      ),
    );

    const insecureImage = placeData('Sarangkot', 'Viewpoint', 'kaski');
    insecureImage.imageUrl = 'http://example.com/image.jpg';
    await assertFails(
      createPlace(doc(database, 'places', 'kaski--sarangkot'), insecureImage),
    );

    const extraField = placeData('Sarangkot', 'Viewpoint', 'kaski');
    extraField.privateNote = 'must not be public';
    await assertFails(
      createPlace(doc(database, 'places', 'kaski--sarangkot'), extraField),
    );

    await assertFails(
      createPlace(
        doc(database, 'places', 'missing-district--some-place'),
        placeData('Some Place', 'Museum', 'missing-district'),
      ),
    );
  },
);

test('admin cannot associate a place with a legacy district document ID',
  async () => {
    await seedDistrict(
      'legacy-kaski',
      districtData('Kaski', 'Gandaki'),
    );
    const database = testEnvironment
      .authenticatedContext('admin-uid', { admin: true })
      .firestore();

    await assertFails(
      createPlace(
        doc(database, 'places', 'legacy-kaski--sarangkot'),
        placeData('Sarangkot', 'Viewpoint', 'legacy-kaski'),
      ),
    );
  },
);

test('admin cannot change a place name or district after creation', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  await seedDistrict('kathmandu', districtData('Kathmandu', 'Bagmati'));
  await seedPlace(
    'kaski--sarangkot',
    placeData('Sarangkot', 'Viewpoint', 'kaski'),
  );
  const database = testEnvironment
    .authenticatedContext('admin-uid', { admin: true })
    .firestore();

  await assertFails(
    updateDoc(doc(database, 'places', 'kaski--sarangkot'), {
      name: 'Renamed viewpoint',
      updatedAt: Timestamp.now(),
    }),
  );
  await assertFails(
    updateDoc(doc(database, 'places', 'kaski--sarangkot'), {
      districtId: 'kathmandu',
      updatedAt: Timestamp.now(),
    }),
  );
});

test('a district cannot be deleted until its final place is removed', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  const database = testEnvironment
    .authenticatedContext('admin-uid', { admin: true }).firestore();
  const district = doc(database, 'districts', 'kaski');
  const count = doc(database, 'districtPlaceCounts', 'kaski');
  const first = doc(database, 'places', 'kaski--sarangkot');
  const second = doc(database, 'places', 'kaski--devis-falls');
  await assertSucceeds(createPlace(first, placeData('Sarangkot', 'Viewpoint', 'kaski')));
  await assertSucceeds(createPlace(second, placeData('Devis Falls', 'Waterfall', 'kaski'), 2));

  await assertFails(deleteDoc(district));
  await assertFails(setDoc(count, { count: 0, placeId: first.id }));
  await assertFails(deleteDoc(count));
  await assertFails(deleteDoc(first));
  const forgedRemoval = writeBatch(database);
  forgedRemoval.delete(first);
  forgedRemoval.set(count, { count: 0, placeId: first.id });
  await assertFails(forgedRemoval.commit());

  for (const [reference, remaining] of [[first, 1], [second, 0]]) {
    await assertFails(deleteDoc(district));
    const removal = writeBatch(database);
    removal.delete(reference);
    removal.set(count, { count: remaining, placeId: reference.id });
    await assertSucceeds(removal.commit());
  }
  await assertSucceeds(deleteDoc(district));
  assert.equal((await getDoc(district)).exists(), false);
});

test('place count rules reject untracked and conflicting batched creates', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  const database = testEnvironment
    .authenticatedContext('admin-uid', { admin: true }).firestore();
  const district = doc(database, 'districts', 'kaski');
  const count = doc(database, 'districtPlaceCounts', 'kaski');
  const first = doc(database, 'places', 'kaski--sarangkot');
  const second = doc(database, 'places', 'kaski--devis-falls');
  const sarangkot = placeData('Sarangkot', 'Viewpoint', 'kaski');
  await assertFails(setDoc(first, sarangkot));
  for (const competingWrite of [
    (batch) => batch.delete(district),
    (batch) => batch.set(second, placeData('Devis Falls', 'Waterfall', 'kaski')),
  ]) {
    const batch = writeBatch(database);
    batch.set(first, sarangkot);
    batch.set(count, { count: 1, placeId: first.id });
    competingWrite(batch);
    await assertFails(batch.commit());
  }
  assert.equal((await getDoc(district)).exists(), true);
  assert.equal((await getDoc(first)).exists(), false);
  assert.equal((await getDoc(second)).exists(), false);
});

test('an uninitialized reference index blocks deletion of pre-existing districts', async () => {
  await seedDistrict('kaski', districtData('Kaski', 'Gandaki'));
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    await deleteDoc(doc(database, 'internal', 'placeReferenceIndex'));
    await setDoc(doc(database, 'places', 'legacy-place'), placeData('Old place', 'Viewpoint', 'kaski'));
  });
  const database = testEnvironment
    .authenticatedContext('admin-uid', { admin: true }).firestore();
  const district = doc(database, 'districts', 'kaski');
  await assertSucceeds(updateDoc(district, { description: 'Still editable' }));
  await assertFails(setDoc(doc(database, 'internal', 'placeReferenceIndex'), { initialized: true }));
  await assertFails(deleteDoc(district));
});

async function seedDistrict(id, data) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'districts', id), data);
  });
}

async function seedPlace(id, data) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    const counter = await getDoc(doc(database, 'districtPlaceCounts', data.districtId));
    await createPlace(doc(database, 'places', id), data, (counter.data()?.count ?? 0) + 1);
  });
}

function createPlace(reference, data, count = 1) {
  const database = reference.firestore;
  const batch = writeBatch(database);
  batch.set(reference, data);
  batch.set(doc(database, 'districtPlaceCounts', data.districtId), {
    count, placeId: reference.id,
  });
  return batch.commit();
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

function placeData(name, category, districtId) {
  return {
    name,
    category,
    districtId,
    description: `${name} travel information`,
    updatedAt: Timestamp.now(),
  };
}
