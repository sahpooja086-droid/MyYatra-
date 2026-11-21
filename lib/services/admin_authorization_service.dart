import 'package:firebase_auth/firebase_auth.dart';

/// Reads the server-issued Firebase Authentication `admin` custom claim.
/// This helper never grants claims or infers admin status from email/login.
class AdminAuthorizationService {
  AdminAuthorizationService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final tokenResult = await user.getIdTokenResult(forceRefresh);
    return tokenResult.claims?['admin'] == true;
  }

  /// Refreshes the ID token so newly granted or revoked claims are rechecked.
  Future<bool> refreshAdminStatus() {
    return isCurrentUserAdmin(forceRefresh: true);
  }
}
