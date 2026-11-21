# MyYatra admin custom claims

This trusted Node.js Admin SDK utility is intentionally separate from the
Flutter app. It uses the Firebase Auth UID, never an email address, and defaults
to a dry run. It has not been executed and does not assign any claims by itself.

## Safe setup

1. Use a trusted workstation and the project owner's approved Google account.
2. Install Node.js 22 or newer, then run `npm install` in this directory.
3. Authenticate Application Default Credentials using the approved Google Cloud
   account. Do not place service-account keys in this repository or the app.
4. In Firebase Console, copy the intended user's Firebase Auth UID. Verify the
   UID and project independently before applying a change.
5. Set these PowerShell environment variables for the current terminal:

   ```powershell
   $env:MYYATRA_FIREBASE_PROJECT_ID = 'myyatra-e873c'
   $env:MYYATRA_ADMIN_UID = '<verified Firebase Auth UID>'
   ```

6. Preview the operation first (this mode makes no Admin SDK request):

   ```powershell
   node .\set-admin-claim.mjs grant
   # or
   node .\set-admin-claim.mjs revoke
   ```

7. Only after explicit owner approval, rerun with `--apply`:

   ```powershell
   node .\set-admin-claim.mjs grant --apply
   # or
   node .\set-admin-claim.mjs revoke --apply
   ```

The grant/revoke process reads and preserves other existing custom claims. A
claim change appears in the Flutter app after the user's ID token is refreshed
(sign out/in or call the prepared `refreshAdminStatus()` helper). Keep the
Admin SDK environment and IAM access restricted to trusted operators.
