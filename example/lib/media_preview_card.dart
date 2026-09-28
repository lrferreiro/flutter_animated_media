import 'package:flutter/material.dart';
import 'package:flutter_animated_media/flutter_animated_media.dart';

class MediaPreviewCard extends StatefulWidget {
  const MediaPreviewCard({super.key, required this.item});
  final MediaItem item;

  @override
  State<MediaPreviewCard> createState() => _MediaPreviewCardState();
}

class _MediaPreviewCardState extends State<MediaPreviewCard> {
  final _playback = MediaPlaybackController();

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AnimatedMedia(
            item: widget.item,
            controller: _playback,
            placeholder: Center(child: Text(widget.item.unicode ?? '')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item.name),
                Text(
                  '${widget.item.attribution.author} · ${widget.item.attribution.license}',
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Pause',
            onPressed: _playback.pause,
            icon: const Icon(Icons.pause),
          ),
          IconButton(
            tooltip: 'Replay',
            onPressed: _playback.replay,
            icon: const Icon(Icons.replay),
          ),
        ],
      ),
    ),
  );
}
