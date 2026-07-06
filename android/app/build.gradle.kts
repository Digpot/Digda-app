import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// android/key.properties 에서 keystore 정보를 로드한다.
// 파일이 없으면(예: 개발자 머신 첫 클론 직후) release 빌드는 debug 키로 폴백한다.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// android/admob.properties(git 제외) 에서 실제 AdMob 앱 ID 를 로드한다.
// 파일이 없으면 구글 공식 "테스트" 앱 ID 로 폴백해 빌드가 깨지지 않게 한다.
val admobProperties = Properties()
val admobPropertiesFile = rootProject.file("admob.properties")
if (admobPropertiesFile.exists()) {
    admobProperties.load(FileInputStream(admobPropertiesFile))
}
val admobAppId = (admobProperties["admobAppId"] as String?)
    ?: "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.digda.app"
    // google_mobile_ads(AdMob)·Android 14 대응으로 compileSdk 34 이상을 보장한다.
    compileSdk = maxOf(flutter.compileSdkVersion, 34)
    // flutter.ndkVersion 기본값이 로컬 미설치 버전이라 AAB 심볼 스트립이 실패
    // ("failed to strip debug symbols") — 설치된 NDK 로 올려 고정한다.
    ndkVersion = maxOf(flutter.ndkVersion, "28.2.13676358")

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.digda.app"
        // google_mobile_ads(AdMob) 5.x 는 minSdk 23 이상을 요구한다.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        // Play 스토어 신규 제출은 targetSdk 34(Android 14) 이상을 요구한다.
        targetSdk = maxOf(flutter.targetSdkVersion, 34)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // AndroidManifest 의 ${admobAppId} 치환값. 실제 앱 ID 는 admob.properties 에서 주입.
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties["storeFile"] as String?
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // key.properties 가 있으면 release 키로, 없으면 debug 키로 서명.
            // 플레이스토어 업로드용 .aab 은 반드시 key.properties 가 존재한 상태에서 빌드해야 한다.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
