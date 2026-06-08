plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Tambahin plugin Google Services di sini
    id("com.google.gms.google-services")
}

android {
    namespace = "com.mdn.laundry"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true 
    }

    // Mengatur target JVM untuk Kotlin menggunakan cara baru
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            // Jika ingin mengabaikan warning kotlin, bisa aktifkan ini:
            // allWarningsAsErrors.set(false)
        }
    }

    defaultConfig {
        applicationId = "com.mdn.laundry"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // PERBAIKAN: Format lintOptions disesuaikan ke Kotlin DSL yang benar
    lint {
        disable.add("InvalidPackage")
        warningsAsErrors = false
        abortOnError = false
        quiet = true  
    }

    // KOTLIN OPTIONS LAMA YANG ERROR SUDAH DIHAPUS DARI SINI

}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}