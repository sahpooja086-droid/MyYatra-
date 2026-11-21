# Firestore rules tests (local emulator only)

These tests load the repository's `firestore.rules` into the Firestore Emulator
and use simulated unauthenticated, normal-user, and `admin: true` identities.
They do not connect to the production Firestore project and do not change rules
or account claims.

From this directory, install the test-only packages:

```powershell
npm install
```

Then run the suite under the Firestore Emulator:

```powershell
npx firebase-tools emulators:exec --config ..\..\firebase.json --only firestore --project demo-myyatra "npm test"
```

The tests cover public reads, authenticated reads, admin reads, non-admin and
unauthenticated write denial, admin create/update/delete with persisted-result
checks, canonical district/province validation, duplicate canonical names,
required and bounded descriptions, experience category validation, unknown
fields, district identity changes, and legacy/malformed delete protection.

The CLI project ID is a `demo-` ID and the emulator is local. Do not replace it
with the production project ID when running rules tests.
