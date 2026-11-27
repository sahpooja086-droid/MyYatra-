import 'package:flutter/material.dart';

import '../../data/nepal_district_directory.dart';
import '../../models/district_model.dart';

class DistrictFormRules {
  DistrictFormRules._();

  static const provinces = NepalDistrictDirectory.provinces;

  static const experienceCategories =
      NepalDistrictDirectory.experienceCategories;

  static String? validateRequiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? validateProvince(String? value) {
    if (value == null || value.isEmpty) return 'Province is required';
    if (!provinces.contains(value)) return 'Select a supported province';
    return null;
  }

  static String? validateDistrict(String? value, String? province) {
    if (value == null || value.isEmpty) return 'District name is required';
    if (validateProvince(province) != null) {
      return 'Select a province before choosing a district';
    }
    final district = NepalDistrictDirectory.byName(value);
    if (district == null) return 'Select a supported district';
    if (district.province != province) {
      return '$value does not belong to $province';
    }
    return null;
  }

  static String? validateExperienceTypes(List<String> values) {
    if (values.isEmpty) return 'Select at least one experience type';
    if (values.any((value) => !experienceCategories.contains(value))) {
      return 'Remove unsupported experience types';
    }
    return null;
  }
}

/// A local-only district form. The result is returned to the caller; this
/// screen intentionally does not perform Firestore writes.
class DistrictFormScreen extends StatefulWidget {
  const DistrictFormScreen({
    super.key,
    this.district,
    this.previewOnly = true,
    this.submitLabel = 'Preview District',
  });

  final DistrictModel? district;
  final bool previewOnly;
  final String submitLabel;

  @override
  State<DistrictFormScreen> createState() => _DistrictFormScreenState();
}

class _DistrictFormScreenState extends State<DistrictFormScreen> {
  static const Color maroon = Color(0xFF8E2442);
  static const Color cream = Color(0xFFFFF9E9);
  static const Color purple = Color(0xFFA482B7);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  String? _province;
  String? _selectedDistrict;
  String? _legacyDistrictIssue;
  late List<String> _experienceTypes;

  bool get _isEditing => widget.district != null;

  @override
  void initState() {
    super.initState();
    final district = widget.district;
    _descriptionController = TextEditingController(
      text: district?.description ?? '',
    );
    _province = DistrictFormRules.provinces.contains(district?.province)
        ? district?.province
        : null;

    if (district != null) {
      final canonicalDistrict =
          NepalDistrictDirectory.byId(district.id) ??
          NepalDistrictDirectory.byName(district.name);
      final savedName = district.name.trim().toLowerCase();
      final nameMatchesCanonical =
          canonicalDistrict != null &&
          (canonicalDistrict.name.toLowerCase() == savedName ||
              canonicalDistrict.alternateNames.any(
                (alias) => alias.toLowerCase() == savedName,
              ));
      if (canonicalDistrict != null &&
          canonicalDistrict.province == district.province &&
          nameMatchesCanonical) {
        _province = canonicalDistrict.province;
        _selectedDistrict = canonicalDistrict.name;
      } else if (canonicalDistrict == null) {
        _legacyDistrictIssue =
            '"${district.name}" is not in the canonical district list. '
            'Choose a valid district to continue.';
      } else if (canonicalDistrict.province != district.province) {
        _legacyDistrictIssue =
            '"${district.name}" belongs to ${canonicalDistrict.province}, '
            'not ${district.province}. Select the correct province and district.';
      } else {
        _legacyDistrictIssue =
            '"${district.name}" does not match the canonical name '
            '"${canonicalDistrict.name}" for this district record. '
            'Select a valid district to continue.';
      }
    }
    _experienceTypes = List<String>.of(district?.experienceTypes ?? const []);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final existing = widget.district;
    final canonicalDistrict = NepalDistrictDirectory.byName(_selectedDistrict!);
    final result = DistrictModel(
      id: existing?.id ?? canonicalDistrict!.id,
      name: canonicalDistrict!.name,
      province: canonicalDistrict.province,
      description: _descriptionController.text.trim(),
      experienceTypes: List<String>.of(_experienceTypes),
      updatedAt: existing?.updatedAt,
    );

    // Return the entered data for local preview. The caller must not persist it
    // until secure admin authorization and Firestore rules are implemented.
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Edit District' : 'Add District'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: const Key('district-province-field'),
                    initialValue: _province,
                    decoration: const InputDecoration(
                      labelText: 'Province',
                      prefixIcon: Icon(Icons.map, color: purple),
                      border: OutlineInputBorder(),
                    ),
                    items: NepalDistrictDirectory.provinces
                        .map(
                          (province) => DropdownMenuItem(
                            value: province,
                            child: Text(province),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      if (_province != value) {
                        _province = value;
                        _selectedDistrict = null;
                        _legacyDistrictIssue = null;
                      }
                    }),
                    validator: DistrictFormRules.validateProvince,
                  ),
                  const SizedBox(height: 16),
                  if (_legacyDistrictIssue != null) ...[
                    Text(
                      _legacyDistrictIssue!,
                      key: const Key('district-legacy-warning'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  DropdownButtonFormField<String>(
                    key: ValueKey('district-dropdown-${_province ?? 'none'}'),
                    initialValue:
                        _province == null ||
                            !(NepalDistrictDirectory
                                        .districtsByProvince[_province] ??
                                    const <String>[])
                                .contains(_selectedDistrict)
                        ? null
                        : _selectedDistrict,
                    decoration: const InputDecoration(
                      labelText: 'District name',
                      prefixIcon: Icon(Icons.location_on, color: purple),
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select a district'),
                    items:
                        (NepalDistrictDirectory
                                    .districtsByProvince[_province] ??
                                const <String>[])
                            .map(
                              (district) => DropdownMenuItem(
                                value: district,
                                child: Text(district),
                              ),
                            )
                            .toList(),
                    onChanged: _province == null
                        ? null
                        : (value) => setState(() {
                            _selectedDistrict = value;
                            _legacyDistrictIssue = null;
                          }),
                    validator: (value) =>
                        DistrictFormRules.validateDistrict(value, _province),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('district-description-field'),
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        DistrictFormRules.validateRequiredText(
                          value,
                          'Description',
                        ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Experience types',
                    style: TextStyle(
                      color: maroon,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose one or more categories.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  FormField<List<String>>(
                    key: const Key('district-experience-types-field'),
                    initialValue: _experienceTypes,
                    validator: (values) =>
                        DistrictFormRules.validateExperienceTypes(
                          values ?? const [],
                        ),
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: DistrictFormRules.experienceCategories
                              .map(
                                (category) => FilterChip(
                                  label: Text(category),
                                  selected: _experienceTypes.contains(category),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _experienceTypes.add(category);
                                      } else {
                                        _experienceTypes.remove(category);
                                      }
                                    });
                                    field.didChange(_experienceTypes);
                                  },
                                  selectedColor: const Color(0xFFF1DCE4),
                                  checkmarkColor: maroon,
                                ),
                              )
                              .toList(),
                        ),
                        // Legacy unsupported selections remain visible so an
                        // editor can remove them instead of silently losing data.
                        ..._experienceTypes
                            .where(
                              (value) => !DistrictFormRules.experienceCategories
                                  .contains(value),
                            )
                            .map(
                              (value) => InputChip(
                                label: Text('Unsupported: $value'),
                                onDeleted: () {
                                  setState(
                                    () => _experienceTypes.remove(value),
                                  );
                                  field.didChange(_experienceTypes);
                                },
                              ),
                            ),
                        if (field.errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 12),
                            child: Text(
                              field.errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.previewOnly
                        ? 'This form only previews the district. Saving to '
                              'Firestore is disabled in the current app runtime.'
                        : 'This form submits through the injected district '
                              'service.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    key: const Key('district-preview-button'),
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: maroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(widget.submitLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
