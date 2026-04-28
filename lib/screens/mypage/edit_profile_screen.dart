import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/api_exception.dart';
import '../../features/user/models/user_models.dart';
import '../../theme/colors.dart';
import '../../widgets/image_pick_helper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _statusController;
  File? _profileImage;
  bool _imageCleared = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final me = Di.userSession.profile;
    _nameController = TextEditingController(text: me?.name ?? '');
    _statusController = TextEditingController(text: me?.statusMessage ?? '');
    if (me == null) {
      // Lazy fetch — 진입 시 한 번 동기화.
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }
    Di.userSession.addListener(_onSession);
  }

  void _onSession() {
    if (!mounted) return;
    final me = Di.userSession.profile;
    if (me == null) return;
    if (_nameController.text.isEmpty) _nameController.text = me.name;
    if (_statusController.text.isEmpty && me.statusMessage != null) {
      _statusController.text = me.statusMessage!;
    }
    setState(() {});
  }

  Future<void> _hydrate() async {
    try {
      await Di.userSession.refresh();
    } catch (e) {
      if (!mounted) return;
      _showError(e, fallback: '프로필을 불러오지 못했습니다.');
    }
  }

  @override
  void dispose() {
    Di.userSession.removeListener(_onSession);
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final status = _statusController.text.trim();
    setState(() => _saving = true);
    try {
      final body = UpdateProfileRequest(
        name: name.isEmpty ? null : name,
        statusMessage: status,
        profileImageId:
            _imageCleared ? null : UpdateProfileRequest.unset,
        // NOTE: 새 이미지 업로드는 12번 Upload 도메인 연동 후 profileImageId 로 전달
      );
      await Di.userSession.update(body);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showError(e, fallback: '프로필을 저장할 수 없습니다.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(Object e, {required String fallback}) {
    String message = fallback;
    if (e is DioException && e.error is ApiException) {
      message = (e.error as ApiException).message;
    } else if (e is ApiException) {
      message = e.message;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final me = Di.userSession.profile;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                    '프로필 편집',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Text(
                      _saving ? '저장 중...' : '저장',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _saving ? AppColors.gray400 : AppColors.primary,
                      ),
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
                    const SizedBox(height: 28),
                    // Profile photo
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final file = await pickImage(context);
                              if (file != null) {
                                setState(() {
                                  _profileImage = file;
                                  _imageCleared = false;
                                });
                              }
                            },
                            child: Stack(
                              children: [
                                _buildAvatar(me),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.gray700,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 16,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => setState(() {
                              _profileImage = null;
                              _imageCleared = true;
                            }),
                            child: Text(
                              _imageCleared ? '기본 아바타로 초기화 됨' : '사진 변경',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                fontSize: 13,
                                color: AppColors.gray500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildFieldLabel('이름'),
                    const SizedBox(height: 8),
                    _NameInput(controller: _nameController),
                    const SizedBox(height: 24),
                    _buildFieldLabel('상태 메시지'),
                    const SizedBox(height: 8),
                    _StatusInput(controller: _statusController),
                    const SizedBox(height: 28),
                    _buildFieldLabel('연동 계정'),
                    const SizedBox(height: 10),
                    _ProviderBadge(provider: me?.provider ?? 'kakao'),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(UserProfile? me) {
    if (_profileImage != null) {
      return ClipOval(
        child: Image.file(_profileImage!, width: 96, height: 96, fit: BoxFit.cover),
      );
    }
    final url = !_imageCleared ? me?.profileImage : null;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderAvatar(),
        ),
      );
    }
    return _placeholderAvatar();
  }

  Widget _placeholderAvatar() => Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, size: 54, color: AppColors.primary),
      );

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: AppColors.gray900,
      ),
    );
  }
}

class _NameInput extends StatelessWidget {
  const _NameInput({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w400,
        fontSize: 15,
        color: AppColors.gray900,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.gray50,
        suffixIcon: GestureDetector(
          onTap: controller.clear,
          child: const Icon(Icons.close, size: 18, color: AppColors.gray400),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _StatusInput extends StatelessWidget {
  const _StatusInput({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 100,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w400,
        fontSize: 15,
        color: AppColors.gray900,
      ),
      decoration: InputDecoration(
        hintText: '상태 메시지를 입력하세요',
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 15,
          color: AppColors.gray300,
        ),
        filled: true,
        fillColor: AppColors.gray50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({required this.provider});
  final String provider;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (provider) {
      'naver' => ('네이버 계정으로 로그인됨', AppColors.naverGreen, AppColors.white),
      'apple' => ('Apple 계정으로 로그인됨', AppColors.appleBlack, AppColors.white),
      'admin' => ('관리자 계정', AppColors.gray700, AppColors.white),
      _ => ('카카오 계정으로 로그인됨', AppColors.kakaoYellow, AppColors.kakaoText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              provider.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 15,
              color: AppColors.gray900,
            ),
          ),
        ],
      ),
    );
  }
}
