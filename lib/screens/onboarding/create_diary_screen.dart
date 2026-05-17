import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/group_room/models/group_room_models.dart';
import '../../features/upload/models/upload_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
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
  int _maxMembers = 4;

  static const List<int?> _presets = [2, 4, 6, 8, 10, null];

  File? _pickedImage;
  /// edit 모드에서 prefill 된 기존 썸네일 URL.
  String? _existingThumbnailUrl;
  /// _existingThumbnailUrl 을 사용자가 명시적으로 제거했는지.
  bool _removedExistingImage = false;

  bool _submitting = false;
  bool _loadingExisting = false;
  /// edit 모드에서 서버 측 현재 인원수 (이 값보다 적게 설정 불가).
  int _currentMemberCount = 1;

  bool get _canCreate =>
      _nameController.text.trim().isNotEmpty && !_submitting;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    if (widget.isEdit) {
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    setState(() => _loadingExisting = true);
    try {
      final detail = await Di.groupRoomRepository.detail(groupId);
      if (!mounted) return;
      setState(() {
        _nameController.text = detail.groupRoom.name;
        _maxMembers = detail.groupRoom.maxMembers;
        _existingThumbnailUrl = detail.groupRoom.thumbnailImage;
        _currentMemberCount = detail.memberships.isNotEmpty
            ? detail.memberships.length
            : detail.groupRoom.memberCount;
        _loadingExisting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingExisting = false);
      showErrorDialog(context, errorMessageOf(e));
    }
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
    setState(() => _maxMembers = value);
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

  Future<String?> _uploadIfNeeded() async {
    final file = _pickedImage;
    if (file == null) return null;
    final uploaded = await Di.uploadRepository.uploadImage(
      filePath: file.path,
      purpose: UploadPurpose.groupThumbnail,
    );
    return uploaded.id;
  }

  Future<void> _submit() async {
    if (!_canCreate) return;
    setState(() => _submitting = true);
    final name = _nameController.text.trim();
    try {
      if (widget.isEdit) {
        final groupId = Di.activeGroup.groupRoomId;
        if (groupId == null) throw Exception('그룹방 정보가 없어요');
        String? newImageId;
        if (_pickedImage != null) {
          newImageId = await _uploadIfNeeded();
        }
        final body = UpdateGroupRoomRequest(
          name: name,
          maxMembers: _maxMembers,
          thumbnailImageId: _pickedImage != null
              ? newImageId
              : (_removedExistingImage
                  ? null
                  : UpdateGroupRoomRequest.unset),
        );
        final updated = await Di.groupRoomRepository.update(groupId, body);
        if (!mounted) return;
        Di.activeGroup.updateName(updated.name);
        Navigator.of(context).pop();
        showInfoDialog(context, '수정 완료', '그룹방 정보를 수정했어요');
      } else {
        final imageId = await _uploadIfNeeded();
        final result = await Di.groupRoomRepository.create(
          CreateGroupRoomRequest(
            name: name,
            maxMembers: _maxMembers,
            thumbnailImageId: imageId,
          ),
        );
        if (!mounted) return;
        Di.activeGroup.enter(
          groupRoomId: result.groupRoom.id,
          groupRoomName: result.groupRoom.name,
          isOwner: true,
        );
        Navigator.of(context).pushReplacementNamed(
          '/code-generate',
          arguments: {
            'code': result.inviteCode,
            'groupRoomId': result.groupRoom.id,
            'groupName': result.groupRoom.name,
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: _loadingExisting
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
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
                          '그룹방',
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
                                borderSide: const BorderSide(
                                    color: AppColors.gray100),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primary),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 24),
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
                                setState(() {
                                  _pickedImage = file;
                                  _removedExistingImage = false;
                                });
                              }
                            },
                            child: _buildThumbnailBox(),
                          ),
                          const SizedBox(height: 28),
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
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: _decrement,
                                  child: _stepperButton(Icons.remove),
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
                                  child: _stepperButton(Icons.add),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: _presets.map((preset) {
                              final label =
                                  preset == null ? '제한없음' : '$preset명';
                              final isSelected = preset == null
                                  ? _maxMembers > 10
                                  : _maxMembers == preset;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () =>
                                      _setMaxMembers(preset ?? 99),
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
                          if (widget.isEdit) ...[
                            const SizedBox(height: 28),
                            GestureDetector(
                              onTap: () => Navigator.of(context)
                                  .pushNamed('/manage-diary'),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gray50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: AppColors.gray100),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.tune_rounded,
                                        size: 20,
                                        color: AppColors.gray700),
                                    SizedBox(width: 10),
                                    Text(
                                      '그룹방 관리',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.gray900,
                                      ),
                                    ),
                                    Spacer(),
                                    Icon(Icons.arrow_forward_ios,
                                        size: 14,
                                        color: AppColors.gray400),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                                  Icon(Icons.info_outline,
                                      size: 16, color: AppColors.gray400),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '그룹방 생성 시 초대 코드가 자동으로\n만들어집니다',
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
                      text: _submitting
                          ? '처리 중...'
                          : (widget.isEdit ? '그룹방 수정하기' : '그룹방 만들기'),
                      onPressed: _canCreate ? _submit : null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildThumbnailBox() {
    if (_pickedImage != null) {
      return _imageWithRemove(
        Image.file(_pickedImage!,
            width: 80, height: 80, fit: BoxFit.cover),
        () => setState(() => _pickedImage = null),
      );
    }
    if (_existingThumbnailUrl != null && !_removedExistingImage) {
      return _imageWithRemove(
        Image.network(_existingThumbnailUrl!,
            width: 80, height: 80, fit: BoxFit.cover),
        () => setState(() => _removedExistingImage = true),
      );
    }
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200, width: 1.5),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_outlined,
              size: 24, color: AppColors.gray400),
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
    );
  }

  Widget _imageWithRemove(Widget image, VoidCallback onRemove) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: image,
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: AppColors.gray700,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  size: 12, color: AppColors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepperButton(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Icon(icon, size: 18, color: AppColors.gray700),
    );
  }
}
