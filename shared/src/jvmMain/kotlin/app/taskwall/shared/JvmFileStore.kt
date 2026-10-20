package app.taskwall.shared

import java.io.File

/** Plain file storage for the JVM target (tests and desktop tooling). */
class JvmFileStore(private val file: File) : TextFileStore {
    override fun read(): String? = if (file.exists()) file.readText() else null

    override fun write(text: String) {
        file.parentFile?.mkdirs()
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(text)
        if (!tmp.renameTo(file)) {
            file.writeText(text)
            tmp.delete()
        }
    }
}
