import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release-Signatur: aus android/key.properties (lokal) oder aus Umgebungsvariablen
// (CI, Werte aus GitHub-Secrets). Siehe docs/release/README.md.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(property: String, env: String): String? =
    keyProperties.getProperty(property) ?: System.getenv(env)?.takeIf { it.isNotEmpty() }

val releaseStoreFile = signingValue("storeFile", "MYDEX_KEYSTORE")
if (System.getenv("MYDEX_REQUIRE_SIGNING") == "true" && releaseStoreFile == null) {
    throw GradleException("Release-Signatur fehlt (MYDEX_KEYSTORE bzw. key.properties).")
}

android {
    namespace = "io.github.josunlp.mydex_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.josunlp.mydex_app"
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
    }

    // „offline“: Standardausgabe ohne Internet-Berechtigung (GrapheneOS-Abnahme).
    // „sync“: zusätzlich Internet für den optionalen Abgleich (ADR 0012).
    flavorDimensions += "edition"
    productFlavors {
        create("offline") {
            dimension = "edition"
            manifestPlaceholders["appLabel"] = "myDex"
        }
        create("sync") {
            dimension = "edition"
            manifestPlaceholders["appLabel"] = "myDex Sync"
            applicationIdSuffix = ".sync"
            versionNameSuffix = "-sync"
        }
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = signingValue("storePassword", "MYDEX_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "MYDEX_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "MYDEX_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Ohne Release-Schlüssel (lokale Entwicklung) mit dem Debug-Schlüssel,
            // damit `flutter run --release` funktioniert. Veröffentlichte Pakete
            // werden nur mit MYDEX_REQUIRE_SIGNING=true gebaut.
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
