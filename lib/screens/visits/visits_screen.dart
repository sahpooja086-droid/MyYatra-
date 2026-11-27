import 'package:flutter/material.dart';

import '../../models/visit_model.dart';
import '../../services/personal_travel_service.dart';
import '../auth/auth_widgets.dart';
import '../common/app_ui.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key, this.service});

  final PersonalTravelService? service;

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  late final PersonalTravelService _service =
      widget.service ?? PersonalTravelService();

  Future<void> _addVisit() async {
    final visit = await showDialog<VisitModel>(
      context: context,
      builder: (_) => const _VisitFormDialog(),
    );
    if (visit == null) return;
    try {
      await _service.addVisit(visit);
    } catch (error) {
      _show(error);
    }
  }

  Future<void> _delete(VisitModel visit) async {
    if (!await confirmDelete(context, 'this visit')) return;
    try {
      await _service.deleteVisit(visit.id);
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
      title: 'My visits',
      floatingActionButton: FloatingActionButton(
        backgroundColor: AuthPalette.maroon,
        foregroundColor: Colors.white,
        onPressed: _addVisit,
        tooltip: 'Add visit',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const _PrivacyNotice(
            message:
                'Visits are private. Only you can open this list; other users '
                'cannot read or search it.',
          ),
          Expanded(
            child: StreamBuilder<List<VisitModel>>(
              stream: _service.watchVisits(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppErrorView(message: snapshot.error.toString());
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final visits = snapshot.data!;
                if (visits.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.map_outlined,
                    title: 'No visits yet',
                    message: 'Add the first place you explored.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: visits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final visit = visits[index];
                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: const Icon(
                          Icons.place,
                          color: AuthPalette.purple,
                        ),
                        title: Text(
                          visit.placeName.isEmpty
                              ? visit.placeId
                              : visit.placeName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${visit.districtId.isEmpty ? 'Unknown district' : visit.districtId}'
                          ' · ${formatDate(visit.visitedAt)}'
                          ' · ${visit.rating}/5'
                          '${visit.notes.isEmpty ? '' : '\n${visit.notes}'}',
                        ),
                        isThreeLine: visit.notes.isNotEmpty,
                        trailing: IconButton(
                          tooltip: 'Delete visit',
                          onPressed: () => _delete(visit),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AuthPalette.mutedText,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EDF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCCBE6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AuthPalette.maroon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AuthPalette.ink,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitFormDialog extends StatefulWidget {
  const _VisitFormDialog();

  @override
  State<_VisitFormDialog> createState() => _VisitFormDialogState();
}

class _VisitFormDialogState extends State<_VisitFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _placeController = TextEditingController();
  final _districtController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _visitedAt = DateTime.now();
  int _rating = 5;

  @override
  void dispose() {
    _placeController.dispose();
    _districtController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _slug(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final placeName = _placeController.text.trim();
    final districtId = _districtController.text.trim();
    Navigator.pop(
      context,
      VisitModel(
        id: '',
        placeId: districtId.isEmpty ? '' : '$districtId--${_slug(placeName)}',
        placeName: placeName,
        districtId: districtId,
        visitedAt: _visitedAt,
        notes: _notesController.text.trim(),
        rating: _rating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a visit'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _placeController,
                decoration: const InputDecoration(labelText: 'Place name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a place name'
                    : null,
              ),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(labelText: 'District'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a district'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Rating'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _rating,
                    onChanged: (value) =>
                        setState(() => _rating = value ?? _rating),
                    items: [
                      for (var i = 1; i <= 5; i++)
                        DropdownMenuItem(value: i, child: Text('$i')),
                    ],
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _visitedAt,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _visitedAt = picked);
                    },
                    child: Text(formatDate(_visitedAt)),
                  ),
                ],
              ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 3,
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
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
