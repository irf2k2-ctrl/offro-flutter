// ==========================================
// FILE: android/app/build.gradle.kts  (APP level)
// Flutter Android build config for Offro
// ==========================================

import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied AFTER the Android and Kotlin
    // Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase plugins
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.offro.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    // (1) Java source/target compatibility
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
	isCoreLibraryDesugaringEnabled = true 
    }

    // (2) Kotlin jvmTarget via Android DSL
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.offro.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: replace with your release signing config before publishing.
            signingConfig = signingConfigs.getByName("debug")
            // Explicitly disable BOTH. AGP requires them to match:
            // if `isShrinkResources` is true anywhere, `isMinifyEnabled` must
            // also be true. Setting both to false avoids the mismatch.
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// (3) Belt-and-suspenders: force every Kotlin compile task to use jvmTarget 17,
//     regardless of whether kotlinOptions above is respected by the current
//     Kotlin Gradle Plugin version.
tasks.withType<KotlinCompile>().configureEach {
    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") 	
}
