buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Konfigurasi Build Directory
val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // ✅ PERBAIKAN: Gunakan afterEvaluate agar plugin sudah ter-apply
    project.afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null && androidExt is com.android.build.gradle.BaseExtension) {
            if (androidExt.namespace == null) {
                // Ambil package dari AndroidManifest.xml sebagai fallback
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val manifestContent = manifestFile.readText()
                    val packageMatch = Regex("""package\s*=\s*"([^"]+)"""")
                        .find(manifestContent)
                    val packageName = packageMatch?.groupValues?.get(1)
                    if (!packageName.isNullOrEmpty()) {
                        androidExt.namespace = packageName
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}