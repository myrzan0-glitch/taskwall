package app.taskwall.shared

/** A line shown above the add button: about starting, doing and finishing. */
data class Quote(val text: String, val author: String)

/**
 * One quote a day, the same all day and for everyone. Days walk through the list
 * in order, so every quote comes round before any repeats.
 *
 * Short lines only, from writers whose words are long out of copyright; none takes
 * more than three lines above the add button.
 */
object DailyQuotes {
    val all: List<Quote> = listOf(
        Quote("While we are postponing, life speeds by.", "Seneca"),
        Quote("Waste no more time arguing what a good man should be. Be one.", "Marcus Aurelius"),
        Quote("First say to yourself what you would be; and then do what you have to do.", "Epictetus"),
        Quote("Well begun is half done.", "Aristotle"),
        Quote("Hold every hour in your grasp.", "Seneca"),
        Quote("The impediment to action advances action. What stands in the way becomes the way.", "Marcus Aurelius"),
        Quote("No great thing is created suddenly.", "Epictetus"),
        Quote("A journey of a thousand miles begins with a single step.", "Lao Tzu"),
        Quote("Life is long if you know how to use it.", "Seneca"),
        Quote("Confine yourself to the present.", "Marcus Aurelius"),
        Quote("Make the best use of what is in your power, and take the rest as it happens.", "Epictetus"),
        Quote("He who has begun has half done. Dare to be wise; begin!", "Horace"),
        Quote("Lost time is never found again.", "Benjamin Franklin"),
        Quote("Nothing is ours, except time.", "Seneca"),
        Quote("Very little is needed to make a happy life.", "Marcus Aurelius"),
        Quote("No man is free who is not master of himself.", "Epictetus"),
        Quote("The beginning is the most important part of the work.", "Plato"),
        Quote("Well done is better than well said.", "Benjamin Franklin"),
        Quote("No man was ever wise by chance.", "Seneca"),
        Quote("If it is not right, do not do it; if it is not true, do not say it.", "Marcus Aurelius"),
        Quote("Knowing is not enough; we must apply.", "Goethe"),
        Quote("Seize the day, put very little trust in tomorrow.", "Horace"),
        Quote("We suffer more often in imagination than in reality.", "Seneca"),
        Quote("Do every act of your life as though it were the very last act of your life.", "Marcus Aurelius"),
        Quote("Do what you can, with what you have, where you are.", "Theodore Roosevelt"),
        Quote("Dripping water hollows out stone.", "Ovid"),
        Quote("Energy and persistence conquer all things.", "Benjamin Franklin"),
        Quote("Begin at once to live.", "Seneca"),
        Quote("Patience and diligence, like faith, remove mountains.", "William Penn"),
        Quote("Never put off till tomorrow what you can do today.", "Thomas Jefferson"),
        Quote("Act well your part; there all the honour lies.", "Alexander Pope"),
        Quote("If you want to improve, be content to be thought foolish and stupid.", "Epictetus"),
    )

    /** Today's quote. */
    fun quoteFor(day: CalendarDay): Quote = all[day.epochDay.mod(all.size)]
}
