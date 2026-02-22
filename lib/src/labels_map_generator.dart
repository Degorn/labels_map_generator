import 'dart:async';
import 'dart:typed_data';

import 'package:image/image.dart';
import 'package:labels_map_generator/src/image_processing.dart';

class LabelMapResult {
  const LabelMapResult({required this.imageWidth, required this.imageHeight, required this.labels});

  final int imageWidth;
  final int imageHeight;
  final Uint32List labels;
}

class LabelMapGenerator {
  LabelMapGenerator({this.alphaThreshold = 180, this.contourZoneId = 0});

  final int alphaThreshold;
  final int contourZoneId;

  final _progressController = StreamController<double>.broadcast(sync: true);
  Stream<double> get progress => _progressController.stream;

  void dispose() {
    _progressController.close();
  }

  LabelMapResult fromImage(Image image, {int dilateIterations = 1}) {
    final width = image.width;
    final height = image.height;
    final pixels = image.buffer.asUint32List();
    final labels = Uint32List(width * height);

    var regionId = contourZoneId + 1;
    final totalPixels = pixels.length;
    final progressStep = (totalPixels / 100).clamp(1, totalPixels).toInt();

    for (var i = 0; i < totalPixels; i++) {
      if (labels[i] == 0 && !_isContour(pixels[i])) {
        _scanlineFloodFill(pixels, labels, i, width, height, regionId++);
      }

      if (i % progressStep == 0) {
        _progressController.add(i / totalPixels);
      }
    }

    if (dilateIterations > 0) {
      _applyDilate(labels, width, height, dilateIterations);
    }

    _progressController.add(1.0);
    return LabelMapResult(imageWidth: width, imageHeight: height, labels: labels);
  }

  void _scanlineFloodFill(
    Uint32List pixels,
    Uint32List labels,
    int startIdx,
    int w,
    int h,
    int id,
  ) {
    final stack = [startIdx];

    while (stack.isNotEmpty) {
      var idx = stack.removeLast();
      var x = idx % w;
      var y = idx ~/ w;

      var left = x;
      while (left > 0 && labels[y * w + left - 1] == 0 && !_isContour(pixels[y * w + left - 1])) {
        left--;
      }

      var right = x;
      while (right < w - 1 &&
          labels[y * w + right + 1] == 0 &&
          !_isContour(pixels[y * w + right + 1])) {
        right++;
      }

      for (var i = left; i <= right; i++) {
        labels[y * w + i] = id;
      }

      if (y > 0) _scanLineForSeed(pixels, labels, left, right, y - 1, w, stack);
      if (y < h - 1) _scanLineForSeed(pixels, labels, left, right, y + 1, w, stack);
    }
  }

  void _scanLineForSeed(
    Uint32List px,
    Uint32List lb,
    int left,
    int right,
    int y,
    int w,
    List<int> stack,
  ) {
    var added = false;
    for (var i = left; i <= right; i++) {
      var idx = y * w + i;
      var canFill = lb[idx] == 0 && !_isContour(px[idx]);

      if (!added && canFill) {
        stack.add(idx);
        added = true;
      } else if (added && !canFill) {
        added = false;
      }
    }
  }

  bool _isContour(int color) {
    return ImageProcessingUtils.isContour(color, alphaThreshold: alphaThreshold);
  }

  void _applyDilate(Uint32List labels, int w, int h, int iterations) {
    for (var step = 0; step < iterations; step++) {
      final changedIndices = <int>[];
      final newValues = <int>[];

      for (var i = 0; i < labels.length; i++) {
        if (labels[i] != 0) continue;

        final n = i >= w ? labels[i - w] : 0;
        final s = i < labels.length - w ? labels[i + w] : 0;
        final west = i % w > 0 ? labels[i - 1] : 0;
        final e = i % w < w - 1 ? labels[i + 1] : 0;

        final neighbor = n != 0 ? n : (s != 0 ? s : (west != 0 ? west : e));
        if (neighbor != 0) {
          changedIndices.add(i);
          newValues.add(neighbor);
        }
      }

      for (var j = 0; j < changedIndices.length; j++) {
        labels[changedIndices[j]] = newValues[j];
      }
    }
  }
}
