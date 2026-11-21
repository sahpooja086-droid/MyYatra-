import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../controllers/district_management_controller.dart';
import '../../data/nepal_district_directory.dart';
import '../../models/district_model.dart';
import '../../services/district_data_validator.dart';
import '../../services/district_mutation_service.dart';
import '../../services/district_service.dart';
import 'district_form_screen.dart';

class DistrictManagementScreen extends StatefulWidget {
  const DistrictManagementScreen({
    super.key,
    this.districtsStream,
    this.districtsStreamFactory,
    this.mutationService,
    this.isAdministrator = false,
  });

  /// Optional stream for UI tests; production uses [DistrictService].
  final Stream<List<DistrictModel>>? districtsStream;

  /// Optional factory allows injected streams to be recreated when retried.
  final Stream<List<DistrictModel>> Function()? districtsStreamFactory;

  /// Optional mutation service for isolated test or explicitly enabled builds.
  /// The production [AuthGate] does not provide a write service.
  final DistrictMutationService? mutationService;
  final bool isAdministrator;

  @override
  State<DistrictManagementScreen> createState() =>
      _DistrictManagementScreenState();
}

class _DistrictManagementScreenState extends State<DistrictManagementScreen> {
  static const Color maroon = Color(0xFF8E2442);
  static const Color purple = Color(0xFFA482B7);
  static const Color cream = Color(0xFFFFF9E9);
  static const String allProvincesLabel = 'All Provinces';

  late Stream<List<DistrictModel>> _districtsStream;
  DistrictManagementController? _controller;
  final TextEditingController _searchController = TextEditingController();
  String _selectedProvince = allProvincesLabel;

  @override
  void initState() {
    super.initState();
    if (widget.isAdministrator) {
      _districtsStream = _createDistrictsStream();
    }
    _configureController();
  }

  @override
  void didUpdateWidget(covariant DistrictManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAdministrator &&
        (!oldWidget.isAdministrator ||
            oldWidget.districtsStream != widget.districtsStream ||
            oldWidget.districtsStreamFactory !=
                widget.districtsStreamFactory)) {
      _districtsStream = _createDistrictsStream();
    }
    if (oldWidget.isAdministrator != widget.isAdministrator ||
        oldWidget.mutationService != widget.mutationService) {
      _configureController();
    }
  }

  Stream<List<DistrictModel>> _createDistrictsStream() {
    return widget.districtsStreamFactory?.call() ??
        widget.districtsStream ??
        DistrictService().getDistricts();
  }

  void _configureController() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _controller = null;

    final mutationService = widget.mutationService;
    if (widget.isAdministrator && mutationService != null) {
      _controller = DistrictManagementController(
        isAdministrator: true,
        service: mutationService,
      )..addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  List<DistrictModel> _filterDistricts(List<DistrictModel> districts) {
    final query = _searchController.text.trim().toLowerCase();
    final provinceFilter = _selectedProvince.toLowerCase();

    return districts.where((district) {
      final name = district.name.trim().toLowerCase();
      final province = district.province.trim().toLowerCase();
      final matchesName = query.isEmpty || name.contains(query);
      final matchesProvince =
          _selectedProvince == allProvincesLabel || province == provinceFilter;
      return matchesName && matchesProvince;
    }).toList();
  }

  void _retryLoadingDistricts() {
    setState(() {
      _districtsStream = _createDistrictsStream();
    });
  }

  Future<void> _openDistrictForm({DistrictModel? district}) async {
    if (!widget.isAdministrator) return;
    final preview = await Navigator.of(context).push<DistrictModel>(
      MaterialPageRoute(
        builder: (_) => DistrictFormScreen(
          district: district,
          previewOnly: widget.mutationService == null,
          submitLabel: widget.mutationService == null
              ? 'Preview District'
              : district == null
              ? 'Add District'
              : 'Update District',
        ),
      ),
    );

    if (!mounted || preview == null) return;

    final controller = _controller;
    if (controller == null) {
      try {
        DistrictDataValidator.normalize(preview, isCreate: district == null);
        _showMessage(
          'District data validated locally. It was NOT saved to Firestore.',
        );
      } on DistrictValidationException catch (error) {
        _showMessage(error.message);
      }
      return;
    }

    final saved = district == null
        ? await controller.addDistrict(preview)
        : await controller.updateDistrict(preview);
    if (!mounted) return;
    _showMessage(controller.message ?? 'District operation failed.', saved);
  }

  void _showMessage(String message, [bool isSuccess = false]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green.shade700 : null,
      ),
    );
  }

  Future<void> _confirmDelete(DistrictModel district) async {
    if (!widget.isAdministrator) return;
    final hasMutationService = _controller != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          hasMutationService ? 'Delete district?' : 'Preview district deletion',
        ),
        content: Text(
          hasMutationService
              ? 'Delete ${district.name} from the supplied district service? '
                    'This cannot be undone.'
              : 'This is a preview only. No Firestore data will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(hasMutationService ? 'Delete' : 'Preview Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    final controller = _controller;
    if (controller == null) {
      _showMessage('Delete was previewed. No data was deleted.');
      return;
    }

    final deleted = await controller.deleteDistrict(district.id);
    if (!mounted) return;
    _showMessage(controller.message ?? 'District operation failed.', deleted);
  }

  Widget _buildDistrictList(
    List<DistrictModel> districts, {
    required bool hasActiveFilters,
  }) {
    if (districts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            hasActiveFilters
                ? 'No districts match your search or province filter. '
                      'Try changing your search or selecting All Provinces.'
                : 'No districts yet. District information will appear here '
                      'once it has been added.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: districts.length,
      itemBuilder: (context, index) {
        final district = districts[index];

        return Card(
          color: Colors.white,
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFF5EAF5),
              child: Icon(Icons.location_on, color: purple),
            ),
            title: Text(
              district.name.trim().isEmpty
                  ? 'District name unavailable'
                  : district.name.trim(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: maroon,
              ),
            ),
            subtitle: Text(
              district.province.trim().isEmpty
                  ? 'Province unavailable'
                  : '${district.province.trim()} Province',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: widget.mutationService == null
                      ? 'Preview district changes (not saved)'
                      : 'Edit district',
                  icon: const Icon(Icons.edit, color: maroon),
                  onPressed: _controller?.isLoading == true
                      ? null
                      : () => _openDistrictForm(district: district),
                ),
                IconButton(
                  tooltip: widget.mutationService == null
                      ? 'Preview delete (not saved)'
                      : 'Delete district',
                  icon: const Icon(Icons.delete_outline, color: maroon),
                  onPressed: _controller?.isLoading == true
                      ? null
                      : () => _confirmDelete(district),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDistrictStream() {
    return StreamBuilder<List<DistrictModel>>(
      stream: _districtsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, color: maroon, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'We couldn’t load districts right now. Please check your '
                    'connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _retryLoadingDistricts,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(foregroundColor: maroon),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: maroon));
        }

        final allDistricts = snapshot.data ?? const <DistrictModel>[];
        return _buildDistrictList(
          _filterDistricts(allDistricts),
          hasActiveFilters:
              _searchController.text.trim().isNotEmpty ||
              _selectedProvince != allProvincesLabel,
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
            'Administrator authorization is required to manage districts.',
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
        title: const Text(
          'Manage Districts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explore Nepal',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: maroon,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage district information',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.mutationService == null
                      ? 'Read-only: Add, Edit, and Delete are previews; '
                            'changes are not saved to Firestore.'
                      : 'Using the injected district service. Production '
                            'Firestore writes remain disconnected.',
                  style: const TextStyle(color: maroon, fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: TextField(
              key: const Key('district-search-field'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search districts',
                hintText: 'Enter a district name',
                prefixIcon: const Icon(Icons.search, color: purple),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: DropdownButtonFormField<String>(
              key: const Key('district-province-filter'),
              initialValue: _selectedProvince,
              decoration: const InputDecoration(
                labelText: 'Filter by province',
                prefixIcon: Icon(Icons.map, color: purple),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: [allProvincesLabel, ...NepalDistrictDirectory.provinces]
                  .map(
                    (province) => DropdownMenuItem(
                      value: province,
                      child: Text(province),
                    ),
                  )
                  .toList(),
              onChanged: (province) {
                if (province == null) return;
                setState(() => _selectedProvince = province);
              },
            ),
          ),
          if (_controller?.isLoading == true)
            const LinearProgressIndicator(color: maroon),
          Expanded(child: _buildDistrictStream()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _controller?.isLoading == true
            ? null
            : () => _openDistrictForm(),
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add District'),
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'MyYatra • Explore · Track · Discover',
            textAlign: TextAlign.center,
            style: TextStyle(color: maroon, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
