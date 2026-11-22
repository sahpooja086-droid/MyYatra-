import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/district_model.dart';
import '../../models/place_model.dart';
import '../../services/place_data_validator.dart';
import '../../services/place_service.dart';
import 'place_form_screen.dart';

class PlaceManagementScreen extends StatefulWidget {
  const PlaceManagementScreen({
    super.key,
    this.districtsStream,
    this.districtsStreamFactory,
    this.initialDistricts = const [],
    this.initialPlaces = const [],
    this.placesStreamFactory,
    this.placeMutations,
    this.signOut,
    this.isAdministrator = false,
  });

  /// Injected district data keeps this screen independent from Firebase.
  final Stream<List<DistrictModel>>? districtsStream;
  final Stream<List<DistrictModel>> Function()? districtsStreamFactory;
  final List<DistrictModel> initialDistricts;

  /// Local records for preview mode and widget tests.
  final List<PlaceModel> initialPlaces;
  final Stream<List<PlaceModel>> Function()? placesStreamFactory;
  final PlaceService? Function()? placeMutations;
  final Future<void> Function()? signOut;
  final bool isAdministrator;

  @override
  State<PlaceManagementScreen> createState() => _PlaceManagementScreenState();
}

class _PlaceManagementScreenState extends State<PlaceManagementScreen> {
  static const Color maroon = Color(0xFF8E2442);
  static const Color purple = Color(0xFFA482B7);
  static const Color cream = Color(0xFFFFF9E9);
  static const String allDistrictsLabel = 'All Districts';

  late Stream<List<DistrictModel>> _districtsStream;
  Stream<List<PlaceModel>>? _placesStream;
  List<DistrictModel> _loadedDistricts = const [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedDistrictId = allDistrictsLabel;
  bool _deleting = false;

  PlaceService? get _mutations =>
      widget.isAdministrator && _placesStream != null
      ? widget.placeMutations?.call()
      : null;

  @override
  void initState() {
    super.initState();
    if (widget.isAdministrator) {
      _districtsStream =
          widget.districtsStreamFactory?.call() ??
          widget.districtsStream ??
          Stream.value(widget.initialDistricts);
      _placesStream = widget.placesStreamFactory?.call();
    }
  }

  @override
  void didUpdateWidget(covariant PlaceManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAdministrator != widget.isAdministrator ||
        oldWidget.placesStreamFactory != widget.placesStreamFactory) {
      _placesStream = widget.isAdministrator
          ? widget.placesStreamFactory?.call()
          : null;
    }
    if (widget.isAdministrator && !oldWidget.isAdministrator) {
      _districtsStream =
          widget.districtsStreamFactory?.call() ??
          widget.districtsStream ??
          Stream.value(widget.initialDistricts);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm({
    PlaceModel? place,
    required List<DistrictModel> districts,
  }) async {
    if (!widget.isAdministrator || _deleting) return;
    final service = _mutations;
    final result = await Navigator.of(context).push<PlaceModel>(
      MaterialPageRoute<PlaceModel>(
        builder: (_) => PlaceFormScreen(
          districts: districts,
          place: place,
          onSave: service == null
              ? null
              : (record) {
                  if (!mounted || _mutations != service) {
                    throw const PlaceServiceException(
                      'Verified emulator access is required to save places.',
                    );
                  }
                  return place == null
                      ? service.addPlace(record)
                      : service.updatePlace(record);
                },
        ),
      ),
    );
    if (!mounted || result == null) return;
    _showMessage(
      service == null
          ? 'Place data validated locally. It was NOT saved to Firestore.'
          : place == null
          ? 'Place added successfully.'
          : 'Place updated successfully.',
    );
  }

  Future<void> _confirmDelete(PlaceModel place) async {
    if (!widget.isAdministrator || _deleting) return;
    final service = _mutations;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          service == null ? 'Preview place deletion' : 'Delete place?',
        ),
        content: Text(
          service == null
              ? 'This is a preview only. ${place.name} will not be deleted or '
                    'changed in Firestore.'
              : 'Delete ${place.name} from the demo emulator?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(service == null ? 'Preview Delete' : 'Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _deleting) return;
    if (service == null) {
      _showMessage('Deletion preview confirmed. No place was deleted.');
      return;
    }
    if (_mutations != service) {
      _showMessage('Verified emulator access is required to delete places.');
      return;
    }
    setState(() => _deleting = true);
    try {
      await service.deletePlace(place.id);
      if (mounted) _showMessage('Place deleted successfully.');
    } on PlaceServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } on PlaceValidationException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Could not delete the place. Try again.');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  DistrictModel? _districtFor(String id, List<DistrictModel> districts) {
    for (final district in districts) {
      if (district.id == id) return district;
    }
    return null;
  }

  Widget _buildResults(
    List<DistrictModel> districts,
    List<PlaceModel> records,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final places = records
        .where((place) {
          final matchesSearch = place.name.trim().toLowerCase().contains(query);
          final matchesDistrict =
              _selectedDistrictId == allDistrictsLabel ||
              place.districtId == _selectedDistrictId;
          return matchesSearch &&
              matchesDistrict &&
              (_placesStream != null ||
                  _districtFor(place.districtId, districts) != null);
        })
        .toList(growable: false);
    if (places.isEmpty) {
      final hasFilters =
          _searchController.text.trim().isNotEmpty ||
          _selectedDistrictId != allDistrictsLabel;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            hasFilters
                ? 'No places match your search or district filter.'
                : _placesStream != null
                ? 'No places found in the demo emulator.'
                : 'No place records are connected yet. Add and Edit are '
                      'available as local previews only.',
            key: const Key('place-empty-state'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('place-results'),
      padding: const EdgeInsets.all(16),
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        final district = _districtFor(place.districtId, districts);
        return Card(
          color: Colors.white,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFF5EAF5),
              child: Icon(Icons.place, color: purple),
            ),
            title: Text(
              place.name,
              style: const TextStyle(
                color: maroon,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              district == null
                  ? 'District unavailable'
                  : '${place.category} · ${district.name} (${district.province})',
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  key: Key('edit-place-${place.id}'),
                  tooltip: _mutations == null
                      ? 'Preview edit place'
                      : 'Edit place',
                  onPressed: _deleting
                      ? null
                      : () => _openForm(place: place, districts: districts),
                  icon: const Icon(Icons.edit, color: maroon),
                ),
                IconButton(
                  key: Key('delete-place-${place.id}'),
                  tooltip: _mutations == null
                      ? 'Preview delete place'
                      : 'Delete place',
                  onPressed: _deleting ? null : () => _confirmDelete(place),
                  icon: const Icon(Icons.delete_outline, color: maroon),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceList(List<DistrictModel> districts) {
    if (_placesStream == null) {
      return _buildResults(districts, widget.initialPlaces);
    }

    return StreamBuilder<List<PlaceModel>>(
      stream: _placesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              key: Key('place-list-loading'),
              color: maroon,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load places from the demo emulator.'),
                TextButton.icon(
                  key: const Key('retry-place-list'),
                  onPressed: () => setState(() {
                    _placesStream = widget.placesStreamFactory?.call();
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        return _buildResults(districts, snapshot.data ?? const []);
      },
    );
  }

  Widget _buildDistrictStream() {
    return StreamBuilder<List<DistrictModel>>(
      stream: _districtsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load districts for place management.'),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _districtsStream =
                        widget.districtsStreamFactory?.call() ??
                        widget.districtsStream ??
                        Stream.value(widget.initialDistricts);
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: maroon));
        }
        _loadedDistricts = snapshot.data ?? const [];
        if (_selectedDistrictId != allDistrictsLabel &&
            !_loadedDistricts.any(
              (district) => district.id == _selectedDistrictId,
            )) {
          _selectedDistrictId = allDistrictsLabel;
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: DropdownButtonFormField<String>(
                key: const Key('place-district-filter'),
                initialValue: _selectedDistrictId,
                decoration: const InputDecoration(
                  labelText: 'Filter by district',
                  prefixIcon: Icon(Icons.map, color: purple),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: allDistrictsLabel,
                    child: Text(allDistrictsLabel),
                  ),
                  ..._loadedDistricts.map(
                    (district) => DropdownMenuItem(
                      value: district.id,
                      child: Text(district.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDistrictId = value);
                  }
                },
              ),
            ),
            Expanded(child: _buildPlaceList(_loadedDistricts)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdministrator) {
      return const Scaffold(
        backgroundColor: cream,
        body: Center(
          child: Text(
            'Administrator authorization is required to manage places.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        title: const Text('Manage Places'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: widget.signOut ?? () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _placesStream == null
                    ? 'Preview only: place records are not connected to Firestore.'
                    : _mutations == null
                    ? 'Demo emulator list. Add, Edit, and Delete are previews.'
                    : 'Place changes are saved to the demo emulator.',
                style: const TextStyle(color: maroon, fontSize: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: TextField(
              key: const Key('place-search-field'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search places',
                prefixIcon: Icon(Icons.search, color: purple),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_deleting)
            const LinearProgressIndicator(semanticsLabel: 'Deleting place'),
          Expanded(child: _buildDistrictStream()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-place-button'),
        onPressed: _deleting
            ? null
            : () => _openForm(districts: _loadedDistricts),
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Place'),
      ),
    );
  }
}
