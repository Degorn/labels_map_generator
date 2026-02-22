import 'dart:io';

import 'package:image/image.dart';
import 'package:labels_map_generator/src/labels_map_generator.dart';
import 'package:test/test.dart';

void main() {
  test('From file', () {
    const imagePath = 'test/images/5x5-frame.png';

    final bytes = File(imagePath).readAsBytesSync();
    final image = decodeImage(bytes);
    if (image == null) {
      fail('Failed to load image from $imagePath');
    }

    final result = LabelMapGenerator().fromImage(image);

    expect(result.labels.map((e) => e & 0xFF).toList(), [
      1, 0, 2, 2, 0, //
      0, 0, 0, 0, 0, //
      3, 3, 3, 0, 4, //
      0, 0, 0, 0, 4, //
      5, 5, 0, 4, 4, //
    ]);
  });
}
