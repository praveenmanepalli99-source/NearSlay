import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';

class AvatarHelper {
  static const String defaultAvatar =
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200';

  static final List<String> sampleAvatars = [
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
    'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
    'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=200',
    'https://images.unsplash.com/photo-1566492031773-4f4e44671857?w=200',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
    'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=200',
    'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=200',
  ];

  static final Map<String, ImageProvider> _imageCache = {};

  /// Returns the appropriate ImageProvider based on whether the string is a URL, Base64, or File path
  static ImageProvider getImageProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      return const NetworkImage(defaultAvatar);
    }

    final trimmed = avatarUrl.trim();
    if (_imageCache.containsKey(trimmed)) {
      return _imageCache[trimmed]!;
    }

    ImageProvider provider;
    // 1. Base64 Data URI or raw Base64 string
    if (trimmed.startsWith('data:image/') || (trimmed.length > 200 && !trimmed.startsWith('http') && !trimmed.startsWith('/'))) {
      try {
        final commaIndex = trimmed.indexOf(',');
        final base64String = commaIndex != -1 ? trimmed.substring(commaIndex + 1) : trimmed;
        provider = MemoryImage(base64Decode(base64String));
      } catch (_) {
        provider = const NetworkImage(defaultAvatar);
      }
    } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      provider = NetworkImage(trimmed);
    } else if (!kIsWeb) {
      try {
        final file = File(trimmed);
        if (file.existsSync()) {
          provider = FileImage(file);
        } else {
          provider = const NetworkImage(defaultAvatar);
        }
      } catch (_) {
        provider = const NetworkImage(defaultAvatar);
      }
    } else {
      provider = const NetworkImage(defaultAvatar);
    }

    if (_imageCache.length > 100) {
      _imageCache.clear();
    }
    _imageCache[trimmed] = provider;
    return provider;
  }

  /// Show image picker bottom sheet allowing user to choose from Gallery, Camera, or Presets
  static Future<String?> showImageSourceDialog({
    required BuildContext context,
    required String currentAvatar,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Update Profile Picture',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gallery Option
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 22),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: const Text('Pick any photo stored on your device', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 400,
                    maxHeight: 400,
                    imageQuality: 80,
                  );
                  if (picked != null) {
                    final bytes = await picked.readAsBytes();
                    final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                    if (context.mounted) {
                      Navigator.of(context).pop(base64String);
                    }
                  }
                },
              ),
              const Divider(height: 16),

              // Camera Option
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.amber.shade800, size: 22),
                ),
                title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: const Text('Use your camera to click a new portrait', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 400,
                    maxHeight: 400,
                    imageQuality: 80,
                  );
                  if (picked != null) {
                    final bytes = await picked.readAsBytes();
                    final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                    if (context.mounted) {
                      Navigator.of(context).pop(base64String);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
