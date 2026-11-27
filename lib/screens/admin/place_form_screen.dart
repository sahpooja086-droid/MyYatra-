import 'package:flutter/material.dart';

import '../../data/nepal_district_directory.dart';
import '../../models/district_model.dart';
import '../../models/place_model.dart';
import '../../services/place_data_validator.dart';
import '../../services/place_service.dart';

class PlaceFormScreen extends StatefulWidget {
  const PlaceFormScreen({
    required this.districts,
    this.place,
    this.onSave,
    super.key,
  });

  final List<DistrictModel> districts;
  final PlaceModel? place;
  final Future<void> Function(PlaceModel)? onSave;

  bool get isEditing => place != null;

  @override
  State<PlaceFormScreen> createState() => _PlaceFormScreenState();
}

class _PlaceFormScreenState extends State<PlaceFormScreen> {
  static const Color maroon = Color(0xFF8E2442);
  static const Color cream = Color(0xFFFFF9E9);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  String? _districtId;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.place?.name ?? '');
    _categoryController = TextEditingController(
      text: widget.place?.category ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.place?.description ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.place?.imageUrl ?? '',
    );
    final existingDistrictId = widget.place?.districtId;
    if (existingDistrictId != null &&
        widget.districts.any(
          (district) =>
              district.id == existingDistrictId && _isCanonical(district),
        )) {
      _districtId = existingDistrictId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    try {
      final place = PlaceDataValidator.normalize(
        PlaceModel(
          id: widget.place?.id ?? '',
          name: _nameController.text,
          category: _categoryController.text,
          districtId: _districtId ?? '',
          description: _descriptionController.text,
          imageUrl: _imageUrlController.text,
          updatedAt: widget.place?.updatedAt,
        ),
        districts: widget.districts,
        isCreate: !widget.isEditing,
      );
      final save = widget.onSave;
      if (save != null) {
        setState(() {
          _saving = true;
          _saveError = null;
        });
        await save(place);
        if (!mounted) return;
      }
      Navigator.of(context).pop(place);
    } on PlaceValidationException catch (error) {
      if (widget.onSave == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      } else if (mounted) {
        setState(() => _saveError = error.message);
      }
    } on PlaceServiceException catch (error) {
      if (mounted) setState(() => _saveError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = 'Could not save the place. Try again.');
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.onSave != null;
    final identityLocked = isLive && widget.isEditing;
    final selectedDistrictExists = widget.districts.any(
      (district) =>
          district.id == widget.place?.districtId && _isCanonical(district),
    );

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: cream,
        appBar: AppBar(
          backgroundColor: maroon,
          foregroundColor: Colors.white,
          title: Text(widget.isEditing ? 'Edit Place' : 'Add Place'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Place details',
                  style: TextStyle(
                    color: maroon,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLive
                      ? 'Changes are saved to the demo emulator.'
                      : 'Preview only: place data is not saved to Firestore.',
                  style: const TextStyle(color: maroon),
                ),
                if (widget.isEditing && !selectedDistrictExists) ...[
                  const SizedBox(height: 12),
                  Text(
                    isLive
                        ? 'This place needs review because its district is unavailable.'
                        : 'This place has a missing or unsupported district. Choose a '
                              'valid district before previewing changes.',
                    key: const Key('place-legacy-district-warning'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('place-name-field'),
                  controller: _nameController,
                  readOnly: identityLocked || _saving,
                  maxLength: PlaceDataValidator.maxNameLength,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Place name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Place name is required.'
                      : value.trim().length > PlaceDataValidator.maxNameLength
                      ? 'Place name must be 120 characters or fewer.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('place-category-field'),
                  controller: _categoryController,
                  enabled: !_saving,
                  maxLength: PlaceDataValidator.maxCategoryLength,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Category is required.'
                      : value.trim().length >
                            PlaceDataValidator.maxCategoryLength
                      ? 'Category must be 80 characters or fewer.'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('place-district-field'),
                  initialValue: _districtId,
                  decoration: const InputDecoration(
                    labelText: 'District',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.districts
                      .where(_isCanonical)
                      .map(
                        (district) => DropdownMenuItem(
                          value: district.id,
                          child: Text(
                            '${district.name} (${district.province})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: identityLocked || _saving
                      ? null
                      : (value) => setState(() => _districtId = value),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Select a district.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('place-image-url-field'),
                  controller: _imageUrlController,
                  enabled: !_saving,
                  maxLength: PlaceDataValidator.maxImageUrlLength,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional, HTTPS)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final url = value?.trim() ?? '';
                    if (url.isEmpty) return null;
                    final parsedUrl = Uri.tryParse(url);
                    if (url.length > PlaceDataValidator.maxImageUrlLength ||
                        parsedUrl == null ||
                        parsedUrl.scheme != 'https' ||
                        parsedUrl.host.isEmpty) {
                      return 'Enter a valid HTTPS image URL.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('place-description-field'),
                  controller: _descriptionController,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: PlaceDataValidator.maxDescriptionLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Description is required.'
                      : value.trim().length >
                            PlaceDataValidator.maxDescriptionLength
                      ? 'Description must be 2000 characters or fewer.'
                      : null,
                ),
                const SizedBox(height: 20),
                if (_saveError != null)
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ElevatedButton(
                  key: const Key('place-preview-button'),
                  onPressed:
                      _saving || (identityLocked && !selectedDistrictExists)
                      ? null
                      : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: maroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : isLive
                        ? 'Save Place'
                        : widget.isEditing
                        ? 'Preview Place Changes'
                        : 'Preview Place',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isCanonical(DistrictModel district) {
    final canonical = NepalDistrictDirectory.byId(district.id);
    return canonical != null &&
        district.name.trim() == canonical.name &&
        district.province.trim() == canonical.province;
  }
}
