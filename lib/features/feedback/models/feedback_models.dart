import 'dart:convert';

/// 피드백 문항 유형 — 서버 enum(FeedbackQuestionType)과 1:1.
enum FeedbackQuestionType {
  section,
  shortText,
  paragraph,
  singleChoice,
  scale,
  grid,
  unknown;

  static FeedbackQuestionType fromName(String? name) {
    switch (name) {
      case 'SECTION':
        return FeedbackQuestionType.section;
      case 'SHORT_TEXT':
        return FeedbackQuestionType.shortText;
      case 'PARAGRAPH':
        return FeedbackQuestionType.paragraph;
      case 'SINGLE_CHOICE':
        return FeedbackQuestionType.singleChoice;
      case 'SCALE':
        return FeedbackQuestionType.scale;
      case 'GRID':
        return FeedbackQuestionType.grid;
      default:
        return FeedbackQuestionType.unknown;
    }
  }
}

/// 어드민이 구성한 피드백 폼 문항. [options] 는 서버가 JSON 문자열로 내려주며 유형별로 파싱한다.
class FeedbackQuestion {
  FeedbackQuestion({
    required this.id,
    required this.order,
    required this.type,
    required this.title,
    required this.description,
    required this.required,
    required this.choices,
    required this.scaleMin,
    required this.scaleMax,
    required this.gridRows,
    required this.gridCols,
  });

  final int id;
  final int order;
  final FeedbackQuestionType type;
  final String title;
  final String? description;
  final bool required;

  /// SINGLE_CHOICE 선택지.
  final List<String> choices;

  /// SCALE 범위.
  final int scaleMin;
  final int scaleMax;

  /// GRID 행/열.
  final List<String> gridRows;
  final List<String> gridCols;

  factory FeedbackQuestion.fromJson(Map<String, dynamic> json) {
    final type = FeedbackQuestionType.fromName(json['type'] as String?);
    dynamic opts;
    final rawOptions = json['options'];
    if (rawOptions is String && rawOptions.trim().isNotEmpty) {
      try {
        opts = jsonDecode(rawOptions);
      } catch (_) {
        opts = null;
      }
    } else if (rawOptions is Map || rawOptions is List) {
      opts = rawOptions;
    }

    List<String> choices = const [];
    int scaleMin = 1;
    int scaleMax = 5;
    List<String> gridRows = const [];
    List<String> gridCols = const [];

    if (type == FeedbackQuestionType.singleChoice && opts is List) {
      choices = opts.map((e) => e.toString()).toList();
    } else if (type == FeedbackQuestionType.scale && opts is Map) {
      scaleMin = (opts['min'] as num?)?.toInt() ?? 1;
      scaleMax = (opts['max'] as num?)?.toInt() ?? 5;
    } else if (type == FeedbackQuestionType.grid && opts is Map) {
      gridRows = ((opts['rows'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      gridCols = ((opts['cols'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
    }

    return FeedbackQuestion(
      id: (json['id'] as num).toInt(),
      order: (json['order'] as num?)?.toInt() ?? 0,
      type: type,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      required: json['required'] as bool? ?? false,
      choices: choices,
      scaleMin: scaleMin,
      scaleMax: scaleMax,
      gridRows: gridRows,
      gridCols: gridCols,
    );
  }
}
