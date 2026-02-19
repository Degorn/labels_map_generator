import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';

class LabelMapResult {
  const LabelMapResult({
    required this.imageWidth,
    required this.imageHeight,
    required this.labels,
    required this.contours,
  });

  final int imageWidth;
  final int imageHeight;
  final Uint32List labels;
  final Map<int, List<(int, int)>> contours;
}

class LabelMapGenerator {
  LabelMapGenerator({this.alphaThreshold = 180, this.contourZoneId = 0})
    : assert(
        alphaThreshold >= 0 && alphaThreshold <= 255,
        'alphaThreshold is $alphaThreshold, but must be between 0 and 255.',
      );

  final int alphaThreshold;
  final int contourZoneId;

  final _progressController = StreamController<double>.broadcast(sync: true);
  Stream<double> get progress => _progressController.stream;

  void dispose() {
    if (!_progressController.isClosed) {
      _progressController.close();
    }
  }

  LabelMapResult? fromFile(String path) {
    final bytes = File(path).readAsBytesSync();
    final image = decodeImage(bytes);
    if (image == null) return null;
    return fromImage(image);
  }

  LabelMapResult fromImage(Image image, {int dilateIterations = 1}) {
    final width = image.width;
    final height = image.height;
    final pixels = image.buffer.asUint32List();

    final labels = Uint32List(width * height);
    var regionId = contourZoneId + 1;

    final contours = <int, List<(int, int)>>{};

    final total = width * height;
    var checked = 0;

    _progressController.add(0.0);

    for (var idx = 0; idx < pixels.length; idx++) {
      if (labels[idx] == 0 && !_isContourColor(pixels[idx])) {
        final (contour, _) = _floodFill(
          pixels: pixels,
          labels: labels,
          width: width,
          height: height,
          startIdx: idx,
          regionId: regionId,
          onPixelVisited: () {
            checked++;
            if (checked % 100 == 0 || checked == total) {
              _progressController.add(checked / total);
            }
          },
        );
        contours[regionId] = contour;
        regionId++;
      } else {
        checked++;
        if (checked % 100 == 0 || checked == total) {
          _progressController.add(checked / total);
        }
      }
    }

    _progressController.add(1.0);

    _applyDilate(labels, width, height, dilateIterations);

    return LabelMapResult(
      imageWidth: width,
      imageHeight: height,
      labels: labels,
      contours: contours,
    );
  }

  (List<(int, int)>, List<int>) _floodFill({
    required Uint32List pixels,
    required Uint32List labels,
    required int width,
    required int height,
    required int startIdx,
    required int regionId,
    void Function()? onPixelVisited,
  }) {
    final stack = <int>[startIdx];
    final zonePixels = <int>[];
    final contour = <(int, int)>[];

    while (stack.isNotEmpty) {
      final idx = stack.removeLast();

      if (labels[idx] != 0) continue;

      // Notify that we're about to label this pixel (counts toward progress).
      onPixelVisited?.call();

      labels[idx] = regionId;
      zonePixels.add(idx);

      final x = idx % width;
      final y = idx ~/ width;

      var isContourPixel = false;

      for (final offset in [-1, 1, -width, width]) {
        final nx = x + (offset == -1 || offset == 1 ? offset : 0);
        final ny = y + (offset == -width || offset == width ? offset ~/ width : 0);

        if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
          isContourPixel = true;
          continue;
        }

        final nIdx = idx + offset;

        if (labels[nIdx] == 0 && !_isContourColor(pixels[nIdx])) {
          stack.add(nIdx);
        } else if (labels[nIdx] == 0 || _isContourColor(pixels[nIdx])) {
          isContourPixel = true;
        }
      }

      if (isContourPixel) {
        contour.add((x, y));
      }
    }

    if (zonePixels.length < 21) {
      for (final idx in zonePixels) {
        labels[idx] = 0;
      }
      return (<(int, int)>[], <int>[]);
    }

    return (contour, zonePixels);
  }

  bool _isContourColor(int color) {
    final a = (color >> 24) & 0xFF;
    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;
    return a > alphaThreshold && r < 10 && g < 10 && b < 10;
  }

  void _applyDilate(Uint32List labels, int width, int height, int iterations) {
    for (var step = 0; step < iterations; step++) {
      final tempLabels = Uint32List.fromList(labels);

      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final idx = y * width + x;
          if (labels[idx] != 0) continue;

          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              final nx = x + dx;
              final ny = y + dy;
              if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                final nIdx = ny * width + nx;
                if (tempLabels[nIdx] != 0) {
                  labels[idx] = tempLabels[nIdx];
                  break;
                }
              }
            }
            if (labels[idx] != 0) break;
          }
        }
      }
    }
  }
}
