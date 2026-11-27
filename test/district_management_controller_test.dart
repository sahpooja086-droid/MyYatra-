import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/controllers/district_management_controller.dart';
import 'package:myyatra/models/district_model.dart';
import 'package:myyatra/services/district_service.dart';

import 'support/fake_district_mutation_service.dart';

void main() {
  group('DistrictManagementController', () {
    test(
      'adds a valid canonical district through the injected service',
      () async {
        final service = FakeDistrictMutationService();
        final controller = DistrictManagementController(
          isAdministrator: true,
          service: service,
        );

        expect(await controller.addDistrict(_kaski()), isTrue);
        expect(service.addCalls, 1);
        expect(service.districts['kaski']?.name, 'Kaski');
        expect(controller.message, 'District added successfully.');
        controller.dispose();
      },
    );

    test('updates a canonical district through the injected service', () async {
      final service = FakeDistrictMutationService([_kaski()]);
      final controller = DistrictManagementController(
        isAdministrator: true,
        service: service,
      );

      final updated = DistrictModel(
        id: 'kaski',
        name: 'Kaski',
        province: 'Gandaki',
        description: 'Updated lake district',
        experienceTypes: const ['Nature', 'Photography'],
      );
      expect(await controller.updateDistrict(updated), isTrue);
      expect(service.updateCalls, 1);
      expect(service.districts['kaski']?.description, 'Updated lake district');
      expect(controller.message, 'District updated successfully.');
      controller.dispose();
    });

    test('deletes a canonical district through the injected service', () async {
      final service = FakeDistrictMutationService([_kaski()]);
      final controller = DistrictManagementController(
        isAdministrator: true,
        service: service,
      );

      expect(await controller.deleteDistrict('kaski'), isTrue);
      expect(service.deleteCalls, 1);
      expect(service.districts, isEmpty);
      expect(controller.message, 'District deleted successfully.');
      controller.dispose();
    });

    test('rejects invalid district data before calling the service', () async {
      final service = FakeDistrictMutationService();
      final controller = DistrictManagementController(
        isAdministrator: true,
        service: service,
      );
      final invalidDistrict = DistrictModel(
        id: 'kaski',
        name: 'Kaski',
        province: 'Bagmati',
        description: 'Description',
        experienceTypes: const ['Nature'],
      );

      expect(await controller.addDistrict(invalidDistrict), isFalse);
      expect(controller.status, DistrictMutationStatus.error);
      expect(controller.message, contains('belongs to Gandaki'));
      expect(service.addCalls, 0);
      controller.dispose();
    });

    test(
      'blocks duplicate districts without overwriting the stored record',
      () async {
        final existing = _kaski();
        final service = FakeDistrictMutationService([existing]);
        final controller = DistrictManagementController(
          isAdministrator: true,
          service: service,
        );
        final duplicate = DistrictModel(
          id: 'kaski',
          name: 'Kaski',
          province: 'Gandaki',
          description: 'Replacement description',
          experienceTypes: const ['Culture'],
        );

        expect(await controller.addDistrict(duplicate), isFalse);
        expect(controller.message, contains('already exists'));
        expect(service.districts['kaski']?.description, existing.description);
        expect(service.addCalls, 0);
        controller.dispose();
      },
    );

    test('reports service errors without reporting success', () async {
      final service = FakeDistrictMutationService()
        ..operationError = const DistrictServiceException('Offline');
      final controller = DistrictManagementController(
        isAdministrator: true,
        service: service,
      );

      expect(await controller.addDistrict(_kaski()), isFalse);
      expect(controller.status, DistrictMutationStatus.error);
      expect(controller.message, 'Offline');
      expect(service.districts, isEmpty);
      controller.dispose();
    });

    test(
      'exposes a loading state while the injected service is working',
      () async {
        final service = FakeDistrictMutationService();
        final operationGate = Completer<void>();
        service.beforeOperation = () => operationGate.future;
        final controller = DistrictManagementController(
          isAdministrator: true,
          service: service,
        );

        final operation = controller.addDistrict(_kaski());
        expect(controller.status, DistrictMutationStatus.loading);
        expect(controller.isLoading, isTrue);
        operationGate.complete();

        expect(await operation, isTrue);
        expect(controller.isLoading, isFalse);
        controller.dispose();
      },
    );

    test('does not call the mutation service for a non-admin', () async {
      final service = FakeDistrictMutationService();
      final controller = DistrictManagementController(
        isAdministrator: false,
        service: service,
      );

      expect(await controller.addDistrict(_kaski()), isFalse);
      expect(controller.message, contains('authorization is required'));
      expect(service.addCalls, 0);
      controller.dispose();
    });

    test('rejects deleting a legacy document ID', () async {
      final service = FakeDistrictMutationService();
      final controller = DistrictManagementController(
        isAdministrator: true,
        service: service,
      );

      expect(await controller.deleteDistrict('old-kaski-id'), isFalse);
      expect(controller.message, contains('canonical district records'));
      expect(service.deleteCalls, 0);
      controller.dispose();
    });

    test('rejects updating a legacy ID before calling the service', () async {
      final legacy = DistrictModel(
        id: 'old-kaski-id',
        name: 'Kaski',
        province: 'Gandaki',
        description: 'Legacy record',
        experienceTypes: const ['Nature'],
      );
      final service = FakeDistrictMutationService([legacy]);
      final controller = DistrictManagementController(
        isAdministrator: true,
        service: service,
      );

      expect(await controller.updateDistrict(legacy), isFalse);
      expect(controller.message, contains('legacy document ID'));
      expect(service.updateCalls, 0);
      expect(service.districts['old-kaski-id']?.description, 'Legacy record');
      controller.dispose();
    });

    test('rejects changing a canonical district identity', () async {
      final service = FakeDistrictMutationService([_kaski()]);
      final controller = DistrictManagementController(
        isAdministrator: true,
        service: service,
      );
      final reassigned = DistrictModel(
        id: 'kaski',
        name: 'Kathmandu',
        province: 'Bagmati',
        description: 'Attempted reassignment',
        experienceTypes: const ['Culture'],
      );

      expect(await controller.updateDistrict(reassigned), isFalse);
      expect(controller.message, contains('identity cannot be changed'));
      expect(service.updateCalls, 0);
      expect(service.districts['kaski']?.name, 'Kaski');
      controller.dispose();
    });

    test('does not notify after disposal during a pending operation', () async {
      final service = FakeDistrictMutationService();
      final operationGate = Completer<void>();
      service.beforeOperation = () => operationGate.future;
      final controller = DistrictManagementController(
        isAdministrator: true,
        service: service,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      final operation = controller.addDistrict(_kaski());
      expect(notifications, 1);
      controller.dispose();
      operationGate.complete();

      expect(await operation, isTrue);
      expect(notifications, 1);
    });
  });
}

DistrictModel _kaski() => DistrictModel(
  id: 'kaski',
  name: 'Kaski',
  province: 'Gandaki',
  description: 'Lake district',
  experienceTypes: const ['Nature'],
);
