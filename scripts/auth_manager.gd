class_name AuthManager
extends RefCounted

## Auth & Account Save Manager for NODEVERSE
## Stores user profiles, credentials, scores, and difficulty in user://nodeverse_accounts.json

const SAVE_PATH: String = "user://nodeverse_accounts.json"

static func _get_store() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"users": {}, "last_user": ""}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {"users": {}, "last_user": ""}
	var txt := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(txt) == OK and json.data is Dictionary:
		var d: Dictionary = json.data
		if not d.has("users"):
			d["users"] = {}
		if not d.has("last_user"):
			d["last_user"] = ""
		return d
	return {"users": {}, "last_user": ""}

static func _save_store(store: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Failed to write to " + SAVE_PATH)
		return false
	var txt := JSON.stringify(store, "  ")
	f.store_string(txt)
	f.close()
	return true

## Register a new account
static func register(username: String, password_text: String) -> Dictionary:
	var uname := username.strip_edges()
	var p := password_text.strip_edges()
	if uname.length() < 2:
		return {"success": false, "message": "아이디는 2글자 이상 입력해주세요."}
	if p.length() < 3:
		return {"success": false, "message": "비밀번호는 3글자 이상 입력해주세요."}

	var store := _get_store()
	var users: Dictionary = store.get("users", {})
	if users.has(uname):
		return {"success": false, "message": "이미 사용 중인 아이디입니다."}

	users[uname] = {
		"password": p,
		"created_at": Time.get_datetime_string_from_system(),
		"last_login": Time.get_datetime_string_from_system(),
		"save_data": {
			"difficulty": "NOVICE",
			"score": 0,
			"cleared_quizzes": [],
			"player_pos": [0.0, 0.55, 1.6],
			"zone": "MAIN",
			"has_saved_game": false
		}
	}
	store["users"] = users
	store["last_user"] = uname
	_save_store(store)
	return {"success": true, "message": "회원가입이 완료되었습니다! 로그인해주세요."}

## Login with username and password
static func login(username: String, password_text: String) -> Dictionary:
	var uname := username.strip_edges()
	var p := password_text.strip_edges()
	if uname.is_empty() or p.is_empty():
		return {"success": false, "message": "아이디와 비밀번호를 모두 입력해주세요."}

	var store := _get_store()
	var users: Dictionary = store.get("users", {})
	if not users.has(uname):
		return {"success": false, "message": "존재하지 않는 아이디입니다."}

	var user_rec: Dictionary = users[uname]
	if str(user_rec.get("password", "")) != p:
		return {"success": false, "message": "비밀번호가 일치하지 않습니다."}

	user_rec["last_login"] = Time.get_datetime_string_from_system()
	store["last_user"] = uname
	_save_store(store)

	var save_data: Dictionary = user_rec.get("save_data", {})
	return {
		"success": true,
		"message": "로그인 성공! 환영합니다.",
		"username": uname,
		"save_data": save_data
	}

## Guest login (instantly creates/loads a guest profile)
static func guest_login() -> Dictionary:
	var guest_name := "Guest"
	var store := _get_store()
	var users: Dictionary = store.get("users", {})
	if not users.has(guest_name):
		users[guest_name] = {
			"password": "guest",
			"created_at": Time.get_datetime_string_from_system(),
			"last_login": Time.get_datetime_string_from_system(),
			"save_data": {
				"difficulty": "NOVICE",
				"score": 0,
				"cleared_quizzes": [],
				"player_pos": [0.0, 0.55, 1.6],
				"zone": "MAIN",
				"has_saved_game": false
			}
		}
		store["users"] = users
	store["last_user"] = guest_name
	_save_store(store)
	return {
		"success": true,
		"message": "게스트로 로그인되었습니다.",
		"username": guest_name,
		"save_data": users[guest_name].get("save_data", {})
	}

## Save user progress (difficulty, score, position, etc.)
static func save_user_progress(username: String, save_data: Dictionary) -> bool:
	var uname := username.strip_edges()
	if uname.is_empty():
		return false
	var store := _get_store()
	var users: Dictionary = store.get("users", {})
	if not users.has(uname):
		return false
	save_data["has_saved_game"] = true
	save_data["last_saved"] = Time.get_datetime_string_from_system()
	users[uname]["save_data"] = save_data
	return _save_store(store)

## Get user save data
static func get_user_progress(username: String) -> Dictionary:
	var uname := username.strip_edges()
	var store := _get_store()
	var users: Dictionary = store.get("users", {})
	if users.has(uname):
		return users[uname].get("save_data", {})
	return {}

## Get last logged in user
static func get_last_user() -> String:
	var store := _get_store()
	return store.get("last_user", "")
