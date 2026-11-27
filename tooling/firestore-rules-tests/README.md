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
They also cover public place reads, admin place CRUD, unauthorized place
mutations, canonical place IDs, canonical district references, required place
fields, optional HTTPS image URLs, prohibited extra fields, and immutable place
identity.

Place documents use `places/{districtId}--{normalized-place-name}` IDs and the
fields `name`, `category`, `districtId`, `description`, `updatedAt`, and
optional `imageUrl`. Name/category/description limits are validated in Flutter
and in rules. Place rules verify that the referenced district document itself
has canonical ID, name, and province data. The category is free text because
the repository contains no approved place-category list. The Flutter Manage
Places list uses the named demo Firestore instance when debug emulator mode is
enabled and its local Firestore endpoint is verified. Manage Places uses local
preview data outside that mode. Add, Edit, and Delete require a separate debug
opt-in, matching loaded rules, an initialized index, and administrator access.

### District deletion and Place references

District deletion requires an initialized reference index and a zero Place
count for the district. Rules enforce that each Place creation or deletion
changes the count atomically for that specific Place. A Place update keeps its
district identity and can remove the optional `imageUrl` field.

On a fresh, isolated demo emulator running the current rules, initialize the
index before exercising District Delete. The same initializer can account for
pre-existing Places in an isolated copy, including references to IDs whose
district records are missing. Run it before other privileged data writers.
It records counts and a readiness marker in one transaction and leaves Place
and district records intact. Until initialization, district deletion is blocked
and district creation, editing, and listing still work.

```powershell
$env:GCLOUD_PROJECT = 'demo-myyatra'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
npm --prefix tooling/firestore-rules-tests run setup:place-index
```

The CLI project ID is a `demo-` ID and the emulator is local. Do not replace it
with the production project ID when running rules tests.

## Full demo Auth + Firestore Emulator CRUD

The app's emulator mode initializes a separately named Firebase app with the
`demo-myyatra` project options, probes both local emulator ports, and configures
Auth and Firestore emulators before rendering the app. Login, token checks,
district reads, and mutations all use that named app. Android's default app
from `google-services.json` is not used by the emulator path. The default
runtime remains preview-only.

Install the test packages once (Node.js 22 or newer is required by
`firebase-admin`; Firebase CLI also requires JDK 21 or newer):

```powershell
npm install --prefix tooling/firestore-rules-tests
```

If `java` is not already on PATH, use Android Studio's bundled JDK in each
PowerShell session that runs Firebase CLI:

```powershell
$javaHome = 'C:\Program Files\Android\Android Studio1\jbr'
$env:JAVA_HOME = $javaHome
$env:PATH = "$javaHome\bin;$env:PATH"
```

### Automated emulator acceptance

From the project root, set local-only test credentials and run both test
suites inside the demo emulators:

```powershell
$env:MYYATRA_EMULATOR_ADMIN_EMAIL = 'district-admin@myyatra.test'
$env:MYYATRA_EMULATOR_ADMIN_PASSWORD = 'LocalOnly-Admin-123!'
$env:MYYATRA_EMULATOR_USER_EMAIL = 'district-user@myyatra.test'
$env:MYYATRA_EMULATOR_USER_PASSWORD = 'LocalOnly-User-123!'
firebase emulators:exec --project demo-myyatra --only auth,firestore "npm --prefix tooling/firestore-rules-tests run test:all"
```

The setup script refuses to run unless Firebase CLI sets
`GCLOUD_PROJECT=demo-myyatra`, Auth is at `127.0.0.1:9099` or `localhost:9099`,
and Firestore is at `127.0.0.1:8080` or `localhost:8080`. It creates or updates
only these local emulator users, sets `admin: true` only on the local admin,
and clears custom claims from the local non-admin. It does not use Application
Default Credentials or a service-account key.

The Auth + Firestore integration test signs in both emulator users, verifies
the admin claim from the issued emulator token, exercises Add/Edit/Delete,
checks live list snapshots, rejects invalid and duplicate district data, and
confirms non-admin and signed-out writes are denied. It does not access
production Firebase.

### Manual MyYatra Android Emulator CRUD

Start both local emulators and keep this terminal open:

```powershell
firebase emulators:start --project demo-myyatra --only auth,firestore
```

In a second PowerShell terminal, provision the two emulator-only users:

```powershell
$env:GCLOUD_PROJECT = 'demo-myyatra'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:MYYATRA_EMULATOR_ADMIN_EMAIL = 'district-admin@myyatra.test'
$env:MYYATRA_EMULATOR_ADMIN_PASSWORD = 'LocalOnly-Admin-123!'
$env:MYYATRA_EMULATOR_USER_EMAIL = 'district-user@myyatra.test'
$env:MYYATRA_EMULATOR_USER_PASSWORD = 'LocalOnly-User-123!'
npm --prefix tooling/firestore-rules-tests run setup:auth-emulator
npm --prefix tooling/firestore-rules-tests run setup:place-index
```

Then launch the Android Emulator build from another terminal:

```powershell
flutter run --dart-define=MYYATRA_ENABLE_EMULATOR_DISTRICT_CRUD=true --dart-define=MYYATRA_FIRESTORE_EMULATOR_HOST=10.0.2.2
```

Sign in as `district-admin@myyatra.test` to add a valid district, edit its
description, and delete it after confirming. Verify each operation appears in
the district list. Try a blank description, an existing district, and the
non-admin test account to verify errors and authorization. The Android
Emulator uses `10.0.2.2` to reach the host ports. If either emulator is
unavailable or the project ID differs, startup fails before the app is shown;
there is no production fallback.

Do not use these test credentials outside the demo emulators. Without the
debug `--dart-define`, Add/Edit/Delete remain local-preview-only. Release and
profile builds reject emulator CRUD mode.

### Manual Place CRUD in the demo emulator

After the reference index has been initialized on the approved demo instance,
append `--dart-define=MYYATRA_ENABLE_EMULATOR_PLACE_CRUD=true` to the debug
launch command above. Sign in as the local administrator. Add a Place, edit
its description and clear its image URL, and verify the live list reflects the
changes. Confirm the referenced district cannot be deleted while the Place
exists, then delete the Place and verify that the district can be deleted.

If rules or the index cannot be verified, Manage Places offers previews.
Restart the app after initializing the index so the administrator check can
enable the write controls.

The automated Place Auth + Firestore test requires a fresh isolated project
`demo-myyatra-place-crud-qa` with Auth on `127.0.0.1:19099` and Firestore on
`127.0.0.1:18082`. Set `GCLOUD_PROJECT`, `FIREBASE_AUTH_EMULATOR_HOST`, and
`FIRESTORE_EMULATOR_HOST` to those values, initialize its index using
`setup:place-index`, then run `node --test --test-isolation=none
tooling/firestore-rules-tests/place-auth-firestore.integration.test.mjs` from
the project root.
