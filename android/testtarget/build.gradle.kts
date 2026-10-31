plugins { alias(libs.plugins.android.application) }

/** Debug-only launcher used by emulator tests. Never shipped inside the JedaSholat APK. */
android {
    namespace = "id.jedasholat.testtarget"
    compileSdk = 35
    defaultConfig {
        applicationId = "id.jedasholat.testtarget"
        minSdk = 29
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
}
