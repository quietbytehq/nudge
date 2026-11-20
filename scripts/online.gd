class_name Online
extends RefCounted
## Posts a qualifying score to the global top 100 at nudge.quietbytehq.uk.
## Only the typed name, the score, the table and the game version are sent.
## It never blocks the game: if there is no internet the post is just dropped.

const SITE := "nudge.quietbytehq.uk"
const URL := "https://nudge.quietbytehq.uk/api/submit"


static func submit(host: Node, player: String, score: int, table_id: String) -> void:
	var req := HTTPRequest.new()
	req.timeout = 8.0
	host.add_child(req)
	req.request_completed.connect(func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		req.queue_free())
	var body := JSON.stringify({
		"name": player,
		"score": score,
		"table": table_id,
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
	})
	if req.request(URL, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body) != OK:
		req.queue_free()
