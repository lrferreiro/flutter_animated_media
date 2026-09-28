import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Registers Noto artwork and catalog licenses once per isolate.
/// Call after initializing Flutter, and expose the app's license screen.
void registerAnimatedMediaLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    final notices = await rootBundle.loadString(
      'packages/flutter_animated_media/THIRD_PARTY_NOTICES',
    );
    final license = await rootBundle.loadString(
      'packages/flutter_animated_media/licenses/CC-BY-4.0.txt',
    );
    yield LicenseEntryWithLineBreaks(const [
      'Animated Noto Emoji (Google)',
    ], '$notices\n\n$license');
    final metadataLicense = await rootBundle.loadString(
      'packages/flutter_animated_media/licenses/Apache-2.0.txt',
    );
    yield LicenseEntryWithLineBreaks(const [
      'Google Emoji Metadata',
    ], '$notices\n\n$metadataLicense');
  });
}
