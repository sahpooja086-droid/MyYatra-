import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/journal_entry_model.dart';
import '../models/journey_models.dart';
import '../models/photo_model.dart';
import '../models/user_profile_model.dart';
import '../models/visit_model.dart';

class PersonalTravelException implements Exception {
  const PersonalTravelException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Uploads and deletes photo binaries for the signed-in owner.
abstract interface class PhotoStorage {
  Future<String> upload({
    required String uid,
    required String path,
    required Uint8List bytes,
    required String contentType,
  });

  Future<void> delete(String path);
}

class FirebasePhotoStorage implements PhotoStorage {
  FirebasePhotoStorage({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> upload({
    required String uid,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final reference = _storage.ref(path);
    if (!path.startsWith('users/$uid/photos/')) {
      throw const PersonalTravelException(
        'Photos can only be uploaded to your own private folder.',
      );
    }
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return reference.getDownloadURL();
  }

  @override
  Future<void> delete(String path) => _storage.ref(path).delete();
}

/// Reads and writes records that live under `users/{uid}`.
///
/// Every query is scoped to the current user, so the app never asks Firestore
/// for another person's private data. Firestore rules enforce the same rule
/// independently of this service.
class PersonalTravelService {
  PersonalTravelService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    PhotoStorage? photoStorage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _photoStorage = photoStorage ?? FirebasePhotoStorage();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final PhotoStorage _photoStorage;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const PersonalTravelException('Please sign in again.');
    }
    return uid;
  }

  DocumentReference<Map<String, dynamic>> get _userDocument =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> _privateCollection(String name) =>
      _userDocument.collection(name);

  Stream<List<VisitModel>> watchVisits() {
    return _privateCollection('visits')
        .orderBy('visitedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(VisitModel.fromFirestore)
              .toList(growable: false),
        )
        .handleError(_mapError);
  }

  Future<void> addVisit(VisitModel visit) {
    return _run(() async {
      await _privateCollection('visits').add(visit.toFirestore());
    });
  }

  Future<void> deleteVisit(String id) {
    return _run(() async {
      await _privateCollection('visits').doc(id).delete();
    });
  }

  Stream<List<JournalEntryModel>> watchJournalEntries() {
    return _privateCollection('journalEntries')
        .orderBy('entryDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(JournalEntryModel.fromFirestore)
              .toList(growable: false),
        )
        .handleError(_mapError);
  }

  Future<void> addJournalEntry(JournalEntryModel entry) {
    return _run(() async {
      await _privateCollection('journalEntries').add(entry.toFirestore());
    });
  }

  Future<void> updateJournalEntry(JournalEntryModel entry) {
    return _run(() async {
      await _privateCollection('journalEntries')
          .doc(entry.id)
          .update(entry.toFirestore());
    });
  }

  Future<void> deleteJournalEntry(String id) {
    return _run(() async {
      await _privateCollection('journalEntries').doc(id).delete();
    });
  }

  Stream<List<PhotoModel>> watchPhotos() {
    return _privateCollection('photos')
        .orderBy('capturedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(PhotoModel.fromFirestore)
              .toList(growable: false),
        )
        .handleError(_mapError);
  }

  Future<void> addPhoto({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String caption,
    required String placeId,
    required String districtId,
    DateTime? capturedAt,
  }) {
    return _run(() async {
      final uid = _uid;
      final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path =
          'users/$uid/photos/${DateTime.now().microsecondsSinceEpoch}-$safeName';
      final downloadUrl = await _photoStorage.upload(
        uid: uid,
        path: path,
        bytes: bytes,
        contentType: contentType,
      );
      final photo = PhotoModel(
        id: '',
        downloadUrl: downloadUrl,
        storagePath: path,
        caption: caption.trim(),
        placeId: placeId,
        districtId: districtId,
        capturedAt: capturedAt ?? DateTime.now(),
      );
      await _privateCollection('photos').add(photo.toFirestore());
    });
  }

  Future<void> deletePhoto(PhotoModel photo) {
    return _run(() async {
      await _privateCollection('photos').doc(photo.id).delete();
      if (photo.storagePath.isNotEmpty) {
        try {
          await _photoStorage.delete(photo.storagePath);
        } catch (_) {
          // The metadata is the source of truth; a missing binary is harmless.
        }
      }
    });
  }

  Future<UserProfileModel?> getProfile() {
    return _run(() async {
      final document = await _userDocument.get();
      if (!document.exists) return null;
      return UserProfileModel.fromFirestore(document);
    });
  }

  Stream<JourneyDnaModel?> watchJourneyDna() {
    return _privateCollection('journeyDna')
        .doc('current')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? JourneyDnaModel.fromMap(snapshot.data()) : null,
        )
        .handleError(_mapError);
  }

  Future<void> saveJourneyDna(JourneyDnaModel dna) {
    return _run(() async {
      await _privateCollection('journeyDna')
          .doc('current')
          .set(dna.toFirestore());
    });
  }

  Future<List<VisitModel>> getVisitsOnce() {
    return _run(() async {
      final snapshot = await _privateCollection('visits').get();
      return snapshot.docs
          .map(VisitModel.fromFirestore)
          .toList(growable: false);
    });
  }

  Future<List<JournalEntryModel>> getJournalEntriesOnce() {
    return _run(() async {
      final snapshot = await _privateCollection('journalEntries').get();
      return snapshot.docs
          .map(JournalEntryModel.fromFirestore)
          .toList(growable: false);
    });
  }

  Future<List<PhotoModel>> getPhotosOnce() {
    return _run(() async {
      final snapshot = await _privateCollection('photos').get();
      return snapshot.docs
          .map(PhotoModel.fromFirestore)
          .toList(growable: false);
    });
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PersonalTravelException {
      rethrow;
    } on FirebaseException catch (error) {
      throw PersonalTravelException(_messageFor(error));
    }
  }

  Never _mapError(Object error) {
    if (error is FirebaseException) {
      throw PersonalTravelException(_messageFor(error));
    }
    throw error;
  }

  String _messageFor(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'This personal record is not available to the current account.';
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return 'Could not reach your private records. Check your connection.';
      default:
        return 'Your private records could not be loaded. Please try again.';
    }
  }
}
