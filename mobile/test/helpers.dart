import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registers in-memory stand-ins for the persisted stores so that widget
/// tests never touch the real platform keystore (which has no plugin
/// implementation under `flutter test`).
void mockPersistedStores() {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStoragePlatform.instance =
      TestFlutterSecureStoragePlatform(<String, String>{});
}
