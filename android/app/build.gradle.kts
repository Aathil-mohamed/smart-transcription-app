plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Apply Google Services plugin so Firebase picks up android/app/google-services.json
    id("com.google.gms.google-services") apply false
}

android {
    namespace = "com.smarttranscribe.smart_transcription_app"
    // Use explicit compile SDK to ensure broad compatibility
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.smarttranscribe.smart_transcription_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Set conservative minSdk to support older Android devices (>=21)
        minSdk = flutter.minSdkVersion
        // Target recent SDK for compatibility and Play Store requirements
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Apply Google Services plugin at the end so the classpath added in the
// root build.gradle.kts is available. This injects values from
// android/app/google-services.json into the build.
apply(plugin = "com.google.gms.google-services")
