import 'package:flutter/foundation.dart';

import '../data/nepal_district_directory.dart';
import '../models/district_model.dart';
import '../services/district_data_validator.dart';
import '../services/district_mutation_service.dart';

enum DistrictMutationStatus { idle, loading, success, error }

/// Coordinates administrator-only district mutations through an injected
/// service. It contains no Firebase dependency.
class DistrictManagementController extends ChangeNotifier {
  DistrictManagementController({
    required this.isAdministrator,
    required this.service,
  });

  final bool isAdministrator;
  final DistrictMutationService service;

  DistrictMutationStatus status = DistrictMutationStatus.idle;
  String? message;
  bool _disposed = false;
  int _operationId = 0;

  bool get isLoading => status == DistrictMutationStatus.loading;

  @override
  void dispose() {
    _disposed = true;
    ++_operationId;
    super.dispose();
  }

  Future<bool> addDistrict(DistrictModel district) {
    return _run(
      () => service.addDistrict(
        DistrictDataValidator.normalize(district, isCreate: true),
      ),
      successMessage: 'District added successfully.',
    );
  }

  Future<bool> updateDistrict(DistrictModel district) {
    return _run(() {
      final normalized = DistrictDataValidator.normalize(
        district,
        isCreate: false,
      );
      final canonical = NepalDistrictDirectory.byName(normalized.name)!;
      final existingCanonical = NepalDistrictDirectory.byId(normalized.id);
      if (existingCanonical == null) {
        throw DistrictValidationException(
          '${canonical.name} uses a legacy document ID. An administrator '
          'must review this record before it can be updated.',
        );
      }
      if (existingCanonical.id != canonical.id) {
        throw const DistrictValidationException(
          'A district record’s canonical identity cannot be changed.',
        );
      }
      return service.updateDistrict(normalized);
    }, successMessage: 'District updated successfully.');
  }

  Future<bool> deleteDistrict(String id) {
    return _run(() {
      if (NepalDistrictDirectory.byId(id) == null) {
        throw const DistrictValidationException(
          'Only canonical district records can be deleted from this screen.',
        );
      }
      return service.deleteDistrict(id);
    }, successMessage: 'District deleted successfully.');
  }

  Future<bool> _run(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    if (_disposed || isLoading) return false;

    if (!isAdministrator) {
      status = DistrictMutationStatus.error;
      message = 'Administrator authorization is required.';
      _notifyListenersIfAlive();
      return false;
    }

    final operationId = ++_operationId;
    status = DistrictMutationStatus.loading;
    message = null;
    _notifyListenersIfAlive();
    try {
      await operation();
      if (_disposed || operationId != _operationId) return true;
      status = DistrictMutationStatus.success;
      message = successMessage;
      _notifyListenersIfAlive();
      return true;
    } catch (error) {
      if (_disposed || operationId != _operationId) return false;
      status = DistrictMutationStatus.error;
      message = error.toString().replaceFirst(RegExp(r'^Exception: '), '');
      _notifyListenersIfAlive();
      return false;
    }
  }

  void _notifyListenersIfAlive() {
    if (!_disposed) notifyListeners();
  }
}
