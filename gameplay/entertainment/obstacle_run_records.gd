class_name ObstacleRunRecords
extends RefCounted


const ARCHIVE_PATH := "user://food_catch_records_v1.json"
const MAX_ENTRIES := 10


static func load_archive() -> Dictionary:
	return AtomicJson.read(
		ARCHIVE_PATH
	)


static func save_archive(
	records: Dictionary
) -> bool:
	return AtomicJson.write(
		ARCHIVE_PATH,
		records
	)


static func top_score(
	records: Dictionary
) -> int:
	return maxi(
		0,
		int(
			records.get(
				"best_score",
				0
			)
		)
	)


static func record(
	records: Dictionary,
	score: int,
	eaten: int,
	match_id: String,
	timestamp: int
) -> Dictionary:
	var entries: Array = records.get(
		"entries",
		[]
	).duplicate(
		true
	)

	for index in entries.size():
		var existing: Dictionary = entries[index]
		if String(
			existing.get(
				"match_id",
				""
			)
		) == match_id:
			return {
				"rank": index + 1,
				"new_top1": false,
				"best_score": top_score(records),
			}

	var safe_score := maxi(
		0,
		score
	)
	var previous_top := top_score(
		records
	)
	var new_top1 := (
		safe_score > previous_top
	)

	entries.append({
		"score": safe_score,
		"eaten": maxi(
			0,
			eaten
		),
		"at_unix": timestamp,
		"match_id": match_id,
	})
	entries.sort_custom(
		func(
			a: Dictionary,
			b: Dictionary
		) -> bool:
			var a_score := int(
				a.get(
					"score",
					0
				)
			)
			var b_score := int(
				b.get(
					"score",
					0
				)
			)
			if a_score != b_score:
				return a_score > b_score
			return int(
				a.get(
					"at_unix",
					0
				)
			) < int(
				b.get(
					"at_unix",
					0
				)
			)
	)

	if entries.size() > MAX_ENTRIES:
		entries.resize(
			MAX_ENTRIES
		)

	var rank := 0
	for index in entries.size():
		var entry: Dictionary = entries[index]
		if String(
			entry.get(
				"match_id",
				""
			)
		) == match_id:
			rank = index + 1
			break

	records["entries"] = entries
	records["best_score"] = maxi(
		previous_top,
		safe_score
	)

	return {
		"rank": rank,
		"new_top1": new_top1,
		"best_score": int(
			records.get(
				"best_score",
				safe_score
			)
		),
	}
