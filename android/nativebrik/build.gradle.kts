plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("kotlinx-serialization")

    id("maven-publish")
    id("signing")
}

group = "com.nativebrik"
version = "0.5.0"

android {
    namespace = "com.nativebrik.sdk"
    compileSdk = 36

    defaultConfig {
        minSdk = 26

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")

        aarMetadata {
            minCompileSdk = 26
        }
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
//            withJavadocJar() // こっちだとsigningに間に合わないので諦めて空にする
            withSourcesJar()
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")
    implementation("androidx.compose.ui:ui-tooling:1.6.4")
    implementation("androidx.compose.ui:ui:1.6.4")
    implementation("androidx.compose.foundation:foundation:1.6.4")
    implementation("androidx.compose.runtime:runtime:1.6.4")
    implementation("io.coil-kt:coil:2.5.0")
    implementation("io.coil-kt:coil-compose:2.5.0")
    implementation("androidx.compose.material3:material3:1.2.1")
    implementation("androidx.navigation:navigation-compose:2.7.7")

    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.14.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}

tasks.register<Jar>("javadocEmptyJar") {
    archiveClassifier = "javadoc"
}
tasks.register<Zip>("makeArchive") {
    dependsOn("publishMavenPublicationToMavenRepository")
    from(layout.buildDirectory.dir("repos/com/nativebrik/sdk/$version"))
    into("com/nativebrik/sdk/$version")
}

afterEvaluate {
    publishing {
        publications {
            register<MavenPublication>("maven") {
                groupId = project.group as String
                artifactId = "sdk"
                version = project.version as String
                from(components["release"])
                artifact(tasks["javadocEmptyJar"])

                pom {
                    name = "Nativebrik SDK"
                    description =
                        "Nativebrik is a tool that helps you to build/manage your mobile application."
                    url = "https://github.com/plaidev/nativebrik-sdk"
                    licenses {
                        license {
                            name = "The Apache License, Version 2.0"
                            url = "https://github.com/plaidev/nativebrik-sdk/blob/main/LICENSE"
                            distribution = "repo"
                        }
                    }
                    developers {
                        developer {
                            id = "nativebrik"
                            name = "nativebrik"
                            email = "dev.share@nativebrik.com"
                        }
                    }
                    scm {
                        connection = "scm:git:https://github.com/plaidev/nativebrik-sdk.git"
                        developerConnection = "scm:git:ssh://github.com/plaidev/nativebrik-sdk.git"
                        url = "https://github.com/plaidev/nativebrik-sdk"
                    }
                }
            }
        }
        repositories {
            maven {
                url = uri(layout.buildDirectory.dir("repos"))
            }
        }
    }
    signing {
        val signingKey = System.getenv("GPG_SIGNING_KEY")
        val signingKeyPassphrase = System.getenv("GPG_SIGNING_KEY_PASSPHRASE")
        useInMemoryPgpKeys(signingKey, signingKeyPassphrase)
        sign(publishing.publications["maven"])
    }
}
