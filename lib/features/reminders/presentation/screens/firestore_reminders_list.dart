import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/glass_card.dart';

class FirestoreRemindersList extends ConsumerWidget {
  const FirestoreRemindersList({super.key});

  void _showAddReminderDialog(BuildContext context) {
    _showReminderDialog(context, null, null, null);
  }

  void _showEditReminderDialog(
    BuildContext context,
    String docId,
    String currentTitle,
    String currentDesc,
  ) {
    _showReminderDialog(context, docId, currentTitle, currentDesc);
  }

  void _showReminderDialog(
    BuildContext context,
    String? docId,
    String? initialTitle,
    String? initialDesc,
  ) {
    final titleCtrl = TextEditingController(text: initialTitle ?? '');
    final descCtrl = TextEditingController(text: initialDesc ?? '');
    final isEdit = docId != null;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Reminder' : 'Add Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final desc = descCtrl.text.trim();
                if (title.isEmpty) return;
                if (isEdit) {
                  await FirebaseService.instance.updateReminder(docId, {
                    'title': title,
                    'description': desc,
                  });
                } else {
                  await FirebaseService.instance.addReminder(
                    title: title,
                    description: desc,
                  );
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = FirebaseService.instance.userId;
    if (userId == null) {
      return const GlassCard(
        padding: EdgeInsets.all(16),
        child: Text('Sign in to view reminders.'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseService.instance.streamReminders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const GlassCard(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (snapshot.hasError) {
          return GlassCard(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reminders',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: () => _showAddReminderDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const GlassCard(
                padding: EdgeInsets.all(16),
                child: Text('No reminders yet.'),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title'] ?? 'Untitled',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['description'] ?? '',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.accent,
                            size: 20,
                          ),
                          onPressed: () {
                            _showEditReminderDialog(
                              context,
                              doc.id,
                              data['title'] ?? '',
                              data['description'] ?? '',
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          onPressed: () async {
                            await FirebaseService.instance.deleteReminder(
                              doc.id,
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
