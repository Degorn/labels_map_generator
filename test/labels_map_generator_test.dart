import 'package:labels_map_generator/src/labels_map_generator.dart';
import 'package:test/test.dart';

void main() {
  test('From file', () {
    const imagePath = 'test/images/5x5-frame.png';
    final result = LabelMapGenerator().fromFile(imagePath);
    if (result == null) {
      fail('Failed to load image from $imagePath');
    }

    expect(result.labels.map((e) => e & 0xFF).toList(), [
      1, 0, 2, 2, 0, //
      0, 0, 0, 0, 0, //
      3, 3, 3, 0, 4, //
      0, 0, 0, 0, 4, //
      5, 5, 0, 4, 4, //
    ]);
  });
}
