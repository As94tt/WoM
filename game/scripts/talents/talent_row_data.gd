class_name TalentRowData
extends Resource
## Eine Reihe eines Talentbaums (Ticket #20).
##
## CHOICE – „Wahl“: 2–3 Talente, von denen genau eins gewählt werden kann
##          (1 Punkt).
## RANKS  – „Ränge“: jedes Talent hat 1–3 Ränge, jeder Rang kostet 1 Punkt.
enum Kind { CHOICE, RANKS }

@export var kind: Kind = Kind.CHOICE
## Punkte, die in den Reihen darüber ausgegeben sein müssen, damit diese Reihe
## frei ist (0 = von Anfang an).
@export_range(0, 100) var required_points := 0
@export var talents: Array[TalentData] = []


func is_choice() -> bool:
	return kind == Kind.CHOICE


## Höchster Rang eines Talents in dieser Reihe (Wahl: immer 1).
func max_rank_of(talent: TalentData) -> int:
	if talent == null:
		return 0
	return 1 if is_choice() else clampi(talent.max_ranks, 1, 3)
