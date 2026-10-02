class_name TetrisRecords
extends RefCounted

# Records are part of the same atomic metadata write as the rewards. This
# archive is used only when that metadata is deleted at the end of a pet life.
const ARCHIVE_PATH := "user://tetris_records_v1.json"
const INITIAL_RECORD := 5000

static func load_archive() -> Dictionary:
	if not FileAccess.file_exists(ARCHIVE_PATH):
		return {}
	var file := FileAccess.open(ARCHIVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func top_score(records: Dictionary) -> int:
	return maxi(INITIAL_RECORD, int(records.get("best_score", INITIAL_RECORD)))

static func record(records: Dictionary, session: TetrisSession, day: String, timestamp: int) -> Dictionary:
	var previous_top := top_score(records)
	var broken := session.score > previous_top
	# day is YYYY-MM-DD in local device time; a backward clock does not reopen
	# a day already rewarded. The comparison also survives new pet lives.
	var bonus := broken and day > str(records.get("last_bonus_day", ""))
	var entries: Array = records.get("entries", []).duplicate(true)
	entries.append({"score": session.score, "lines": session.lines,
		"level": session.level(), "at_unix": timestamp, "match_id": session.match_id})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.score) > int(b.score) if int(a.score) != int(b.score) else int(a.at_unix) < int(b.at_unix))
	if entries.size() > 10:
		entries.resize(10)
	var rank := 0
	for index in entries.size():
		if str(entries[index].match_id) == session.match_id:
			rank = index + 1
			break
	records["entries"] = entries
	records["best_score"] = maxi(previous_top, session.score)
	if bonus:
		records["last_bonus_day"] = day
	return {"broken_record": broken, "bonus_chests": 1 if bonus else 0, "rank": rank}
