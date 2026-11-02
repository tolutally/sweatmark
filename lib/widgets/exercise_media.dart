import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// An exercise demonstration. Catalog media is bundled as animated WebP
/// (scripts/build_exercise_media.py), so it shows instantly and offline; any
/// other URL, or a missing bundled file, falls back to the network cache.
/// Parameters mirror [CachedNetworkImage] so call sites stay unchanged.
class ExerciseMedia extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final Alignment alignment;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Duration fadeInDuration;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  const ExerciseMedia({
    super.key,
    required this.imageUrl,
    this.fit,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.placeholder,
    this.errorWidget,
  });

  static const _release = '@v1.1.0/';

  /// Bundled asset for an ExerciseGymGifsDB URL, e.g.
  /// `…@v1.1.0/biceps/barbell-curl.gif` → `assets/exercises/media/biceps__barbell-curl.webp`.
  /// Older history entries keep their original URL and resolve the same way.
  static String? assetFor(String url) {
    final start = url.indexOf(_release);
    if (start < 0 || !url.endsWith('.gif')) return null;
    final id = url.substring(start + _release.length, url.length - 4);
    return 'assets/exercises/media/${id.replaceAll('/', '__')}.webp';
  }

  Widget _network(BuildContext context) => CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        alignment: alignment,
        color: color,
        colorBlendMode: colorBlendMode,
        fadeInDuration: fadeInDuration,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );

  @override
  Widget build(BuildContext context) {
    final asset = assetFor(imageUrl);
    if (asset == null) return _network(context);
    return Image.asset(
      asset,
      fit: fit,
      alignment: alignment,
      color: color,
      colorBlendMode: colorBlendMode,
      gaplessPlayback: true,
      errorBuilder: (context, _, __) => _network(context),
    );
  }
}
