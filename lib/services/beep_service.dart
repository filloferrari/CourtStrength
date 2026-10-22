import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Suona tre bip alla fine del recupero. Il suono è generato in memoria
/// (WAV a 16 bit), quindi non servono file audio negli asset.
class BeepService {
  BeepService() : _player = AudioPlayer();

  final AudioPlayer _player;
  Uint8List? _wav;

  Future<void> playRestEnd() async {
    try {
      _wav ??= _buildWav();
      await _player.stop();
      await _player.play(BytesSource(_wav!));
    } catch (_) {
      // Il suono è un extra: un errore audio non deve mai bloccare l'allenamento.
    }
  }

  Future<void> dispose() => _player.dispose();

  static Uint8List _buildWav() {
    const sampleRate = 22050;
    const beeps = 3;
    const beepSamples = sampleRate * 180 ~/ 1000; // 180 ms
    const gapSamples = sampleRate * 120 ~/ 1000; // 120 ms
    const freq = 1000.0;
    const total = beeps * beepSamples + (beeps - 1) * gapSamples;

    final data = ByteData(44 + total * 2);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + total * 2, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    data.setUint32(40, total * 2, Endian.little);

    var pos = 44;
    const fade = sampleRate * 0.008; // 8 ms di attacco/rilascio contro i click
    for (var b = 0; b < beeps; b++) {
      for (var i = 0; i < beepSamples; i++) {
        final edge = math.min(i, beepSamples - 1 - i).toDouble();
        final env = math.min(1.0, edge / fade);
        final s = math.sin(2 * math.pi * freq * i / sampleRate) * env * 0.8;
        data.setInt16(pos, (s * 32767).round(), Endian.little);
        pos += 2;
      }
      if (b < beeps - 1) pos += gapSamples * 2; // silenzio (già a zero)
    }
    return data.buffer.asUint8List();
  }
}