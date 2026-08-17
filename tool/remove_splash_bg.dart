import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final source = File('assets/images/splashiocn.png');
  final output = File('assets/images/splash_icon_transparent.png');
  final bytes = source.readAsBytesSync();
  final image = img.decodePng(bytes);

  if (image == null) {
    stderr.writeln('Could not decode splash icon.');
    exit(1);
  }

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      final isBlueBackground = b > 120 && b > r + 15 && b > g + 5;
      final isLightBlueBackground =
          r < 180 && g < 200 && b > 100 && (r + g) < b + 40;

      if (isBlueBackground || isLightBlueBackground) {
        image.setPixelRgba(x, y, r, g, b, 0);
      }
    }
  }

  output.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Saved ${output.path}');
}
