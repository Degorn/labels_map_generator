import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';

class LabelMapResult {
  const LabelMapResult({required this.imageWidth, required this.imageHeight, required this.labels});

  final int imageWidth;
  final int imageHeight;
  final Uint32List labels;
}

class LabelMapGenerator {
  const LabelMapGenerator({this.alphaThreshold = 180, this.contourZoneId = 0})
    : assert(
        alphaThreshold >= 0 && alphaThreshold <= 255,
        'alphaThreshold is $alphaThreshold, but must be between 0 and 255.',
      );

  final int alphaThreshold;
  final int contourZoneId;

  LabelMapResult? fromFile(String path) {
    final bytes = File(path).readAsBytesSync();
    final image = decodeImage(bytes);
    if (image == null) return null;
    return fromImage(image);
  }

  LabelMapResult fromImage(Image image) {
    final width = image.width;
    final height = image.height;
    final pixels = image.buffer.asUint32List();

    final labels = Uint32List(width * height);
    var regionId = contourZoneId + 1;

    for (var idx = 0; idx < pixels.length; idx++) {
      if (labels[idx] == 0 && !_isContourColor(pixels[idx])) {
        _floodFill(
          pixels: pixels,
          labels: labels,
          width: width,
          height: height,
          startIdx: idx,
          regionId: regionId,
        );
        regionId++;
      }
    }

    return LabelMapResult(imageWidth: width, imageHeight: height, labels: labels);
  }

  List<int> _floodFill({
    required Uint32List pixels,
    required Uint32List labels,
    required int width,
    required int height,
    required int startIdx,
    required int regionId,
  }) {
    final stack = <int>[startIdx];
    final zonePixels = <int>[];

    while (stack.isNotEmpty) {
      final idx = stack.removeLast();

      labels[idx] = regionId;
      zonePixels.add(idx);

      final x = idx % width;
      final y = idx ~/ width;

      if (x > 0) {
        final nIdx = idx - 1;
        if (labels[nIdx] == 0 && !_isContourColor(pixels[nIdx])) stack.add(nIdx);
      }
      if (x < width - 1) {
        final nIdx = idx + 1;
        if (labels[nIdx] == 0 && !_isContourColor(pixels[nIdx])) stack.add(nIdx);
      }
      if (y > 0) {
        final nIdx = idx - width;
        if (labels[nIdx] == 0 && !_isContourColor(pixels[nIdx])) stack.add(nIdx);
      }
      if (y < height - 1) {
        final nIdx = idx + width;
        if (labels[nIdx] == 0 && !_isContourColor(pixels[nIdx])) stack.add(nIdx);
      }
    }

    return zonePixels;
  }

  bool _isContourColor(int color) {
    final a = (color >> 24) & 0xFF;
    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;
    return a > alphaThreshold && r < 10 && g < 10 && b < 10;
  }
}
