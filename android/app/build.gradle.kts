plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "de.arkanwett"
    compileSdk = 35

    defaultConfig {
        applicationId = "de.arkanwett"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    // Das Spiel selbst liegt unter /web und wird direkt als Asset eingebunden –
    // eine Kopie im Android-Verzeichnis waere sonst sofort veraltet.
    sourceSets["main"].assets.srcDir(rootProject.projectDir.parentFile.resolve("web"))

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-ktx:1.9.3")
}
