import 'package:flutter/material.dart';

import 'diary_form_screen.dart';

class EditDiaryScreen extends StatelessWidget {
  const EditDiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final diaryId = args is String ? args : null;
    return DiaryFormScreen(
      mode: DiaryFormMode.edit,
      diaryId: diaryId,
    );
  }
}
