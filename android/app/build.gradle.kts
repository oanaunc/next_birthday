plugins { id("com.android.application") }
android {
    namespace = "com.oanarinaldi.nextbirthday"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.oanarinaldi.nextbirthday"
        minSdk = 30
        targetSdk = 36
        versionCode = 1
        versionName = "2.0"
        buildConfigField("String", "REVIEW_CODE_SHA256", "\"" + providers.environmentVariable("NEXTBIRTHDAY_REVIEW_CODE_SHA256").getOrElse("") + "\"")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    buildFeatures { buildConfig = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    signingConfigs {
        providers.environmentVariable("NEXTBIRTHDAY_UPLOAD_KEYSTORE").orNull?.let { path ->
            create("upload") {
                storeFile = file(path)
                storePassword = providers.environmentVariable("NEXTBIRTHDAY_UPLOAD_STORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("NEXTBIRTHDAY_UPLOAD_KEY_ALIAS").get()
                keyPassword = providers.environmentVariable("NEXTBIRTHDAY_UPLOAD_KEY_PASSWORD").get()
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
dependencies {
    implementation("androidx.activity:activity:1.13.0")
    implementation("androidx.webkit:webkit:1.15.0")
    implementation("androidx.core:core:1.17.0")
    implementation("androidx.fragment:fragment:1.8.9")
    implementation("com.android.billingclient:billing:8.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("com.google.errorprone:error_prone_annotations:2.36.0")
}
