import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/district_model.dart';
import 'screens/admin/district_management_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/admin_authorization_service.dart';
import 'services/district_mutation_service.dart';
import 'services/district_service.dart';

const bool _enableEmulatorDistrictCrud = bool.fromEnvironment(
  'MYYATRA_ENABLE_EMULATOR_DISTRICT_CRUD',
  defaultValue: false,
);
const String _firestoreEmulatorHost = String.fromEnvironment(
  'MYYATRA_FIRESTORE_EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);
const String _emulatorProjectId = 'demo-myyatra';
const FirebaseOptions _emulatorFirebaseOptions = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:123456789012:android:0123456789abcdef',
  messagingSenderId: '123456789012',
  projectId: _emulatorProjectId,
);

Future<void> main() async {
  if (_enableEmulatorDistrictCrud && !kDebugMode) {
    throw StateError(
      'Emulator district CRUD is available only in debug builds.',
    );
  }
  if (_enableEmulatorDistrictCrud &&
      !const {
        '10.0.2.2',
        '127.0.0.1',
        'localhost',
        '::1',
      }.contains(_firestoreEmulatorHost)) {
    throw StateError(
      'District CRUD may connect only to a local Firestore Emulator host.',
    );
  }

  WidgetsFlutterBinding.ensureInitialized();

  if (_enableEmulatorDistrictCrud) {
    await _verifyEmulatorsReachable();
  }

  FirebaseAuth? firebaseAuth;
  DistrictService? districtService;
  DistrictMutationService? districtMutationService;
  if (_enableEmulatorDistrictCrud) {
    final firebaseApp = await Firebase.initializeApp(
      name: 'myyatra-demo-emulator',
      options: _emulatorFirebaseOptions,
    );
    if (firebaseApp.options.projectId != _emulatorProjectId) {
      throw StateError('Emulator mode must use project $_emulatorProjectId.');
    }

    final auth = FirebaseAuth.instanceFor(app: firebaseApp);
    await auth.useAuthEmulator(_firestoreEmulatorHost, 9099);
    firebaseAuth = auth;

    final firestore = FirebaseFirestore.instanceFor(app: firebaseApp);
    firestore.useFirestoreEmulator(_firestoreEmulatorHost, 8080);
    districtService = DistrictService(
      repository: FirestoreDistrictRepository(firestore: firestore),
    );
    districtMutationService = districtService;
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(
    MyApp(
      firebaseAuth: firebaseAuth,
      districtsStreamFactory: districtService?.getDistricts,
      districtMutationService: districtMutationService,
    ),
  );
}

Future<void> _verifyEmulatorsReachable() async {
  for (final port in [9099, 8080]) {
    Socket? socket;
    try {
      socket = await Socket.connect(
        _firestoreEmulatorHost,
        port,
        timeout: const Duration(seconds: 3),
      );
    } on SocketException catch (error) {
      throw StateError(
        'The demo Firebase Emulator on port $port is unavailable. Start '
        'both Auth and Firestore emulators before launching emulator mode. '
        'Details: $error',
      );
    } on TimeoutException catch (error) {
      throw StateError(
        'Timed out checking the demo Firebase Emulator on port $port. '
        'No production fallback is available. Details: $error',
      );
    } finally {
      socket?.destroy();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.firebaseAuth,
    this.districtsStreamFactory,
    this.districtMutationService,
  });

  final FirebaseAuth? firebaseAuth;
  final Stream<List<DistrictModel>> Function()? districtsStreamFactory;
  final DistrictMutationService? districtMutationService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyYatra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8E2442)),
        useMaterial3: true,
      ),
      home: AuthGate(
        firebaseAuth: firebaseAuth,
        districtsStreamFactory: districtsStreamFactory,
        districtMutationService: districtMutationService,
      ),
    );
  }
}

enum _AuthGateView {
  checking,
  checkingAuthorization,
  signedOut,
  administrator,
  nonAdministrator,
  error,
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.signedInChanges,
    this.authorizationChecker,
    this.districtsStream,
    this.districtsStreamFactory,
    this.firebaseAuth,
    this.districtMutationService,
    this.signOut,
  });

  /// Emits the current signed-in state on login, logout, and token changes.
  /// Production uses FirebaseAuth.idTokenChanges(); tests inject this stream.
  final Stream<bool>? signedInChanges;
  final AdminAuthorizationChecker? authorizationChecker;
  final Stream<List<DistrictModel>>? districtsStream;
  final Stream<List<DistrictModel>> Function()? districtsStreamFactory;
  final FirebaseAuth? firebaseAuth;
  final DistrictMutationService? districtMutationService;
  final Future<void> Function()? signOut;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const Color maroon = Color(0xFF8E2442);
  static const Color cream = Color(0xFFFFF9E9);

  late final Stream<bool> _signedInChanges;
  StreamSubscription<bool>? _authSubscription;
  _AuthGateView _view = _AuthGateView.checking;
  bool _hasAuthenticatedUser = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _signedInChanges =
        widget.signedInChanges ??
        (widget.firebaseAuth ?? FirebaseAuth.instance)
            .idTokenChanges()
            .map((user) => user != null);
    _listenForAuthentication();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenForAuthentication() {
    _authSubscription?.cancel();
    _authSubscription = _signedInChanges.listen(
      _onSignedInChanged,
      onError: (Object _) {
        if (!mounted) return;
        ++_requestId;
        setState(() => _view = _AuthGateView.error);
      },
    );
  }

  void _onSignedInChanged(bool isSignedIn) {
    if (!mounted) return;
    _hasAuthenticatedUser = isSignedIn;
    if (!isSignedIn) {
      ++_requestId;
      setState(() => _view = _AuthGateView.signedOut);
      return;
    }
    _checkAdministrator(forceRefresh: false);
  }

  Future<void> _checkAdministrator({required bool forceRefresh}) async {
    if (!mounted) return;
    final requestId = ++_requestId;
    setState(() => _view = _AuthGateView.checkingAuthorization);
    try {
      final checker =
          widget.authorizationChecker ??
          AdminAuthorizationService(auth: widget.firebaseAuth);
      final isAdministrator = await checker.isCurrentUserAdmin(
        forceRefresh: forceRefresh,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _view = isAdministrator
            ? _AuthGateView.administrator
            : _AuthGateView.nonAdministrator;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _view = _AuthGateView.error);
    }
  }

  Future<void> _retryAuthorization() async {
    if (_hasAuthenticatedUser) {
      await _checkAdministrator(forceRefresh: true);
    } else {
      setState(() => _view = _AuthGateView.checking);
      _listenForAuthentication();
    }
  }

  Future<void> _signOut() async {
    try {
      if (widget.signOut != null) {
        await widget.signOut!();
      } else {
        await (widget.firebaseAuth ?? FirebaseAuth.instance).signOut();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _view = _AuthGateView.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _AuthGateView.checking:
      case _AuthGateView.checkingAuthorization:
        return Scaffold(
          backgroundColor: cream,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: maroon),
                const SizedBox(height: 16),
                Text(
                  'Checking administrator authorization…',
                  style: const TextStyle(color: maroon),
                ),
              ],
            ),
          ),
        );
      case _AuthGateView.signedOut:
        return LoginScreen(auth: widget.firebaseAuth);
      case _AuthGateView.administrator:
        return DistrictManagementScreen(
          districtsStream: widget.districtsStream,
          districtsStreamFactory: widget.districtsStreamFactory,
          mutationService: widget.districtMutationService,
          signOut: _signOut,
          isAdministrator: true,
        );
      case _AuthGateView.nonAdministrator:
        return _AuthorizationMessage(
          title: 'Administrator access required',
          message:
              'Your account is signed in, but it does not have the '
              'administrator permission needed to manage districts.',
          primaryActionLabel: 'Refresh authorization',
          onPrimaryAction: () => _checkAdministrator(forceRefresh: true),
          onSignOut: _signOut,
        );
      case _AuthGateView.error:
        return _AuthorizationMessage(
          title: 'Authorization could not be checked',
          message:
              'Check your internet connection and try again. District '
              'management remains unavailable until authorization is verified.',
          primaryActionLabel: 'Retry',
          onPrimaryAction: _retryAuthorization,
          onSignOut: _signOut,
        );
    }
  }
}

class _AuthorizationMessage extends StatelessWidget {
  const _AuthorizationMessage({
    required this.title,
    required this.message,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.onSignOut,
  });

  static const Color maroon = Color(0xFF8E2442);
  static const Color cream = Color(0xFFFFF9E9);

  final String title;
  final String message;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        title: const Text('MyYatra'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, color: maroon, size: 52),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: maroon,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onPrimaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: maroon,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(primaryActionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
