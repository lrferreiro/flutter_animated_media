import 'package:flutter/material.dart';
import 'package:flutter_animated_media/flutter_animated_media.dart';

class PerformanceList extends StatelessWidget {
  const PerformanceList({
    super.key,
    required this.animated,
    required this.scroll,
    required this.loader,
  });

  final bool animated;
  final ScrollController scroll;
  final MediaLoader loader;
  static const emojis = ['😀', '❤️', '👍🏽', '🚀'];

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: Text(animated ? 'Animated' : 'Static')),
      body: ListView.builder(
        controller: scroll,
        itemCount: 80,
        itemExtent: 84,
        itemBuilder: (context, index) => Center(
          child: animated
              ? AnimatedEmoji(
                  emojis[index % emojis.length],
                  loader: loader,
                  maxCycles: 2,
                )
              : Text(
                  emojis[index % emojis.length],
                  style: const TextStyle(fontSize: 48, height: 1),
                ),
        ),
      ),
    ),
  );
}
