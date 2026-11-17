import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';

/// Asks camera or gallery, then picks up to [remaining] photos. Resolves to
/// the picked files (possibly empty), or null when the person backed out.
/// Shows a snackbar when the picker failed or more were picked than fit.
Future<List<File>?> pickPhotos(BuildContext context, ImagePicker picker, {required int remaining, required int max}) async {
  if (remaining <= 0) return const <File>[];
  final messenger = ScaffoldMessenger.of(context);
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            subtitle: Text('Up to $remaining more'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final List<XFile> picked;
  try {
    // The picker rejects a limit under 2, so the last slot is a single pick.
    if (source == ImageSource.gallery && remaining >= 2) {
      picked = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 85, limit: remaining);
    } else {
      final single = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      picked = single == null ? const <XFile>[] : [single];
    }
  } on PlatformException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message ?? 'Could not open your photos.')));
    return null;
  }
  // Some platforms ignore the limit.
  final accepted = picked.take(remaining).map((file) => File(file.path)).toList();
  if (accepted.length < picked.length) {
    messenger.showSnackBar(SnackBar(
      content: Text('Only the first ${accepted.length} were added. You can add up to $max photos.'),
    ));
  }
  return accepted;
}

/// "Add Photos": a horizontal strip of picked photos, each with a × to
/// remove it, and an "+ Add Photo" tile until [max] is reached.
class PhotoPickerStrip extends StatelessWidget {
  const PhotoPickerStrip({
    super.key,
    required this.photos,
    required this.max,
    required this.onAdd,
    required this.onRemove,
    required this.helper,
    this.title = 'Add Photos',
  });

  static const double _tile = 84;

  final List<File> photos;
  final int max;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onRemove;
  final String title;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final canAdd = photos.length < max;
    final decodeWidth = (_tile * MediaQuery.devicePixelRatioOf(context)).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Wraps rather than overflows with a long title or large text.
            Expanded(
              child: Text(title, style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Text('${photos.length}/$max', style: const TextStyle(color: AppColors.gray, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(helper, style: const TextStyle(color: AppColors.gray, fontSize: 12)),
        const SizedBox(height: 10),
        SizedBox(
          height: _tile + 8,
          child: ListView(
            scrollDirection: Axis.horizontal,
            // Room for the remove badges that overhang each thumbnail's corner.
            padding: const EdgeInsets.only(top: 8, right: 8),
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          photos[i],
                          width: _tile,
                          height: _tile,
                          fit: BoxFit.cover,
                          cacheWidth: decodeWidth,
                          semanticLabel: 'Photo ${i + 1}',
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Material(
                          color: AppColors.black,
                          shape: const CircleBorder(side: BorderSide(color: AppColors.white, width: 2)),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onRemove == null ? null : () => onRemove!(i),
                            child: Semantics(
                              button: true,
                              label: 'Remove photo ${i + 1}',
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close, size: 14, color: AppColors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (canAdd)
                Material(
                  color: AppColors.softBackground,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: _tile,
                      height: _tile,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 24, color: AppColors.gray),
                          SizedBox(height: 4),
                          Text('+ Add Photo', style: TextStyle(color: AppColors.gray, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
