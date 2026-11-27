import 'package:flutter/material.dart';

import '../../models/journal_entry_model.dart';
import '../../services/personal_travel_service.dart';
import '../auth/auth_widgets.dart';
import '../common/app_ui.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, this.service});

  final PersonalTravelService? service;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late final PersonalTravelService _service =
      widget.service ?? PersonalTravelService();

  Future<void> _openForm([JournalEntryModel? existing]) async {
    final entry = await showDialog<JournalEntryModel>(
      context: context,
      builder: (_) => _JournalFormDialog(existing: existing),
    );
    if (entry == null) return;
    try {
      if (existing == null) {
        await _service.addJournalEntry(entry);
      } else {
        await _service.updateJournalEntry(entry);
      }
    } catch (error) {
      _show(error);
    }
  }

  Future<void> _delete(JournalEntryModel entry) async {
    if (!await confirmDelete(context, 'this journal entry')) return;
    try {
      await _service.deleteJournalEntry(entry.id);
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
      title: 'My journal',
      floatingActionButton: FloatingActionButton(
        backgroundColor: AuthPalette.maroon,
        foregroundColor: Colors.white,
        onPressed: _openForm,
        tooltip: 'Add journal entry',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<JournalEntryModel>>(
        stream: _service.watchJournalEntries(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorView(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const AppEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Your journal is empty',
              message: 'Write down a memory from your travels.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(
                    Icons.menu_book,
                    color: AuthPalette.purple,
                  ),
                  title: Text(
                    entry.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${formatDate(entry.entryDate)}'
                    '${entry.districtId.isEmpty ? '' : ' · ${entry.districtId}'}'
                    '${entry.body.isEmpty ? '' : '\n${entry.body}'}',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: entry.body.isNotEmpty,
                  onTap: () => _openForm(entry),
                  trailing: IconButton(
                    tooltip: 'Delete journal entry',
                    onPressed: () => _delete(entry),
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
    );
  }
}

class _JournalFormDialog extends StatefulWidget {
  const _JournalFormDialog({this.existing});

  final JournalEntryModel? existing;

  @override
  State<_JournalFormDialog> createState() => _JournalFormDialogState();
}

class _JournalFormDialogState extends State<_JournalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _bodyController = TextEditingController(
    text: widget.existing?.body ?? '',
  );
  late final _districtController = TextEditingController(
    text: widget.existing?.districtId ?? '',
  );
  late DateTime _entryDate = widget.existing?.entryDate ?? DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existing;
    final entry = JournalEntryModel(
      id: existing?.id ?? '',
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      placeId: existing?.placeId ?? '',
      districtId: _districtController.text.trim(),
      entryDate: _entryDate,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
    );
    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New entry' : 'Edit entry'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title'
                    : null,
              ),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: 'Entry'),
                maxLines: 5,
              ),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(
                  labelText: 'District (optional)',
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _entryDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _entryDate = picked);
                  },
                  child: Text('Date: ${formatDate(_entryDate)}'),
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
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
