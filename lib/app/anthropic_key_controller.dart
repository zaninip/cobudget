import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kStorageKey = 'anthropic_api_key';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class AnthropicKeyController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => _storage.read(key: _kStorageKey);

  Future<void> setKey(String key) async {
    final trimmed = key.trim();
    await _storage.write(key: _kStorageKey, value: trimmed);
    state = AsyncData(trimmed);
  }

  Future<void> clearKey() async {
    await _storage.delete(key: _kStorageKey);
    state = const AsyncData(null);
  }

  Future<String?> readKey() => _storage.read(key: _kStorageKey);
}

final anthropicKeyControllerProvider =
    AsyncNotifierProvider<AnthropicKeyController, String?>(
  AnthropicKeyController.new,
);
