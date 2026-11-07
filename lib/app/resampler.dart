import 'dart:math' as math;
import 'dart:typed_data';

/// Akış halinde örnekleme hızı dönüştürücü (alçak geçiren FIR + doğrusal ara değer).
/// Yerel katman normalde 16 kHz verir; bazı Android cihazlarda 44,1/48 kHz'e düşerse kullanılır.
class StreamResampler {
  StreamResampler(this.inRate, this.outRate) {
    final cutoff = 0.45 * math.min(inRate, outRate) / inRate; // normalize (0..0.5)
    const taps = 63;
    _h = Float64List(taps);
    var sum = 0.0;
    for (var i = 0; i < taps; i++) {
      final m = i - (taps - 1) / 2;
      final sinc = m == 0 ? 2 * cutoff : math.sin(2 * math.pi * cutoff * m) / (math.pi * m);
      final w = 0.42 - 0.5 * math.cos(2 * math.pi * i / (taps - 1)) + 0.08 * math.cos(4 * math.pi * i / (taps - 1));
      _h[i] = sinc * w;
      sum += _h[i];
    }
    for (var i = 0; i < taps; i++) {
      _h[i] /= sum;
    }
    _hist = Float64List(taps);
    _step = inRate / outRate;
  }

  final int inRate;
  final int outRate;
  late final Float64List _h;
  late final Float64List _hist;
  late final double _step;
  int _histPos = 0;
  double _pos = 0; // bir sonraki çıkış örneğinin, işlenmiş girdiye göre konumu
  double _prev = 0;
  double _cur = 0;
  int _consumed = 0;

  double _filter(double x) {
    _hist[_histPos] = x;
    _histPos = (_histPos + 1) % _hist.length;
    var acc = 0.0;
    var j = _histPos;
    for (var i = 0; i < _h.length; i++) {
      acc += _h[i] * _hist[j];
      j++;
      if (j == _hist.length) j = 0;
    }
    return acc;
  }

  Float32List process(Float32List x) {
    if (inRate == outRate) return x;
    final out = <double>[];
    for (var i = 0; i < x.length; i++) {
      _prev = _cur;
      _cur = _filter(x[i]);
      _consumed++;
      // çıkış örnekleri (_consumed - 1, _consumed] aralığına düşüyorsa üret
      while (_pos <= _consumed - 1) {
        final frac = _pos - (_consumed - 2);
        out.add(_prev + (_cur - _prev) * frac.clamp(0.0, 1.0));
        _pos += _step;
      }
    }
    // taşmayı önlemek için sayaçları küçült
    if (_consumed > 1 << 30) {
      _pos -= _consumed - 2;
      _consumed = 2;
    }
    return Float32List.fromList(out);
  }
}
