
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.smart_attendance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

   
defaultConfig {
    applicationId = "com.example.smart_attendance"

    minSdk = 23
    targetSdk = flutter.targetSdkVersion

    versionCode = flutter.versionCode
    versionName = flutter.versionName
}


    buildTypes {
        release {
            // Untuk pengujian saja, menggunakan debug signing.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Dependency yang dibutuhkan camera plugin.
    implementation("androidx.concurrent:concurrent-futures:1.2.0")
}

flutter {
    source = "../.."
}
