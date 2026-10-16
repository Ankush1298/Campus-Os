import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/stamp_settings.dart';

Future<StampSettings?> showGeoCamSettingsSheet(
  BuildContext context, {
  required StampSettings initialSettings,
  ValueChanged<StampSettings>? onSettingsChanged,
}) async {
  final result = await showModalBottomSheet<StampSettings>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => GeoCamSettingsSheet(initial: initialSettings),
  );
  if (result != null && onSettingsChanged != null) {
    onSettingsChanged(result);
  }
  return result;
}

class GeoCamSettingsSheet extends StatefulWidget {
  final StampSettings initial;
  const GeoCamSettingsSheet({super.key, required this.initial});

  @override
  State<GeoCamSettingsSheet> createState() => _GeoCamSettingsSheetState();
}

class _GeoCamSettingsSheetState extends State<GeoCamSettingsSheet> {
  late StampSettings _settings;
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _settings = widget.initial.copy();
    _customController = TextEditingController(text: _settings.customText);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Widget _switch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      value: value,
      activeTrackColor: AppColors.primary,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                const Text(
                  'Stamp Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Customize the cryptographic stamp burned into captured media pixels.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const Divider(height: 24),
            _switch(
              'Coordinates',
              'Burn GPS latitude & longitude into output image',
              _settings.showCoordinates,
              (v) => setState(() => _settings.showCoordinates = v),
            ),
            _switch(
              'Address',
              'Burn reverse-geocoded location into output image',
              _settings.showAddress,
              (v) => setState(() => _settings.showAddress = v),
            ),
            _switch(
              'Date & Time',
              'Burn capture timestamp into output image',
              _settings.showDateTime,
              (v) => setState(() => _settings.showDateTime = v),
            ),
            _switch(
              'GPS Accuracy',
              'Burn estimated GPS accuracy (±m) into output image',
              _settings.showAccuracy,
              (v) => setState(() => _settings.showAccuracy = v),
            ),
            _switch(
              'QR Code',
              'Burn scannable verification QR into output image',
              _settings.showQr,
              (v) => setState(() => _settings.showQr = v),
            ),
            _switch(
              'Pixel-Embedded Stamp',
              'Burn cryptographic metadata directly into photo pixels',
              _settings.pixelEmbeddedStamps,
              (v) => setState(() => _settings.pixelEmbeddedStamps = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customController,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: 'Custom Stamp Header',
                hintText: 'e.g. CAMPUS INSPECTION / LAB AUDIT',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => _settings.customText = v,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, _settings),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save Stamp Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
