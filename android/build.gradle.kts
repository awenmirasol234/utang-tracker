allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        try {
            val setCompileSdk =
                android.javaClass.methods.firstOrNull { method ->
                    method.name == "setCompileSdk" &&
                        method.parameterCount == 1 &&
                        (method.parameterTypes[0] == Int::class.javaPrimitiveType ||
                            method.parameterTypes[0] == Integer::class.java)
                }
            if (setCompileSdk != null) {
                setCompileSdk.invoke(android, 36)
                return@afterEvaluate
            }
            val setCompileSdkVersion =
                android.javaClass.methods.firstOrNull { method ->
                    method.name == "setCompileSdkVersion" && method.parameterCount == 1
                }
            if (setCompileSdkVersion != null) {
                setCompileSdkVersion.invoke(android, 36)
                return@afterEvaluate
            }
            val compileSdkVersion =
                android.javaClass.methods.firstOrNull { method ->
                    method.name == "compileSdkVersion" &&
                        method.parameterCount == 1 &&
                        method.parameterTypes[0] == Int::class.javaPrimitiveType
                }
            compileSdkVersion?.invoke(android, 36)
        } catch (_: Throwable) {
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
