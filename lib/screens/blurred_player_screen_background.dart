import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:octo_image/octo_image.dart';

import '../services/current_album_image_provider.dart';

/// Same as [_PlayerScreenAlbumImage], but with a BlurHash instead. We also
/// filter the BlurHash so that it works as a background image.
class BlurredPlayerScreenBackground extends ConsumerWidget {
  /// should never be less than 1.0
  final double brightnessFactor;

  const BlurredPlayerScreenBackground({
    Key? key,
    this.brightnessFactor = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageProvider = ref.watch(currentAlbumImageProvider);

    return ClipRect(
      child: imageProvider == null
          ? const SizedBox.shrink()
          : OctoImage(
              image: imageProvider,
              fit: BoxFit.cover,
              placeholderBuilder: (_) => const SizedBox.shrink(),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              imageBuilder: (context, child) => ColorFiltered(
                colorFilter: ColorFilter.mode(
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withOpacity(0.675 / brightnessFactor)
                        : Colors.white.withOpacity(0.5 / brightnessFactor),
                    BlendMode.srcOver),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 85,
                    sigmaY: 85,
                    tileMode: TileMode.mirror,
                  ),
                  child: SizedBox.expand(child: child),
                ),
              ),
            ),
    );
  }
}
