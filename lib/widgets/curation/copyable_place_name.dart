import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/lab_theme.dart';

class CopyablePlaceName extends StatelessWidget {
  final String name;
  final String? address;

  const CopyablePlaceName({super.key, required this.name, this.address});

  Future<void> _copyName(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: name));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Copied "$name"')));
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SelectableText(name, style: titleStyle)),
            const SizedBox(width: LabSpacing.xs),
            OutlinedButton.icon(
              onPressed: () => _copyName(context),
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('Copy name'),
            ),
          ],
        ),
        if (address != null) ...[
          const SizedBox(height: LabSpacing.xxs),
          SelectableText(
            address!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
