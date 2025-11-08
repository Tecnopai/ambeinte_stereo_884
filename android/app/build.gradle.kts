import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
}

android {
    namespace = "com.miltonbass.ambientestereo884"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        // Use Java 21 as the Kotlin jvmTarget to match the Java toolchain.
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        applicationId = "com.miltonbass.ambientestereo884"
        multiDexEnabled = true
        
        // SDK mínimo actualizado a 21 para Android Auto/Automotive
        // (Flutter.minSdkVersion ya debería ser >= 21)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystoreProperties = Properties()
            val keystoreFile = rootProject.file("key.properties")
            if (keystoreFile.exists()) {
                keystoreProperties.load(FileInputStream(keystoreFile))
            }

            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // BOM centraliza versiones de Firebase
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))

    // Dependencias específicas de Firebase
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-common")
    implementation("com.google.firebase:firebase-config")
    implementation("com.google.firebase:firebase-firestore")

    // Librerías Android
    implementation("androidx.media:media:1.7.0")
    implementation("androidx.core:core-ktx:1.12.0")
}

flutter {
    source = "../.."
}