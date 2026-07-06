import 'dart:io';

import 'package:flutter/material.dart';

import 'diary_form_screen.dart';

class WriteDiaryScreen extends StatelessWidget {
  const WriteDiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return DiaryFormScreen(
      mode: DiaryFormMode.create,
      initialDate: args is DateTime ? args : null,
    );
  }
}

/// 호환용 — 기존 import 가 일부 노출돼있어 export.
// ignore: unused_element
typedef _PickedImageFile = File;
