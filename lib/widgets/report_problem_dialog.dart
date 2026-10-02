import 'package:flutter/material.dart';

import 'dart:async';

import '../domain/lab_place.dart';
import '../domain/qa_issue.dart';

class ReportProblemDialog extends StatefulWidget {
  final LabPlace place;
  final String packVersion;
  final FutureOr<void> Function(QaIssue) onSubmit;
  final QaIssueType initialType;

  const ReportProblemDialog({
    super.key,
    required this.place,
    required this.packVersion,
    required this.onSubmit,
    this.initialType = QaIssueType.wrongCategory,
  });

  static Future<void> show(
    BuildContext context, {
    required LabPlace place,
    required String packVersion,
    required FutureOr<void> Function(QaIssue) onSubmit,
    QaIssueType initialType = QaIssueType.wrongCategory,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ReportProblemDialog(
        place: place,
        packVersion: packVersion,
        onSubmit: onSubmit,
        initialType: initialType,
      ),
    );
  }

  @override
  State<ReportProblemDialog> createState() => _ReportProblemDialogState();
}

class _ReportProblemDialogState extends State<ReportProblemDialog> {
  late QaIssueType _selectedType;
  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  final TextEditingController _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    final issue = QaIssue(
      id: 'qa_${widget.place.id}_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now().toIso8601String(),
      cityId: widget.place.cityId,
      packVersion: widget.packVersion,
      placeId: widget.place.id,
      placeName: widget.place.name,
      tier: widget.place.tier,
      category: widget.place.category,
      latitude: widget.place.latitude,
      longitude: widget.place.longitude,
      issueType: _selectedType,
      note: _noteController.text.trim(),
    );

    try {
      await widget.onSubmit(issue);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Issue could not be saved: $e. Please retry.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reported "${_selectedType.label}" for ${widget.place.name}',
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.report_problem_outlined, color: Colors.red.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Report QA Issue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.place.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'ID: ${widget.place.id} • Tier: ${widget.place.tier}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Divider(height: 24),
              const Text(
                'Select Issue Type:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<QaIssueType>(
                initialValue: _selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: QaIssueType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      type.label,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedType = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Tester Notes / Evidence:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Actually a souvenir store, wrong pin location, duplicate of ...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save Issue'),
        ),
      ],
    );
  }
}
