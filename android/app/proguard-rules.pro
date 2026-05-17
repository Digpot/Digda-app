# ───── Flutter 기본 ─────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# ───── Firebase ─────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ───── Kakao SDK ─────
-keep class com.kakao.sdk.**.model.* { *; }
-keep class * extends com.google.gson.TypeAdapter
-keepattributes Signature, *Annotation*

# ───── Naver Login SDK ─────
-keep class com.nhn.android.naverlogin.** { *; }
-keep class com.navercorp.nid.** { *; }
-dontwarn com.nhn.android.naverlogin.**
-dontwarn com.navercorp.nid.**

# ───── Apple Sign-In (sign_in_with_apple) ─────
-keep class com.aboutyou.dart_packages.sign_in_with_apple.** { *; }

# ───── Dio + Retrofit/Json 직렬화 보호 ─────
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ───── Play Core (deferred components) — 일부 디바이스 누락 클래스 경고 무시 ─────
-dontwarn com.google.android.play.core.**

# ───── 기존 ─────
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE
