# Memoring — Parser grammar (reminder-engine)

What `RuleBasedTimeIntentParser` understands. QA tests against this list.
The matched time phrase is **stripped** from the stored text.

## Relative durations
- `in N minutes` / `in N mins` — e.g. "in 10 minutes"
- `in N hours` / `in N hrs` — e.g. "in 2 hours"
- `in N days` — e.g. "in 3 days"
- `in N weeks`
- `in N months` — e.g. "in 8 months"
- `in N years`
- `in a/an <unit>` — e.g. "in an hour", "in a week"

## Named relative days
- `today` (+ optional time; defaults to 9:00 am if none)
- `tonight` → today 20:00
- `tomorrow` (+ optional time; default 9:00 am)
- `next <weekday>` — "next friday" → coming Friday 9:00 am (+ optional time)
- `<weekday>` — "monday" → next upcoming Monday

## Absolute dates
- `on <month> <day>` / `<month> <day>` — "on june 30", "dec 25" (+ optional time)
- defaults to 9:00 am if no time given; rolls to next year if the date already passed

## Time of day (combines with any date above)
- `9am`, `9 am`, `9:30pm`, `at 5pm`, `at 9`, `noon`, `midnight`
- bare hour ("at 5") → next upcoming 5 o'clock (am/pm chosen as the soonest future)

## Recurrence
- `daily` / `every day` (+ optional time; default 9:00 am)
- `weekly` / `every week`
- `every <weekday>` — "every monday" (+ optional time)
- `monthly` / `every month` — repeats on that day-of-month
- `yearly` / `annually` / `every year` (+ optional "on <month> <day>")

## Classification (short vs long)
- one-off: `< 30 days` → short, `>= 30 days` → long
- recurring: daily/weekly → short; monthly/yearly → long

## No-time / errors
- no parseable time → `ParseNeedsTime` (UI shows a time picker; never guess)
- computed time already passed → `ParseFailure(pastTime)`
- empty text → `ParseFailure(empty)`; over 500 chars → `ParseFailure(tooLong)`
