import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Dart-defines arrive base64-encoded, comma-joined (see Flutter's gradle_utils).
val dartDefines: Map<String, String> by lazy {
    (project.findProperty("dart-defines") as String?)
        ?.split(',')
        ?.mapNotNull { entry ->
            if (entry.isBlank()) null else {
                val decoded = String(Base64.getDecoder().decode(entry), Charsets.UTF_8)
                val idx = decoded.indexOf('=')
                if (idx <= 0) null else decoded.substring(0, idx) to decoded.substring(idx + 1)
            }
        }?.toMap() ?: emptyMap()
}

android {
    namespace = "com.cinnamontrace.cinnamon_trace"
    compileSdk = 37
    // Pinned to the locally installed NDK; sdkmanager auto-download crashes on this machine.
    ndkVersion = "30.0.15729638"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cinnamontrace.cinnamon_trace"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Google Maps SDK key from `flutter run --dart-define=MAPS_API_KEY=...`.
        // Flutter forwards dart-defines base64-encoded, comma-joined in the
        // `dart-defines` property. Empty default keeps builds green without a
        // key; the map picker degrades gracefully (see maps_api_key.dart).
        manifestPlaceholders["MAPS_API_KEY"] = dartDefines["MAPS_API_KEY"] ?: ""
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
