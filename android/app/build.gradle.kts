import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Bagian ini untuk membaca versi dari file local.properties
// Kode ini ditambahkan untuk menggantikan `flutter.minSdkVersion` dll.
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}
val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toInt() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    // [PERBAIKAN 2] Menyesuaikan namespace agar cocok dengan Firebase
    namespace = "com.desakumantan.desaku"
    compileSdk = 35 // Menggunakan versi SDK yang stabil
    ndkVersion = "27.0.12077973"

    compileOptions {
        // [PENAMBAHAN 3] Mengaktifkan desugaring
        isCoreLibraryDesugaringEnabled = true
        // Menggunakan versi Java yang lebih rendah untuk kompatibilitas desugaring
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // [PERBAIKAN 4] Mengubah applicationId agar sama persis dengan di google-services.json
        applicationId = "com.desakumantan.desaku"
        minSdk = 21 // Menetapkan minSdk secara eksplisit
        targetSdk = 35 // Menetapkan targetSdk secara eksplisit
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        // [PENAMBAHAN 5] Mengaktifkan multidex
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // [PENAMBAHAN 6] Menambahkan Firebase BoM dan library desugaring
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-analytics")
    
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
