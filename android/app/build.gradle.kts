plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.rasoi.mitra.rasoi_mitra2"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        register("release") {
            storeFile = file("rasoi-mitra-key.jks")
            storePassword = System.getenv("STORE_PASSWORD") ?: "RasoiMitra@YCCE"
            keyAlias = "rasoi-mitra-alias"
            keyPassword = System.getenv("KEY_PASSWORD") ?: "RasoiMitra@YCCE"
        }
    }

    defaultConfig {
        applicationId = "com.rasoi.mitra.rasoi_mitra2"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}