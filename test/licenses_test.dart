import 'package:flutter/foundation.dart';
import 'package:flutter_animated_media/flutter_animated_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'registration is explicit, idempotent and includes complete attribution',
    () async {
      registerAnimatedMediaLicenses();
      registerAnimatedMediaLicenses();
      final entries = await LicenseRegistry.licenses
          .where(
            (entry) => entry.packages.contains('Animated Noto Emoji (Google)'),
          )
          .toList();
      expect(entries.length, 1);
      final text = entries.single.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('Animated Noto Emoji by Google'));
      expect(text, contains('https://creativecommons.org/licenses/by/4.0/'));
      expect(text, contains('Section 8'));
      expect(text, contains('Google Emoji Metadata'));
      expect(text, contains('emoji_17_0_ordering.json'));
      final metadata = await LicenseRegistry.licenses
          .where((entry) => entry.packages.contains('Google Emoji Metadata'))
          .toList();
      expect(metadata.length, 1);
      final metadataText = metadata.single.paragraphs
          .map((p) => p.text)
          .join('\n');
      expect(metadataText, contains('Apache License'));
      expect(metadataText, contains('Version 2.0, January 2004'));
      expect(metadataText, contains('END OF TERMS AND CONDITIONS'));
    },
  );
}
