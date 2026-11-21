import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/nepal_district_directory.dart';
import '../../models/district_model.dart';
import '../../services/district_service.dart';
import 'district_form_screen.dart';

class DistrictManagementScreen extends StatefulWidget {
  const DistrictManagementScreen({super.key, this.districtsStream});

  /// Optional stream for UI tests; production uses [DistrictService].
  final Stream<List<DistrictModel>>? districtsStream;

  @override
  State<DistrictManagementScreen> createState() =>
      _DistrictManagementScreenState();
}

class _DistrictManagementScreenState
    extends State<DistrictManagementScreen> {
  static const Color maroon = Color(0xFF8E2442);
  static const Color purple = Color(0xFFA482B7);
  static const Color cream = Color(0xFFFFF9E9);
  static const String allProvincesLabel = 'All Provinces';

  late Stream<List<DistrictModel>> _districtsStream;
  final TextEditingController _searchController = TextEditingController();
  String _selectedProvince = allProvincesLabel;

  @override
  void initState() {
    super.initState();
    _districtsStream =
        widget.districtsStream ?? DistrictService().getDistricts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DistrictModel> _filterDistricts(List<DistrictModel> districts) {
    final query = _searchController.text.trim().toLowerCase();
    final provinceFilter = _selectedProvince.toLowerCase();

    return districts.where((district) {
      final name = district.name.trim().toLowerCase();
      final province = district.province.trim().toLowerCase();
      final matchesName = query.isEmpty || name.contains(query);
      final matchesProvince = _selectedProvince == allProvincesLabel ||
          province == provinceFilter;
      return matchesName && matchesProvince;
    }).toList();
  }

  void _retryLoadingDistricts() {
    setState(() {
      _districtsStream = DistrictService().getDistricts();
    });
  }

  Future<void> _openDistrictForm({DistrictModel? district}) async {
    final preview = await Navigator.of(context).push<DistrictModel>(
      MaterialPageRoute(
        builder: (_) => DistrictFormScreen(district: district),
      ),
    );

    if (!mounted || preview == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'District data validated locally. It was NOT saved to Firestore.',
        ),
      ),
    );
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
            trailing: IconButton(
              tooltip: 'Preview district changes (not saved)',
              icon: const Icon(Icons.edit, color: maroon),
              onPressed: () => _openDistrictForm(district: district),
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
          return const Center(
            child: CircularProgressIndicator(color: maroon),
          );
        }

        final allDistricts = snapshot.data ?? const <DistrictModel>[];
        return _buildDistrictList(
          _filterDistricts(allDistricts),
          hasActiveFilters: _searchController.text.trim().isNotEmpty ||
              _selectedProvince != allProvincesLabel,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore Nepal',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: maroon,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Manage district information',
                  style: TextStyle(color: Colors.black54),
                ),
                SizedBox(height: 6),
                Text(
                  'Read-only: Add and Edit are previews; changes are not saved.',
                  style: TextStyle(color: maroon, fontSize: 12),
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
              items: [
                allProvincesLabel,
                ...NepalDistrictDirectory.provinces,
              ]
                  .map((province) => DropdownMenuItem(
                        value: province,
                        child: Text(province),
                      ))
                  .toList(),
              onChanged: (province) {
                if (province == null) return;
                setState(() => _selectedProvince = province);
              },
            ),
          ),
          Expanded(child: _buildDistrictStream()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDistrictForm(),
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
