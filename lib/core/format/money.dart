/// 원(KRW) 표기 공통 규칙.
///
/// 가계부는 캘린더 셀·상세·전체 페이지에서 같은 금액을 서로 다른 폭으로 보여준다.
/// 포맷을 화면마다 따로 짜면 "12,000원" 과 "1.2만" 이 한 화면에 섞이므로 여기에 모은다.
library;

/// 1234567 → '1,234,567'. 음수도 부호를 유지한다.
String formatAmount(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

/// 1234567 → '1,234,567원'.
String formatWon(int amount) => '${formatAmount(amount)}원';

/// 좁은 자리(캘린더 셀·칩)용 축약 표기.
///
/// 만/억 단위로 줄이되 소수 첫째 자리까지만 남긴다. 1,234,567 → '123.5만'.
/// 캘린더 한 칸은 7분의 1 폭이라 원 단위를 그대로 쓰면 무조건 잘린다.
String formatAmountCompact(int amount) {
  final negative = amount < 0;
  final v = amount.abs();
  String body;
  if (v >= 100000000) {
    body = '${_trimZero(v / 100000000)}억';
  } else if (v >= 10000) {
    body = '${_trimZero(v / 10000)}만';
  } else {
    body = formatAmount(v);
  }
  return negative ? '-$body' : body;
}

/// 1.0 → '1', 1.25 → '1.3' (소수 첫째 자리 반올림, 정수면 소수점 제거).
String _trimZero(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toStringAsFixed(1);
}
