abstract class ImageProcessingUtils {
  static bool isContour(int color, {int alphaThreshold = 180}) {
    final a = (color >> 24) & 0xFF;
    if (a <= alphaThreshold) return false;

    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;
    return r < 90 && g < 90 && b < 90;
  }
}
