package app.taskwall.shared

/**
 * Where [TaskWallStore] keeps its JSON. Each platform supplies one: the iOS
 * app writes into the App Group container so its shortcuts can read it too.
 */
interface TextFileStore {
    fun read(): String?
    fun write(text: String)
}

class InMemoryTextFileStore(private var text: String? = null) : TextFileStore {
    override fun read(): String? = text
    override fun write(text: String) {
        this.text = text
    }
}
