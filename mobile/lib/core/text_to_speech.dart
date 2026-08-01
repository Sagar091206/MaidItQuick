import 'package:flutter/services.dart';

class AppTextToSpeech {
  AppTextToSpeech._();

  static const _channel = MethodChannel('maiditquick/text_to_speech');

  static Future<void> speak({
    required String text,
    required String languageCode,
  }) async {
    try {
      await _channel.invokeMethod<void>('speak', {
        'text': text,
        'languageCode': languageCode,
      });
    } on PlatformException catch (error) {
      throw TextToSpeechException(error.message ?? 'Audio is unavailable.');
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException catch (error) {
      throw TextToSpeechException(error.message ?? 'Audio could not stop.');
    }
  }
}

class TextToSpeechException implements Exception {
  const TextToSpeechException(this.message);

  final String message;
}
