import 'package:flutter/material.dart';
import 'package:flutter_animated_media/flutter_animated_media.dart';

import 'media_gallery_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerAnimatedMediaLicenses();
  runApp(const AnimatedMediaExample());
}

class AnimatedMediaExample extends StatelessWidget {
  const AnimatedMediaExample({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Animated media gallery',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      brightness: Brightness.dark,
    ),
    home: const MediaGalleryPage(),
  );
}
