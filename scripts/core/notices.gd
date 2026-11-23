class_name Notices
extends RefCounted
## What the road is allowed to say.
##
## By 0.62 a run could put eighty different lines on the screen: SAW
## AHEAD, WAVE CLEAR +12, THICK SKIN SAVED 3, INTO THE THICK OF IT. Each
## was true and none could be read at a run, and under them the three
## that mattered (the gate you took, the bite you took, the boss) were
## lost. Players said it in four words: "too much text".
##
## So every line now has a rank, and the default is silence. Pure: the
## ranks, and whether a line of a rank may show right now.

## Never shown. The call is kept where the event happens so that a
## learning mode could voice it again, but the road does not.
const CHATTER := 0
## Shown if nothing else has been said for NICE_GAP seconds.
const NICE := 1
## Always shown.
const MUST := 2

## Seconds of quiet a NICE line needs before it.
const NICE_GAP := 1.4
## The longest a line may be, in words, both lines of a banner together.
## Counted by the tests over every line the game can say.
const MAX_WORDS := 8


static func shows(rank: int, since_last: float) -> bool:
	if rank >= MUST:
		return true
	if rank == NICE:
		return since_last >= NICE_GAP
	return false


## A banner that must be read holds its place: a lesser one cannot
## replace it while it is up.
static func banner_shows(rank: int, since_last: float, must_is_up: bool) -> bool:
	if rank >= MUST:
		return true
	return not must_is_up and shows(rank, since_last)


static func words(text: String) -> int:
	return text.replace("\n", " ").split(" ", false).size()
