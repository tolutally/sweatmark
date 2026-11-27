import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';

/// Full-height sheet that previews [card] and shares it as a PNG. The
/// preview is the exported image, always drawn in the light theme.
Future<void> showShareImage(
  BuildContext context, {
  required String title,
  required String shareTitle,
  required String fileName,
  required Key previewKey,
  required Widget card,
  ShareCanvas? canvas,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: AppColors.ink,
      barrierColor: Colors.black54,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => FractionallySizedBox(
        heightFactor: .94,
        child: _ShareImageSheet(
            title: title,
            shareTitle: shareTitle,
            fileName: fileName,
            previewKey: previewKey,
            canvas: canvas,
            card: card),
      ),
    );

class _ShareImageSheet extends StatefulWidget {
  final String title, shareTitle, fileName;
  final Key previewKey;
  final Widget card;
  final ShareCanvas? canvas;
  const _ShareImageSheet(
      {required this.title,
      required this.shareTitle,
      required this.fileName,
      required this.previewKey,
      required this.card,
      this.canvas});

  @override
  State<_ShareImageSheet> createState() => _ShareImageSheetState();
}

class _ShareImageSheetState extends State<_ShareImageSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;
  String? _error;

  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing) return;
    final button = buttonContext.findRenderObject() as RenderBox?;
    final origin =
        button == null ? null : button.localToGlobal(Offset.zero) & button.size;
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      // Capture only the card, after the current frame has painted. Its eager
      // Column includes every row, even those below the viewport.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) {
        throw StateError('The card is not ready.');
      }
      final size = boundary.size;
      // Keep long images within a reasonable memory/texture budget.
      final canvas = widget.canvas;
      final ratio = canvas != null
          ? canvas.pixels.width / size.width
          : math.min(
              3.0,
              math.min(math.sqrt(12000000 / (size.width * size.height)),
                  8192 / math.max(size.width, size.height)));
      final image = await boundary.toImage(pixelRatio: ratio);
      // Release the native image even if PNG encoding fails.
      final bytes = await (() async {
        try {
          final encoded =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (encoded == null) throw StateError('Could not create the image.');
          return encoded.buffer
              .asUint8List(encoded.offsetInBytes, encoded.lengthInBytes);
        } finally {
          image.dispose();
        }
      })();
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(
        title: widget.shareTitle,
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: [widget.fileName],
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not share this image. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// A fixed canvas is laid out at its own size and scaled to fit the
  /// preview; the capture still uses the canvas size.
  Widget _fit(Widget child, double maxHeight) {
    final canvas = widget.canvas;
    if (canvas == null) return child;
    // Show the whole canvas on screen: as wide as fits within [maxHeight].
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: math.max(0, maxHeight) * canvas.layout.aspectRatio),
      child: AspectRatio(
          aspectRatio: canvas.layout.aspectRatio,
          child: FittedBox(child: child)),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_sharing,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              IconButton(
                tooltip: 'Close share preview',
                onPressed: _sharing ? null : () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .09),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white38,
                    minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.close_rounded, size: 25),
              ),
              Expanded(
                child: Text(widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 48),
            ]),
          ),
          Expanded(
            child: LayoutBuilder(builder: (_, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - 40)),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: KeyedSubtree(
                        key: widget.previewKey,
                        child: _fit(
                            RepaintBoundary(
                              key: _cardKey,
                              child: Theme(
                                // Export stays consistent in light and dark mode.
                                data: lightTheme,
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: widget.canvas == null
                                      ? widget.card
                                      : SizedBox.fromSize(
                                          size: widget.canvas!.layout,
                                          child: widget.card),
                                ),
                              ),
                            ),
                            constraints.maxHeight - 40),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
                border: Border(
                    top:
                        BorderSide(color: Colors.white.withValues(alpha: .1)))),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white)),
                  ),
                Builder(builder: (buttonContext) {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sharing ? null : () => _share(buttonContext),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: AppColors.lavender,
                          foregroundColor: AppColors.ink,
                          disabledBackgroundColor: AppColors.paleLavender,
                          disabledForegroundColor: AppColors.ink),
                      icon: _sharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.ink))
                          : const Icon(Icons.ios_share_rounded, size: 20),
                      label: Text(_sharing
                          ? 'Preparing image…'
                          : 'Share or save image'),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                const Text(
                    'Choose an app or save from your phone’s share menu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ),
        ]),
      );
}

/// A fixed-size export, such as a 9:16 story or reel image.
class ShareCanvas {
  /// Size the card is laid out at, in logical pixels.
  final Size layout;

  /// Size of the exported image, in pixels.
  final Size pixels;
  const ShareCanvas({required this.layout, required this.pixels});

  /// 1080 × 1920, the size Instagram and TikTok use for reels and stories.
  static const reel =
      ShareCanvas(layout: Size(360, 640), pixels: Size(1080, 1920));
}
