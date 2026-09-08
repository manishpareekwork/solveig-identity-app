allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/** macOS writes AppleDouble (._*) sidecars on exFAT; AAPT treats them as resource dirs and fails. */
fun Project.stripAppleDoubleFiles(root: java.io.File) {
    if (!root.exists()) return
    root.walkTopDown().maxDepth(16).forEach { file ->
        if (file.isFile && file.name.startsWith("._")) {
            file.delete()
        }
    }
}

val projectRoot: java.io.File = rootProject.projectDir.parentFile
    ?: error("Could not resolve Flutter project root")
val flutterBuildDir = java.io.File(projectRoot, "build")

val newBuildDir: Directory =
    rootProject.layout.projectDirectory.dir(flutterBuildDir.absolutePath)
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Strip after macOS writes sidecars and before any task reads build/ outputs (jars, AAPT, etc.).
gradle.taskGraph.beforeTask {
    if (project.rootProject == rootProject) {
        stripAppleDoubleFiles(flutterBuildDir)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
