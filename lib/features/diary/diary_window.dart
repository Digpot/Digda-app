/// 일기 작성·수정·삭제 가능 기간 정책 — 단일 소스.
///
/// 디그팟 일기는 **오늘로부터 최근 3개월** 안의 날짜만 다룰 수 있다.
/// - 작성: 3개월 이전 날짜로는 새 일기를 쓸 수 없다.
/// - 수정/삭제: 일기 날짜가 3개월을 지났으면 잠겨서 바꿀 수 없다.
///
/// 서버(DiaryServiceImpl)도 같은 규칙(todayKst().minusMonths(3))으로 막으므로
/// 임계 개월 수를 바꿀 땐 양쪽을 함께 수정해야 한다.
const int kDiaryEditableMonths = 3;

/// 편집 가능한 가장 이른 날짜(자정). 오늘에서 [kDiaryEditableMonths] 개월을 뺀다.
/// 월 언더플로(예: 1월-3월)는 DateTime 생성자가 정규화한다.
DateTime diaryEditableFrom() {
  final now = DateTime.now();
  return DateTime(now.year, now.month - kDiaryEditableMonths, now.day);
}

/// [date] 가 편집 가능 기간(최근 3개월) 안에 드는지. 시간 컴포넌트는 무시한다.
bool isDiaryDateEditable(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return !d.isBefore(diaryEditableFrom());
}
