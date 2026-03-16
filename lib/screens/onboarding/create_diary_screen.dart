import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/image_pick_helper.dart';

class CreateDiaryScreen extends StatefulWidget {
  const CreateDiaryScreen({super.key, this.isEdit = false});

  final bool isEdit;

  @override
  State<CreateDiaryScreen> createState() => _CreateDiaryScreenState();
}

class _CreateDiaryScreenState extends State<CreateDiaryScreen> {
  late final TextEditingController _nameController;
  late int _maxMembers;

  static const List<int?> _presets = [2, 4, 6, 8, 10, null]; // null = 제한없음

  File? _pickedImage;

  // 목데이터: 현재 참여 중인 멤버 수 (나중에 API로 교체)
  static const int _currentMemberCount = 7;

  bool get _canCreate => _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.isEdit ? '여행 모임' : '',
    );
    _maxMembers = widget.isEdit ? 6 : 4;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _increment() {
    setState(() {
      if (_maxMembers < 99) _maxMembers++;
    });
  }

  void _decrement() {
    if (widget.isEdit && _maxMembers - 1 < _currentMemberCount) {
      _showMemberLimitDialog();
      return;
    }
    setState(() {
      if (_maxMembers > 2) _maxMembers--;
    });
  }

  void _setMaxMembers(int value) {
    if (widget.isEdit && value < _currentMemberCount) {
      _showMemberLimitDialog();
      return;
    }
    setState(() {
      _maxMembers = value;
    });
  }

  void _showMemberLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '인원 변경 불가',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: Text(
          '현재 $_currentMemberCount명이 참여 중이에요.\n참여 인원보다 적게 설정할 수 없어요.',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '확인',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '다이어리',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // 방 이름
                    const Text(
                      '방 이름',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      maxLength: 20,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                        height: 1.4,
                        color: AppColors.gray900,
                      ),
                      decoration: InputDecoration(
                        hintText: '여행 모임',
                        hintStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                          color: AppColors.gray300,
                        ),
                        counterStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.gray400,
                        ),
                        filled: true,
                        fillColor: AppColors.gray50,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.gray100),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 24),
                    // 대표 이미지
                    const Row(
                      children: [
                        Text(
                          '대표 이미지',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.3,
                            color: AppColors.gray900,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '(선택)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final file = await pickImage(context);
                        if (file != null) {
                          setState(() => _pickedImage = file);
                        }
                      },
                      child: _pickedImage != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _pickedImage!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _pickedImage = null),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: AppColors.gray700,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.gray200,
                                  width: 1.5,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    size: 24,
                                    color: AppColors.gray400,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '사진 추가',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 11,
                                      color: AppColors.gray400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 28),
                    // 최대 인원
                    const Text(
                      '최대 인원',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '이 다이어리에 참여할 수 있는 최대 인원을 설정하세요',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 스테퍼
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _decrement,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.gray200),
                              ),
                              child: const Icon(
                                Icons.remove,
                                size: 18,
                                color: AppColors.gray700,
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '$_maxMembers',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                  color: AppColors.gray900,
                                ),
                              ),
                              const Text(
                                '명',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                  color: AppColors.gray500,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _increment,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.gray200),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 18,
                                color: AppColors.gray700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 프리셋 버튼
                    Row(
                      children: _presets.map((preset) {
                        final label = preset == null ? '제한없음' : '$preset명';
                        final isSelected = preset == null
                            ? _maxMembers > 10
                            : _maxMembers == preset;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              _setMaxMembers(preset ?? 99);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.gray50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.gray200,
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.gray700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // 다이어리 관리 버튼 (수정 모드에서만 표시)
                    if (widget.isEdit) ...[
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pushNamed('/manage-diary'),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gray100),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: AppColors.gray700,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '다이어리 관리',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.gray900,
                                ),
                              ),
                              Spacer(),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: AppColors.gray400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // 초대 코드 섹션 (생성 모드에서만 표시)
                    if (!widget.isEdit) ...[
                      const SizedBox(height: 28),
                      const Text(
                        '초대 코드',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.3,
                          color: AppColors.gray900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gray100),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.gray400,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '다이어리 생성 시 초대 코드가 자동으로\n만들어집니다',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13,
                                  height: 1.5,
                                  color: AppColors.gray500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: PrimaryButton(
                text: widget.isEdit ? '다이어리 수정하기' : '다이어리 만들기',
                onPressed: _canCreate
                    ? () => widget.isEdit
                        ? Navigator.of(context).pop()
                        : Navigator.of(context)
                            .pushReplacementNamed('/code-generate')
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
