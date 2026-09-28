import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Registers Noto attribution and the complete CC BY 4.0 text once per isolate.
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
  });
}
