package app.taskwall.shared

/**
 * One story in Reads, under the tasks on Today: what someone wise said about getting
 * things done, and how to use it on today's list.
 *
 * Quotes come from texts in the public domain: an old translation, or the original
 * (Latin, Kazakh) with our own translation beneath it.
 */
data class Read(
    val id: String,
    val author: String,
    val minutes: Int,
    val title: String,
    val subtitle: String,
    /** Paragraphs before the quote. */
    val opening: List<String>,
    /** The original words, when the quote is our own translation. */
    val quoteOriginal: String?,
    val quote: String,
    /** Where the quote comes from, and whose translation it is. */
    val source: String,
    /** Paragraphs after the quote. */
    val closing: List<String>,
) {
    /** What Share sends: the title, the quote and who said it. */
    val shareText: String get() = "$title\n\n“$quote”\n— $author"
}

object Reads {
    val all: List<Read> = listOf(
        Read(
            id = "marcus-get-up",
            author = "Marcus Aurelius",
            minutes = 4,
            title = "Get up and do the work",
            subtitle = "What a Roman emperor told himself on cold mornings",
            opening = listOf(
                "Marcus Aurelius ran the Roman Empire and led its armies on the frontier, and some mornings he still did not want to get out of bed. We know because he wrote it down. His private notebook, never meant for anyone else, opens Book 5 with an argument against his own blanket.",
            ),
            quoteOriginal = null,
            quote = "In the morning when thou risest unwillingly, let this thought be present: I am rising to the work of a human being.",
            source = "Meditations 5.1 · translated by George Long",
            closing = listOf(
                "He doesn’t wait to feel ready. He reminds himself what the day is for. The plants, the birds, the ants and the bees all get on with their part of the work, he writes; why should a person refuse to do theirs?",
                "The trick still works. The hardest moment of any task is the minute before you start it, when it is still a whole idea instead of a first small step. Name the first step, take it, and the rest of the morning has somewhere to go.",
            ),
        ),
        Read(
            id = "seneca-short-life",
            author = "Seneca",
            minutes = 4,
            title = "Life isn’t short. We waste it.",
            subtitle = "On the Shortness of Life, in four minutes",
            opening = listOf(
                "Around the year 49, Seneca wrote a long letter to his friend Paulinus, who looked after Rome’s grain supply. Its whole argument fits in one sentence, and it is the sentence people still quote.",
            ),
            quoteOriginal = "Non exiguum temporis habemus, sed multum perdidimus.",
            quote = "We are not given a short time, but we waste much of it.",
            source = "On the Shortness of Life 1.3 · our translation",
            closing = listOf(
                "Seneca’s complaint isn’t that people are idle. It’s that they are busy with the wrong things: other people’s errands, other people’s opinions, plans for a later that never quite arrives. We guard our money carefully, he notes, and give our time away to anyone who asks for it.",
                "Your list is where that changes. A task with a time on it is a decision about your life, made in advance. Look at today’s list and ask of each line: is this mine, or did I just say yes?",
            ),
        ),
        Read(
            id = "abai-five-things",
            author = "Abai Kunanbayuly",
            minutes = 4,
            title = "Five things to run toward",
            subtitle = "A Kazakh poet’s short list for a whole person, and a full day",
            opening = listOf(
                "Abai Kunanbayuly, the Kazakh poet and thinker, liked to teach in lists. In a poem from 1886 he names five things to keep away from and five to hold close, if you mean to become a real person.",
            ),
            quoteOriginal = "Талап, еңбек, терең ой,\nҚанағат, рақым, ойлап қой —\nБес асыл іс, көнсеңіз.",
            quote = "Striving, work and deep thought, contentment and kindness: keep them in mind. These are the five precious deeds.",
            source = "“Ғылым таппай мақтанба”, 1886 · our translation",
            closing = listOf(
                "The five enemies are just as plain: gossip, lies, boasting, laziness and squandering. Laziness sits among them as an ordinary habit, not a mood to wait out. You feed it or you starve it.",
                "Read the good list against your tasks. Striving is choosing the task that matters; work is starting it; deep thought is doing it well. Contentment is crossing it off and stopping there, without blaming yourself for the rest of the list. Kindness is the task you do for someone else.",
            ),
        ),
    )

    fun byId(id: String): Read? = all.firstOrNull { it.id == id }
}
