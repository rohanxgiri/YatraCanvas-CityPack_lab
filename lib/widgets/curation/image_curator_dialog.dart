import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/lab_theme.dart';
import '../../curation/curated_image_import_service.dart';
import '../../domain/curation/curated_place.dart';

class ImageImportSelection {
  final Uint8List bytes;
  final String filename;
  final String source;
  final String sourcePage;
  final String license;
  final String licenseUrl;

  const ImageImportSelection({
    required this.bytes,
    required this.filename,
    required this.source,
    required this.sourcePage,
    required this.license,
    required this.licenseUrl,
  });
}

class ImageFileSelection {
  final Uint8List bytes;
  final String filename;

  const ImageFileSelection({required this.bytes, required this.filename});
}

class ImageCuratorDialog extends StatefulWidget {
  final CuratedPlace place;
  final Future<ImageFileSelection?> Function()? pickFile;
  final Future<void> Function(ImageImportSelection selection) onImport;
  final Future<void> Function({
    required String? primaryImagePath,
    required String evidenceSource,
  })
  onSave;
  final Future<void> Function(String issueType, String note) onFlag;

  const ImageCuratorDialog({
    super.key,
    required this.place,
    this.pickFile,
    required this.onImport,
    required this.onSave,
    required this.onFlag,
  });

  static Future<void> show(
    BuildContext context, {
    required CuratedPlace place,
    required Future<void> Function(ImageImportSelection selection) onImport,
    required Future<void> Function({
      required String? primaryImagePath,
      required String evidenceSource,
    })
    onSave,
    required Future<void> Function(String issueType, String note) onFlag,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ImageCuratorDialog(
        place: place,
        onImport: onImport,
        onSave: onSave,
        onFlag: onFlag,
      ),
    );
  }

  @override
  State<ImageCuratorDialog> createState() => _ImageCuratorDialogState();
}

class _ImageCuratorDialogState extends State<ImageCuratorDialog> {
  static const _licenseUrls = <String, String>{
    'CC BY-SA 4.0': 'https://creativecommons.org/licenses/by-sa/4.0/',
    'CC BY 4.0': 'https://creativecommons.org/licenses/by/4.0/',
    'CC0 / Public Domain': 'https://creativecommons.org/publicdomain/zero/1.0/',
    'Contributor owned': '',
  };

  final _sourceController = TextEditingController();
  final _sourcePageController = TextEditingController();
  String _selectedLicense = 'CC BY-SA 4.0';
  Uint8List? _selectedBytes;
  String? _selectedFilename;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _sourceController.dispose();
    _sourcePageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _errorMessage = null);
    try {
      final selection = await (widget.pickFile?.call() ?? _pickLocalImage());
      if (selection == null) return;
      final bytes = selection.bytes;
      if (!mounted) return;
      if (bytes.length > CuratedImageImportService.maximumSourceBytes) {
        setState(
          () => _errorMessage =
              'That file is larger than 25 MB. Choose a smaller image.',
        );
        return;
      }
      setState(() {
        _selectedBytes = bytes;
        _selectedFilename = selection.filename;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'The photo could not be opened: $error');
    }
  }

  Future<ImageFileSelection?> _pickLocalImage() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a hero photo',
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    );
    if (file == null) return null;
    return ImageFileSelection(
      bytes: await file.readAsBytes(),
      filename: file.name,
    );
  }

  Future<void> _importImage() async {
    final bytes = _selectedBytes;
    final filename = _selectedFilename;
    if (bytes == null || filename == null) {
      setState(() => _errorMessage = 'Choose a photo to continue.');
      return;
    }
    if (_sourceController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Add the image source to continue.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.onImport(
        ImageImportSelection(
          bytes: bytes,
          filename: filename,
          source: _sourceController.text.trim(),
          sourcePage: _sourcePageController.text.trim(),
          license: _selectedLicense,
          licenseUrl: _licenseUrls[_selectedLicense] ?? '',
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ImageImportException catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'The photo could not be imported: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.place.hasImage;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        LabSpacing.lg,
        LabSpacing.lg,
        LabSpacing.lg,
        0,
      ),
      contentPadding: const EdgeInsets.all(LabSpacing.lg),
      actionsPadding: const EdgeInsets.fromLTRB(
        LabSpacing.lg,
        0,
        LabSpacing.lg,
        LabSpacing.lg,
      ),
      title: Row(
        children: [
          const CircleAvatar(
            backgroundColor: LabPalette.tealSoft,
            foregroundColor: LabPalette.teal,
            child: Icon(Icons.add_photo_alternate_outlined),
          ),
          const SizedBox(width: LabSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasImage ? 'Review or replace photo' : 'Add a hero photo'),
                Text(
                  widget.place.name,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kIsWeb)
                const _ModeNotice(
                  icon: Icons.desktop_windows_outlined,
                  title: 'Photo import is a desktop task',
                  message: 'This browser build can review and flag photos, but it cannot write Git tracked city pack files. Open the Windows app to import a photo.',
                )
              else ...[
                _ImageDropZone(
                  bytes: _selectedBytes,
                  filename: _selectedFilename,
                  onPick: _isSaving ? null : _pickImage,
                ),
                const SizedBox(height: LabSpacing.lg),
                Text(
                  'Photo credit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: LabSpacing.sm),
                TextField(
                  controller: _sourceController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Source',
                    hintText: 'Wikimedia Commons, official tourism board, or own work',
                  ),
                ),
                const SizedBox(height: LabSpacing.sm),
                TextField(
                  controller: _sourcePageController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Source page or evidence URL',
                    hintText: 'Optional for contributor owned work',
                  ),
                ),
                const SizedBox(height: LabSpacing.sm),
                _buildLicenseField(),
                const SizedBox(height: LabSpacing.sm),
                Text(
                  'The app creates a 1600 px primary WebP, a 480 px thumbnail, and a Git tracked attribution record. The source database remains unchanged.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: LabSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(LabSpacing.sm),
                    decoration: BoxDecoration(
                      color: LabPalette.dangerSoft,
                      borderRadius: BorderRadius.circular(LabRadius.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: LabPalette.danger,
                        ),
                        const SizedBox(width: LabSpacing.xs),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: LabPalette.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (hasImage) ...[
                const SizedBox(height: LabSpacing.lg),
                const Divider(),
                const SizedBox(height: LabSpacing.sm),
                Text(
                  'Current photo review',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: LabSpacing.xs),
                Wrap(
                  spacing: LabSpacing.xs,
                  runSpacing: LabSpacing.xs,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              await widget.onSave(
                                primaryImagePath: widget.place.primaryImagePath,
                                evidenceSource: 'Human reviewer confirmed the image matches the destination',
                              );
                              if (context.mounted) Navigator.of(context).pop();
                            },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark correct'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              await widget.onFlag(
                                'wrong_image',
                                'Image depicts the wrong place',
                              );
                              if (context.mounted) Navigator.of(context).pop();
                            },
                      icon: const Icon(Icons.wrong_location_outlined),
                      label: const Text('Wrong place'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              await widget.onFlag(
                                'wrong_image',
                                'Image is blurry, low resolution, or watermarked',
                              );
                              if (context.mounted) Navigator.of(context).pop();
                            },
                      icon: const Icon(Icons.blur_off_outlined),
                      label: const Text('Poor quality'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (hasImage)
          TextButton(
            onPressed: _isSaving
                ? null
                : () async {
                    await widget.onSave(
                      primaryImagePath: '',
                      evidenceSource:
                          'Removed an inappropriate or broken image',
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
            style: TextButton.styleFrom(foregroundColor: LabPalette.danger),
            child: const Text('Remove current'),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!kIsWeb)
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _importImage,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_upload_outlined),
            label: Text(_isSaving ? 'Importing…' : 'Import photo'),
          ),
      ],
    );
  }

  Widget _buildLicenseField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedLicense,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Licence'),
      items: _licenseUrls.keys
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              if (value != null) {
                setState(() => _selectedLicense = value);
              }
            },
    );
  }
}

class _ModeNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ModeNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LabSpacing.md),
      decoration: BoxDecoration(
        color: LabPalette.saffronSoft,
        borderRadius: BorderRadius.circular(LabRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: LabPalette.ink),
          const SizedBox(width: LabSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: LabSpacing.xxs),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageDropZone extends StatelessWidget {
  final Uint8List? bytes;
  final String? filename;
  final VoidCallback? onPick;

  const _ImageDropZone({
    required this.bytes,
    required this.filename,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: LabPalette.tealSoft,
        borderRadius: BorderRadius.circular(LabRadius.md),
        border: Border.all(color: LabPalette.teal),
      ),
      child: bytes == null
          ? Padding(
              padding: const EdgeInsets.all(LabSpacing.xl),
              child: Column(
                children: [
                  const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 44,
                    color: LabPalette.teal,
                  ),
                  const SizedBox(height: LabSpacing.sm),
                  Text(
                    'Choose a clear, representative photo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: LabSpacing.xxs),
                  const Text(
                    'JPG, PNG, or WebP · up to 25 MB · at least 640 × 480',
                  ),
                  const SizedBox(height: LabSpacing.md),
                  ElevatedButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Choose photo'),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(
                    bytes!,
                    fit: BoxFit.cover,
                    semanticLabel: 'Selected photo preview',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(LabSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: LabPalette.success),
                      const SizedBox(width: LabSpacing.xs),
                      Expanded(
                        child: Text(filename!, overflow: TextOverflow.ellipsis),
                      ),
                      TextButton(
                        onPressed: onPick,
                        child: const Text('Choose another'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
