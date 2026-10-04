import 'package:flutter/material.dart';

import '../../domain/curation/curated_place.dart';

class OpeningHoursEditorDialog extends StatefulWidget {
  const OpeningHoursEditorDialog({
    required this.place,
    required this.onSave,
    super.key,
  });
  final CuratedPlace place;
  final Function({required String openingHours, required String evidenceSource})
  onSave;
  static Future<void> show(
    BuildContext context, {
    required CuratedPlace place,
    required Function({
      required String openingHours,
      required String evidenceSource,
    })
    onSave,
  }) => showDialog(
    context: context,
    builder: (_) => OpeningHoursEditorDialog(place: place, onSave: onSave),
  );
  @override
  State<OpeningHoursEditorDialog> createState() =>
      _OpeningHoursEditorDialogState();
}

class _OpeningHoursEditorDialogState extends State<OpeningHoursEditorDialog> {
  static const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const codes = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  late final TextEditingController _raw;
  final _source = TextEditingController();
  final _day = List.generate(7, (_) => TextEditingController());
  bool _weekly = false, _verified = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _raw = TextEditingController(text: widget.place.openingHours ?? '');
    _verified = widget.place.override?.openingHoursStatus == 'VERIFIED';
    _source.text = (widget.place.override?.fieldSources['opening_hours'] ?? '')
        .replaceFirst(RegExp(r'^(Verified|Unverified) hours:\s*'), '');
    for (final section in _raw.text.split(';')) {
      final match = RegExp(
        r'^\s*((?:Mo|Tu|We|Th|Fr|Sa|Su)(?:[-,](?:Mo|Tu|We|Th|Fr|Sa|Su))*)\s+(.+)\s*$',
      ).firstMatch(section);
      if (match == null || !_validDay(match[2]!.trim())) continue;
      for (final range in match[1]!.split(',')) {
        final limits = range.split('-');
        var index = codes.indexOf(limits.first);
        final last = codes.indexOf(limits.last);
        while (true) {
          _day[index].text = match[2]!.trim();
          if (index == last) break;
          index = (index + 1) % 7;
        }
      }
    }
  }

  @override
  void dispose() {
    _raw.dispose();
    _source.dispose();
    for (final c in _day) {
      c.dispose();
    }
    super.dispose();
  }

  String _weeklyValue() => List.generate(7, (i) {
    final text = _day[i].text.trim();
    return '${codes[i]} ${text.isEmpty || text.toLowerCase() == 'unknown'
        ? 'unknown'
        : text.toLowerCase() == 'closed'
        ? 'off'
        : text == '24 hours' || text == '24/7'
        ? '00:00-24:00'
        : text}';
  }).join('; ');
  bool _validDay(String text) {
    if ([
      '',
      'unknown',
      'closed',
      'off',
      '24 hours',
      '24/7',
    ].contains(text.toLowerCase())) {
      return true;
    }
    for (final interval in text.split(',')) {
      final match = RegExp(r'^\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*$')
          .firstMatch(interval);
      if (match == null) return false;
      final open = int.parse(match[1]!) * 60 + int.parse(match[2]!),
          close = int.parse(match[3]!) * 60 + int.parse(match[4]!);
      if (int.parse(match[2]!) > 59 ||
          int.parse(match[4]!) > 59 ||
          open >= 1440 ||
          close > 1440 ||
          close <= open) {
        return false;
      }
    }
    return true;
  }

  void _save() {
    if (_weekly && _day.any((c) => !_validDay(c.text.trim()))) {
      setState(
        () =>
            _error = 'Use HH:mm-HH:mm intervals, Closed, Unknown, or 24 hours.',
      );
      return;
    }
    final text = _weekly
        ? (_day.every(
                (c) =>
                    c.text.trim().isEmpty ||
                    c.text.trim().toLowerCase() == 'unknown',
              )
              ? ''
              : _weeklyValue())
        : _raw.text.trim();
    if (_verified && (text.isEmpty || _source.text.trim().isEmpty)) {
      setState(
        () => _error = 'Verified hours require a schedule and source evidence.',
      );
      return;
    }
    widget.onSave(
      openingHours: text,
      evidenceSource:
          '${_verified ? 'Verified hours:' : 'Unverified hours:'} ${_source.text.trim()}',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Opening hours: ${widget.place.name}'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Keep missing hours unknown. Include split intervals when the venue closes between sessions.',
            ),
            SwitchListTile(
              title: const Text('Edit a weekly schedule'),
              value: _weekly,
              onChanged: (v) => setState(() => _weekly = v),
            ),
            if (_weekly)
              ...List.generate(
                7,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _day[i],
                    decoration: InputDecoration(
                      labelText: days[i],
                      hintText: 'Unknown, Closed, 09:00-14:00,17:00-22:00',
                    ),
                  ),
                ),
              )
            else
              TextField(
                controller: _raw,
                decoration: const InputDecoration(
                  labelText: 'Source schedule',
                  helperText: 'Blank means unknown. Example: Mo-Su 09:00-17:00',
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _raw.text = '';
                    _weekly = false;
                    _verified = false;
                  }),
                  child: const Text('Set unknown'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _raw.text = '24/7';
                    _weekly = false;
                  }),
                  child: const Text('24 hours'),
                ),
              ],
            ),
            TextField(
              controller: _source,
              decoration: const InputDecoration(
                labelText: 'Source or evidence',
              ),
            ),
            CheckboxListTile(
              title: const Text('I verified this schedule against the source'),
              value: _verified,
              onChanged: (v) => setState(() => _verified = v ?? false),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save Correction')),
    ],
  );
}
