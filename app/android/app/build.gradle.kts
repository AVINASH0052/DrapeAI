plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.sugatai.sugatai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.sugatai.sugatai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val alias = keystoreProperties["keyAlias"] as String?
            val keyPassword = keystoreProperties["keyPassword"] as String?
            val storeFilePath = keystoreProperties["storeFile"] as String?
            val storePassword = keystoreProperties["storePassword"] as String?
            if (
                keystorePropertiesFile.exists() &&
                !alias.isNullOrBlank() &&
                !keyPassword.isNullOrBlank() &&
                !storeFilePath.isNullOrBlank() &&
                !storePassword.isNullOrBlank()
            ) {
                keyAlias = alias
                this.keyPassword = keyPassword
                storeFile = file(storeFilePath)
                this.storePassword = storePassword
            }
        }
    }

    buildTypes {
        release {
            val storeFilePath = keystoreProperties["storeFile"] as String?
            val releaseStore = storeFilePath?.let { file(it) }
            val releaseReady =
                keystorePropertiesFile.exists() &&
                    !keystoreProperties["keyAlias"].toString().isBlank() &&
                    !keystoreProperties["keyPassword"].toString().isBlank() &&
                    !storeFilePath.isNullOrBlank() &&
                    !keystoreProperties["storePassword"].toString().isBlank() &&
                    releaseStore?.isFile == true
            val assemblingRelease =
                gradle.startParameter.taskNames.any { name ->
                    name.contains("Release", ignoreCase = true)
                }
            if (assemblingRelease && !releaseReady) {
                throw GradleException(
                    "Release signing is required. Copy android/key.properties.example " +
                        "to android/key.properties and point storeFile at the upload keystore."
                )
            }
            if (releaseReady) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
