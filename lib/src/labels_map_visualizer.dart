import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';

abstract class LabelsMapVisualizer {
  static void visualizeLabelMapMask({
    required int imageWidth,
    required int imageHeight,
    required Uint32List labels,
    required String saveAs,
    int contourZoneId = 0,
    bool randomizeColors = false,
  }) {
    assert(
      labels.length == imageWidth * imageHeight,
      'labels length (${labels.length}) != image size (${imageWidth * imageHeight})',
    );

    final outPixels = Uint32List(imageWidth * imageHeight);
    final encode = randomizeColors ? _encodeRandomized : _encodeById;
    for (var i = 0; i < labels.length; i++) {
      final id = labels[i];
      outPixels[i] = id == contourZoneId ? 0 : encode(id);
    }

    final newImage = Image.fromBytes(
      width: imageWidth,
      height: imageHeight,
      bytes: outPixels.buffer,
      format: Format.uint8,
      numChannels: 4,
      order: ChannelOrder.rgba,
    );

    final file = File(saveAs);
    file.createSync(recursive: true);
    file.writeAsBytesSync(encodePng(newImage));
  }

  static int _encodeById(int id) {
    return (0xFF << 24) | (id & 0xFF) | (((id >> 8) & 0xFF) << 8) | (((id >> 16) & 0xFF) << 16);
  }

  static int _encodeRandomized(int id) {
    final color = (id * 2654435761) & 0xFFFFFF;
    return (0xFF << 24) |
        (color & 0xFF) |
        (((color >> 8) & 0xFF) << 8) |
        (((color >> 16) & 0xFF) << 16);
  }
}
