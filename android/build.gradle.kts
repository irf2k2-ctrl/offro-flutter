// ==========================================
// FILE: android/build.gradle.kts  (PROJECT / ROOT level)
// ==========================================
// NOTE: DO NOT add a `buildscript { ... }` block here.
//       All plugin versions are declared in `settings.gradle.kts`
//       via the modern declarative plugins { ... } block.
//       Duplicating them here causes version conflicts.
// ==========================================

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Standard Flutter clean task — deletes the root build directory.
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
