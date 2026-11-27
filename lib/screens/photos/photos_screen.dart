import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/photo_model.dart';
import '../../services/personal_travel_service.dart';
import '../auth/auth_widgets.dart';
import '../common/app_ui.dart';

class PhotoPickerResult {
  const PhotoPickerResult({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

typedef PhotoPicker = Future<PhotoPickerResult?> Function();

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key, this.service, this.picker});

  final PersonalTravelService? service;
  final PhotoPicker? picker;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  late final PersonalTravelService _service =
      widget.service ?? PersonalTravelService();

  PhotoPicker get _picker => widget.picker ?? _pickWithImagePicker;

  Future<PhotoPickerResult?> _pickWithImagePicker() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final name = file.name;
    final extension = name.toLowerCase().split('.').last;
    final contentType = switch (extension) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    return PhotoPickerResult(
      bytes: await file.readAsBytes(),
      fileName: name,
      contentType: contentType,
    );
  }

  Future<void> _addPhoto() async {
    final draft = await showDialog<_PhotoDraft>(
      context: context,
      builder: (_) => _PhotoFormDialog(picker: _picker),
    );
    if (draft == null) return;
    try {
      await _service.addPhoto(
        bytes: draft.picked.bytes,
        fileName: draft.picked.fileName,
        contentType: draft.picked.contentType,
        caption: draft.caption,
        placeId: draft.placeId,
        districtId: draft.districtId,
        capturedAt: draft.capturedAt,
      );
    } catch (error) {
      _show(error);
    }
  }

  Future<void> _delete(PhotoModel photo) async {
    if (!await confirmDelete(context, 'this photo')) return;
    try {
      await _service.deletePhoto(photo);
    } catch (error) {
      _show(error);
    }
  }

  void _show(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSectionScaffold(
      title: 'My photos',
      floatingActionButton: FloatingActionButton(
        backgroundColor: AuthPalette.maroon,
        foregroundColor: Colors.white,
        onPressed: _addPhoto,
        tooltip: 'Add photo',
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: StreamBuilder<List<PhotoModel>>(
        stream: _service.watchPhotos(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorView(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final photos = snapshot.data!;
          if (photos.isEmpty) {
            return const AppEmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No photos yet',
              message:
                  'Photos are stored in your private folder and are hidden '
                  'from every other account.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                color: Colors.white,
                child: InkWell(
                  onTap: () => _delete(photo),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: photo.downloadUrl.isEmpty
                            ? const ColoredBox(
                                color: Color(0xFFF4EDF8),
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AuthPalette.purple,
                                ),
                              )
                            : Image.network(
                                photo.downloadUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Color(0xFFF4EDF8),
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: AuthPalette.purple,
                                  ),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              photo.caption.isEmpty
                                  ? 'Untitled photo'
                                  : photo.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              formatDate(photo.capturedAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AuthPalette.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PhotoDraft {
  const _PhotoDraft({
    required this.picked,
    required this.caption,
    required this.placeId,
    required this.districtId,
    required this.capturedAt,
  });

  final PhotoPickerResult picked;
  final String caption;
  final String placeId;
  final String districtId;
  final DateTime capturedAt;
}

class _PhotoFormDialog extends StatefulWidget {
  const _PhotoFormDialog({required this.picker});

  final PhotoPicker picker;

  @override
  State<_PhotoFormDialog> createState() => _PhotoFormDialogState();
}

class _PhotoFormDialogState extends State<_PhotoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final _placeController = TextEditingController();
  final _districtController = TextEditingController();
  PhotoPickerResult? _picked;
  DateTime _capturedAt = DateTime.now();
  bool _picking = false;

  @override
  void dispose() {
    _captionController.dispose();
    _placeController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final result = await widget.picker();
      if (mounted && result != null) setState(() => _picked = result);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final picked = _picked;
    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an image first.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _PhotoDraft(
        picked: picked,
        caption: _captionController.text.trim(),
        placeId: _placeController.text.trim(),
        districtId: _districtController.text.trim(),
        capturedAt: _capturedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a photo'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _picking ? null : _pick,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _picked == null
                      ? 'Choose image'
                      : 'Choose a different image',
                ),
              ),
              if (_picked != null)
                Text(
                  _picked!.fileName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AuthPalette.mutedText,
                  ),
                ),
              TextFormField(
                controller: _captionController,
                decoration: const InputDecoration(labelText: 'Caption'),
              ),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(
                  labelText: 'District (optional)',
                ),
              ),
              TextFormField(
                controller: _placeController,
                decoration: const InputDecoration(
                  labelText: 'Place ID (optional)',
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _capturedAt,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _capturedAt = picked);
                  },
                  child: Text('Taken: ${formatDate(_capturedAt)}'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Upload')),
      ],
    );
  }
}
