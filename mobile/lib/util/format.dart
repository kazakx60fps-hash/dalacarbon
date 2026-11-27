// Сандарды сайттағыдай пішімдеу: мыңдықтар бос орынмен, ондық бөлгіш — үтір.
String fmtInt(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return n < 0 ? '−$b' : b.toString();
}

String fmtNum(num n, [int digits = 1]) {
  final fixed = n.toStringAsFixed(digits);
  final parts = fixed.split('.');
  final whole = fmtInt(int.parse(parts[0]));
  if (parts.length < 2) return whole;
  final frac = parts[1].replaceAll(RegExp(r'0+$'), '');
  return frac.isEmpty ? whole : '$whole,$frac';
}

String money(num n) => '\$${fmtInt(n)}';

const monthsKk = ['Қаңтар', 'Ақпан', 'Наурыз', 'Сәуір', 'Мамыр', 'Маусым', 'Шілде', 'Тамыз', 'Қыркүйек', 'Қазан', 'Қараша', 'Желтоқсан'];
const weekdaysKk = ['Дүйсенбі', 'Сейсенбі', 'Сәрсенбі', 'Бейсенбі', 'Жұма', 'Сенбі', 'Жексенбі'];
const weekdaysShortKk = ['Дс', 'Сс', 'Ср', 'Бс', 'Жм', 'Сб', 'Жк'];

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Python-ның round() функциясындай: дәл жартысы жұп санға қарай (1912,5 → 1912).
/// Сервер есептеген табыспен бірдей сан шығуы үшін.
int roundHalfEven(num x) {
  final f = x.floorToDouble();
  final diff = x - f;
  if ((diff - 0.5).abs() < 1e-9) return f.toInt().isEven ? f.toInt() : f.toInt() + 1;
  return x.round();
}
