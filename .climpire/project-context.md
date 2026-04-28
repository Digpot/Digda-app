# Project: digdaapp

## File Structure
```
├── android/
│   ├── app/
│   │   ├── src/
│   │   │   ├── debug/
│   │   │   │   ...
│   │   │   ├── main/
│   │   │   │   ...
│   │   │   └── profile/
│   │   │       ...
│   │   └── build.gradle.kts
│   ├── gradle/
│   │   └── wrapper/
│   │       ├── gradle-wrapper.jar
│   │       └── gradle-wrapper.properties
│   ├── build.gradle.kts
│   ├── digdaapp_android.iml
│   ├── gradle.properties
│   ├── gradlew
│   ├── gradlew.bat
│   ├── local.properties
│   └── settings.gradle.kts
├── assets/
│   ├── fonts/
│   │   ├── Inter-Bold.ttf
│   │   └── Inter-Regular.ttf
│   ├── icons/
│   ├── images/
│   └── svg/
│       ├── empty_state.svg
│       ├── kakao_logo.svg
│       └── logo.svg
├── design/
│   ├── wireframes/
│   │   ├── images/
│   │   │   ├── S1-Splash.png
│   │   │   ├── S10-Todo_List.png
│   │   │   ├── S2-1-Social_Login.png
│   │   │   ├── S2-2-Terms_Agreement.png
│   │   │   ├── S3A-1-Code_Input.png
│   │   │   ├── S3A-2-Code_Generate.png
│   │   │   ├── S3A-3-Create_New_Diary.png
│   │   │   ├── S3A-3-Create_Update_Diary.png
│   │   │   ├── S3A-Empty_State.svg.png
│   │   │   ├── S3B-Group_List.png
│   │   │   ├── S4-Group_Home.png
│   │   │   ├── S5-1-Day_Detail_Bottom_Sheet.png
│   │   │   ├── S5-1-Schedule_Detail.png
│   │   │   ├── S5-2-Add_Schedule.png
│   │   │   ├── S5-2-Participant_Popup.png
│   │   │   ├── S5-Schedule_Calendar.png
│   │   │   ├── S6-1-Diary_Detail.png
│   │   │   ├── S6-2-Write_Diary.png
│   │   │   ├── S6-3-Edit_Diary.png
│   │   │   ├── S6-Diary_Calendar.png
│   │   │   ├── S8-1-Edit_Profile.png
│   │   │   ├── S8-2-Notification_Settings.png
│   │   │   ├── S8-3-Privacy_Settings.png
│   │   │   ├── S8-My_Page.png
│   │   │   └── S9-Notifications.png
│   │   ├── problem/
│   │   │   ├── image1.png
│   │   │   ├── image2.png
│   │   │   └── image3.png
│   │   └── svg/
│   │       ├── S1-Splash.svg
│   │       ├── S10-Todo_List.svg
│   │       ├── S2-1-Social_Login.svg
│   │       ├── S2-2-Terms_Agreement.svg
│   │       ├── S3A-1-Code_Input.svg
│   │       ├── S3A-2-Code_Generate.svg
│   │       ├── S3A-3-Create_New_Diary.svg
│   │       ├── S3A-3-Create_Update_Diary.svg
│   │       ├── S3A-Empty_State.svg
│   │       ├── S3B-Group_List.svg
│   │       ├── S4-Group_Home.svg
│   │       ├── S5-1-Day_Detail_Bottom_Sheet.svg
│   │       ├── S5-1-Schedule_Detail.svg
│   │       ├── S5-2-Add_Schedule.svg
│   │       ├── S5-2-Participant_Popup.svg
│   │       ├── S5-Schedule_Calendar.svg
│   │       ├── S6-1-Diary_Detail.svg
│   │       ├── S6-2-Write_Diary.svg
│   │       ├── S6-3-Edit_Diary.svg
│   │       ├── S6-Diary_Calendar.svg
│   │       ├── S8-1-Edit_Profile.svg
│   │       ├── S8-2-Notification_Settings.svg
│   │       ├── S8-3-Privacy_Settings.svg
│   │       ├── S8-My_Page.svg
│   │       └── S9-Notifications.svg
│   └── figma-context.md
├── ios/
│   ├── Flutter/
│   │   ├── ephemeral/
│   │   │   ├── flutter_lldb_helper.py
│   │   │   └── flutter_lldbinit
│   │   ├── AppFrameworkInfo.plist
│   │   ├── Debug.xcconfig
│   │   ├── flutter_export_environment.sh
│   │   ├── Generated.xcconfig
│   │   └── Release.xcconfig
│   ├── Runner/
│   │   ├── Assets.xcassets/
│   │   │   ├── AppIcon.appiconset/
│   │   │   │   ...
│   │   │   └── LaunchImage.imageset/
│   │   │       ...
│   │   ├── Base.lproj/
│   │   │   ├── LaunchScreen.storyboard
│   │   │   └── Main.storyboard
│   │   ├── AppDelegate.swift
│   │   ├── GeneratedPluginRegistrant.h
│   │   ├── GeneratedPluginRegistrant.m
│   │   ├── Info.plist
│   │   ├── Runner-Bridging-Header.h
│   │   └── SceneDelegate.swift
│   ├── Runner.xcodeproj/
│   │   ├── project.xcworkspace/
│   │   │   ├── xcshareddata/
│   │   │   │   ...
│   │   │   └── contents.xcworkspacedata
│   │   ├── xcshareddata/
│   │   │   └── xcschemes/
│   │   │       ...
│   │   └── project.pbxproj
│   ├── Runner.xcworkspace/
│   │   ├── xcshareddata/
│   │   │   ├── IDEWorkspaceChecks.plist
│   │   │   └── WorkspaceSettings.xcsettings
│   │   └── contents.xcworkspacedata
│   └── RunnerTests/
│       └── RunnerTests.swift
├── lib/
│   ├── navigation/
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── social_login_screen.dart
│   │   │   └── terms_agreement_screen.dart
│   │   ├── diary/
│   │   │   ├── diary_calendar_screen.dart
│   │   │   ├── diary_detail_screen.dart
│   │   │   ├── edit_diary_screen.dart
│   │   │   └── write_diary_screen.dart
│   │   ├── game/
│   │   │   └── quiz_coming_soon_screen.dart
│   │   ├── group/
│   │   │   ├── group_home_screen.dart
│   │   │   └── group_list_screen.dart
│   │   ├── mypage/
│   │   │   ├── edit_profile_screen.dart
│   │   │   ├── my_page_screen.dart
│   │   │   ├── notification_settings_screen.dart
│   │   │   └── privacy_settings_screen.dart
│   │   ├── notification/
│   │   ├── notifications/
│   │   │   └── notifications_screen.dart
│   │   ├── onboarding/
│   │   │   ├── code_generate_screen.dart
│   │   │   ├── code_input_screen.dart
│   │   │   ├── create_diary_screen.dart
│   │   │   └── empty_state_screen.dart
│   │   ├── quiz/
│   │   ├── schedule/
│   │   │   ├── add_schedule_screen.dart
│   │   │   ├── schedule_calendar_screen.dart
│   │   │   └── schedule_detail_screen.dart
│   │   ├── splash/
│   │   │   └── splash_screen.dart
│   │   └── todo/
│   │       └── todo_list_screen.dart
│   ├── theme/
│   │   ├── colors.dart
│   │   ├── dimensions.dart
│   │   └── text_styles.dart
│   ├── widgets/
│   │   ├── app_bottom_nav_bar.dart
│   │   ├── back_header.dart
│   │   ├── center_title_header.dart
│   │   ├── diary_list_item.dart
│   │   ├── feature_card.dart
│   │   ├── group_list_tile.dart
│   │   ├── notification_item.dart
│   │   ├── outline_button.dart
│   │   ├── primary_button.dart
│   │   └── todo_item.dart
│   ├── app_router.dart
│   ├── app.dart
│   └── main.dart
├── linux/
│   ├── flutter/
│   │   ├── ephemeral/
│   │   ├── CMakeLists.txt
│   │   ├── generated_plugin_registrant.cc
│   │   ├── generated_plugin_registrant.h
│   │   └── generated_plugins.cmake
│   ├── runner/
│   │   ├── CMakeLists.txt
│   │   ├── main.cc
│   │   ├── my_application.cc
│   │   └── my_application.h
│   └── CMakeLists.txt
├── macos/
│   ├── Flutter/
│   │   ├── ephemeral/
│   │   │   ├── flutter_export_environment.sh
│   │   │   └── Flutter-Generated.xcconfig
│   │   ├── Flutter-Debug.xcconfig
│   │   ├── Flutter-Release.xcconfig
│   │   └── GeneratedPluginRegistrant.swift
│   ├── Runner/
│   │   ├── Assets.xcassets/
│   │   │   └── AppIcon.appiconset/
│   │   │       ...
│   │   ├── Base.lproj/
│   │   │   └── MainMenu.xib
│   │   ├── Configs/
│   │   │   ├── AppInfo.xcconfig
│   │   │   ├── Debug.xcconfig
│   │   │   ├── Release.xcconfig
│   │   │   └── Warnings.xcconfig
│   │   ├── AppDelegate.swift
│   │   ├── DebugProfile.entitlements
│   │   ├── Info.plist
│   │   ├── MainFlutterWindow.swift
│   │   └── Release.entitlements
│   ├── Runner.xcodeproj/
│   │   ├── project.xcworkspace/
│   │   │   └── xcshareddata/
│   │   │       ...
│   │   ├── xcshareddata/
│   │   │   └── xcschemes/
│   │   │       ...
│   │   └── project.pbxproj
│   ├── Runner.xcworkspace/
│   │   ├── xcshareddata/
│   │   │   └── IDEWorkspaceChecks.plist
│   │   └── contents.xcworkspacedata
│   └── RunnerTests/
│       └── RunnerTests.swift
├── test/
│   └── widget_test.dart
├── web/
│   ├── icons/
│   │   ├── Icon-192.png
│   │   ├── Icon-512.png
│   │   ├── Icon-maskable-192.png
│   │   └── Icon-maskable-512.png
│   ├── favicon.png
│   ├── index.html
│   └── manifest.json
├── windows/
│   ├── flutter/
│   │   ├── ephemeral/
│   │   │   └── generated_config.cmake
│   │   ├── CMakeLists.txt
│   │   ├── generated_plugin_registrant.cc
│   │   ├── generated_plugin_registrant.h
│   │   └── generated_plugins.cmake
│   ├── runner/
│   │   ├── resources/
│   │   │   └── app_icon.ico
│   │   ├── CMakeLists.txt
│   │   ├── flutter_window.cpp
│   │   ├── flutter_window.h
│   │   ├── main.cpp
│   │   ├── resource.h
│   │   ├── runner.exe.manifest
│   │   ├── Runner.rc
│   │   ├── utils.cpp
│   │   ├── utils.h
│   │   ├── win32_window.cpp
│   │   └── win32_window.h
│   └── CMakeLists.txt
├── analysis_options.yaml
├── CLAUDE.md
├── digdaapp.iml
├── pubspec.lock
├── pubspec.yaml
└── README.md
```

## Key Files
- lib/ (39 files)

## README (first 20 lines)
# 디그다 (DiGDa) - 디지털 그룹 다이어리

Flutter로 구현한 커플/그룹을 위한 공유 다이어리 앱입니다.

## 주요 기능

- **소셜 로그인**: 카카오, 네이버, Apple 로그인
- **다이어리 그룹**: 코드로 참여하거나 새 다이어리 생성
- **일정 관리**: 캘린더 기반 일정 추가/확인
- **공유 일기**: 그룹 멤버 모두가 같은 날 일기 작성
- **퀴즈**: 서로를 얼마나 아는지 테스트 (Coming Soon)
- **투두리스트**: 함께 해야 할 일 관리
- **알림**: 일정/일기/기념일 알림

## 기술 스택

- Flutter 3.41.1 / Dart SDK >=3.2.0
- `table_calendar: ^3.1.0` — 캘린더 UI
- `go_router: ^14.0.0` — 라우팅
- `intl: ^0.19.0` — 날짜/국제화
