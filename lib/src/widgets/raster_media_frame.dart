import 'package:flutter/widgets.dart';

import '../playback/raster_playback.dart';

class RasterMediaFrame extends StatelessWidget {
  const RasterMediaFrame({
    super.key,
    required this.playback,
    required this.width,
    required this.height,
    required this.fit,
  });

  final RasterPlayback playback;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) =>
        RawImage(image: playback.image, width: width, height: height, fit: fit),
  );
}
