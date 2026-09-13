import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

class ImageDerivativeSpec {
  final String key;
  final int maxDimension;
  final int quality;
  final int? maxBytes;
  const ImageDerivativeSpec({
    required this.key,
    required this.maxDimension,
    required this.quality,
    this.maxBytes,
  });
}

class ImageDerivativeCodec {
  const ImageDerivativeCodec();

  Future<Map<String, Uint8List>> resizeMany(
    Uint8List bytes,
    List<ImageDerivativeSpec> specs,
  ) async {
    try {
      return await compute(
        _resizeManyToJpeg,
        _ResizeManyRequest(bytes: bytes, specs: specs),
      );
    } catch (_) {
      return const {};
    }
  }
}

class _ResizeManyRequest {
  final Uint8List bytes;
  final List<ImageDerivativeSpec> specs;
  const _ResizeManyRequest({required this.bytes, required this.specs});
}

Map<String, Uint8List> _resizeManyToJpeg(_ResizeManyRequest request) {
  final result = <String, Uint8List>{};
  final img.Image? decoded = img.decodeImage(request.bytes);
  if (decoded == null) return result;

  for (final spec in request.specs) {
    try {
      final originalWidth = decoded.width;
      final originalHeight = decoded.height;

      Uint8List? encoded;
      final maxBytes = spec.maxBytes;

      if (maxBytes == null) {
        final longestSide = originalWidth > originalHeight
            ? originalWidth
            : originalHeight;
        final scale = longestSide > spec.maxDimension
            ? spec.maxDimension / longestSide
            : 1.0;
        final targetWidth = (originalWidth * scale).round().clamp(
          1,
          originalWidth,
        );
        final targetHeight = (originalHeight * scale).round().clamp(
          1,
          originalHeight,
        );

        final resized =
            (targetWidth == originalWidth && targetHeight == originalHeight)
            ? decoded
            : img.copyResize(
                decoded,
                width: targetWidth,
                height: targetHeight,
                interpolation: img.Interpolation.average,
              );

        encoded = img.encodeJpg(resized, quality: spec.quality);
      } else {
        int currentMaxDim = spec.maxDimension;
        final qualitySteps = [spec.quality, 80, 75, 70, 65, 60, 55, 50];
        final dimensionSteps = [spec.maxDimension, 1400, 1200, 1024, 800];

        dimLoop:
        for (final dim in dimensionSteps) {
          if (dim > currentMaxDim) continue;
          final longestSide = originalWidth > originalHeight
              ? originalWidth
              : originalHeight;
          final scale = longestSide > dim ? dim / longestSide : 1.0;
          final targetWidth = (originalWidth * scale).round().clamp(
            1,
            originalWidth,
          );
          final targetHeight = (originalHeight * scale).round().clamp(
            1,
            originalHeight,
          );

          final resized =
              (targetWidth == originalWidth && targetHeight == originalHeight)
              ? decoded
              : img.copyResize(
                  decoded,
                  width: targetWidth,
                  height: targetHeight,
                  interpolation: img.Interpolation.average,
                );

          for (final q in qualitySteps) {
            final candidate = img.encodeJpg(resized, quality: q);
            if (candidate.length <= maxBytes) {
              encoded = candidate;
              break dimLoop;
            }
          }
        }

        if (encoded == null) {
          final scale =
              640.0 /
              (originalWidth > originalHeight ? originalWidth : originalHeight);
          final targetWidth = (originalWidth * scale).round().clamp(
            1,
            originalWidth,
          );
          final targetHeight = (originalHeight * scale).round().clamp(
            1,
            originalHeight,
          );
          final smallResized = img.copyResize(
            decoded,
            width: targetWidth,
            height: targetHeight,
            interpolation: img.Interpolation.average,
          );
          encoded = img.encodeJpg(smallResized, quality: 45);
        }
      }

      result[spec.key] = encoded;
    } catch (_) {}
  }
  return result;
}
