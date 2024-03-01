import groovy.util.Node
import java.net.URI

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("kotlinx-serialization")

    id("maven-publish")
    id("signing")
//    id("io.codearte.nexus-staging")
}

group = "com.nativebrik"
version = "0.0.1"

android {
    namespace = "com.nativebrik.sdk"
    compileSdk = 34

    defaultConfig {
        minSdk = 26

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    buildFeatures {
        compose = true
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.2"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = "1.8"
    }
    publishing {
        singleVariant("release") {
            withJavadocJar()
            withSourcesJar()
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")
    implementation("androidx.compose.ui:ui-tooling:1.6.2")
    implementation("androidx.compose.ui:ui:1.6.2")
    implementation("androidx.compose.foundation:foundation:1.6.2")
    implementation("androidx.compose.runtime:runtime:1.6.2")
    implementation("io.coil-kt:coil:2.5.0")
    implementation("io.coil-kt:coil-compose:2.5.0")
    implementation("androidx.compose.material3:material3:1.2.0")
    implementation("androidx.navigation:navigation-compose:2.7.7")

    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}

afterEvaluate {

    publishing {
        publications {
            register<MavenPublication>("maven") {
                groupId = "com.nativebrik"
                artifactId = "sdk"
                version = "0.0.1"
                from(components["release"])

                pom {
                    name = "Nativebrik SDK for Android"
                    description = "Nativebrik is a tool that helps you to build/manage your mobile application."
                    url = "https://github.com/plaidev/nativebrik-sdk"
                    licenses {
                        license {
                            name = "The Apache License, Version 2.0"
                            url = "http://www.apache.org/licenses/LICENSE-2.0.txt"
                        }
                    }
                    developers {
                        developer {
                            id = "nativebrik"
                            name = "nativebrik"
                            email = "dev.share+nativebrik@plaid.co.jp"
                        }
                    }
                    scm {
                        connection = "scm:git:https://github.com/plaidev/karte-android-sdk.git\""
                        developerConnection = "scm:git:ssh://github.com/plaidev/karte-android-sdk.git"
                        url = "https://github.com/plaidev/nativebrik-sdk"
                    }
                }
            }
        }
        repositories {
            maven {
                url = URI("https://oss.sonatype.org/service/local/staging/deploy/maven2")
                credentials {
                    username = "xxx"
                    password = "xxx"
                }
            }
        }
    }
}
signing {
//    sign(publishing.publications["maven"])
}
//nexusStaging {
//    packageGroup = "com.nativebrik"
//    stagingProfileId = "xxx"
//    username = "ossrhUsername"
//    password = "ossrhPassword"
//}