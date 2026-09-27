import 'package:flutter/material.dart';
import '../domain/lab_place.dart';
import '../domain/qa_issue.dart';

class ReportProblemDialog extends StatefulWidget {
  final LabPlace place;
  final String packVersion;
  final Function(QaIssue) onSubmit;

  const ReportProblemDialog({
    super.key,
    required this.place,
    required this.packVersion,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required LabPlace place,
    required String packVersion,
    required Function(QaIssue) onSubmit,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ReportProblemDialog(
        place: place,
        packVersion: packVersion,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<ReportProblemDialog> createState() => _ReportProblemDialogState();
}

class _ReportProblemDialogState extends State<ReportProblemDialog> {
  QaIssueType _selectedType = QaIssueType.wrongCategory;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
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

    widget.onSubmit(issue);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reported "${_selectedType.label}" for ${widget.place.name}'),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: QaIssueType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.label, style: const TextStyle(fontSize: 13)),
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
          onPressed: _submit,
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
