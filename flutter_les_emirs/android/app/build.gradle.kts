plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_les_emirs"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = "21"
    }

    defaultConfig {
        applicationId = "com.example.flutter_les_emirs"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // =========================================================
    // BLOC CORRIGÉ POUR LES FLAVORS (KOTLIN DSL)
    // =========================================================

    // Déclare la dimension de vos saveurs
    flavorDimensions += listOf("app_mode")

    productFlavors {
        // 1. Version ACCUEIL (Route par défaut) - Renommé de 'main' à 'app'
        // Package ID final: com.example.flutter_les_emirs.app
        create("app") {
            dimension = "app_mode"
            applicationIdSuffix = ".app"
            resValue("string", "app_name", "Emirs - Accueil")
        }

        // 2. Version DASHBOARD (Route /dashboard)
        // Package ID final: com.example.flutter_les_emirs.dashboard
        create("dashboard") {
            dimension = "app_mode"
            applicationIdSuffix = ".dashboard"
            resValue("string", "app_name", "Emirs - Dashboard")
        }

        // 3. Version ADMIN (Route /admin)
        // Package ID final: com.example.flutter_les_emirs.admin
        create("admin") {
            dimension = "app_mode"
            applicationIdSuffix = ".admin"
            resValue("string", "app_name", "Emirs - Admin")
        }
    }

    // =========================================================
    // FIN DU BLOC FLAVORS
    // =========================================================

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}