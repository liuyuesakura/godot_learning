## SaveManager.gd (Autoload)
## 本地存档管理。两部分独立文件：
##   1. Run 存档（myspire_run.json）—— 地图不落盘，由种子确定性重建（ADR-003）。
##   2. IAP 存档（myspire_iap.json）—— 非消耗品购买记录 + 消耗品库存，跨 run 持久。
## 生命周期：整个应用存活期。
extends Node

const SAVE_PATH: String = "user://myspire_run.json"
const IAP_PATH: String = "user://myspire_iap.json"
const AUTH_PATH: String = "user://myspire_auth.json"

## IAP 内存缓存：{"non_consumables": {sku -> purchase_dict}, "consumable_inventory": {sku -> int}}
var _iap_data: Dictionary = {}
## 登录会话缓存：AuthManager.current_user 的快照（跨启动恢复）。
var _auth_data: Dictionary = {}


func _ready() -> void:
	_load_iap()
	_load_auth()


# ─── Run 存档 ───────────────────────────────────────────────────


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_run(run: RunState) -> void:
	if run == null:
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write save (err %d)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(run.to_dict()))


func load_run() -> RunState:
	if not has_save():
		return null
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return RunState.from_dict(parsed as Dictionary)
	push_error("SaveManager: save file corrupted.")
	return null


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ─── IAP 存档（跨 run 持久） ──────────────────────────────────────


func _load_iap() -> void:
	if not FileAccess.file_exists(IAP_PATH):
		_iap_data = {"non_consumables": {}, "consumable_inventory": {}}
		return
	var f: FileAccess = FileAccess.open(IAP_PATH, FileAccess.READ)
	if f == null:
		_iap_data = {"non_consumables": {}, "consumable_inventory": {}}
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_iap_data = parsed
	if not _iap_data.has("non_consumables"):
		_iap_data["non_consumables"] = {}
	if not _iap_data.has("consumable_inventory"):
		_iap_data["consumable_inventory"] = {}


func _save_iap_to_disk() -> void:
	var f: FileAccess = FileAccess.open(IAP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write IAP save (err %d)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(_iap_data))


## 非消耗品：记录购买。
func save_iap(sku: String, purchase: Dictionary) -> void:
	(_iap_data["non_consumables"] as Dictionary)[sku] = purchase
	_save_iap_to_disk()


## 非消耗品：是否已拥有。
func has_iap(sku: String) -> bool:
	return (_iap_data["non_consumables"] as Dictionary).has(sku)


## 非消耗品：获取购买记录。
func get_iap(sku: String) -> Dictionary:
	return (_iap_data["non_consumables"] as Dictionary).get(sku, {})


## 非消耗品：获取所有已拥有商品。
func get_all_iaps() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sku: String in (_iap_data["non_consumables"] as Dictionary).keys():
		var entry: Dictionary = (_iap_data["non_consumables"] as Dictionary)[sku]
		var merged: Dictionary = entry.duplicate()
		merged["sku"] = sku
		result.append(merged)
	return result


## 非消耗品：退款时移除。
func remove_iap(sku: String) -> void:
	(_iap_data["non_consumables"] as Dictionary).erase(sku)
	_save_iap_to_disk()


## 消耗品：增加库存。
func add_consumable(sku: String, count: int = 1) -> void:
	var inv: Dictionary = _iap_data["consumable_inventory"] as Dictionary
	inv[sku] = int(inv.get(sku, 0)) + count
	_save_iap_to_disk()


## 消耗品：使用一个（库存 -1）。返回是否使用成功。
func use_consumable(sku: String) -> bool:
	var inv: Dictionary = _iap_data["consumable_inventory"] as Dictionary
	var current: int = int(inv.get(sku, 0))
	if current <= 0:
		return false
	inv[sku] = current - 1
	_save_iap_to_disk()
	return true


## 消耗品：查询库存。
func get_consumable_count(sku: String) -> int:
	return int((_iap_data["consumable_inventory"] as Dictionary).get(sku, 0))


## 清空所有 IAP 数据（调试用）。
func clear_iaps() -> void:
	_iap_data = {"non_consumables": {}, "consumable_inventory": {}}
	_save_iap_to_disk()


# ─── 登录会话存档（跨启动恢复） ──────────────────────────────────


func _load_auth() -> void:
	if not FileAccess.file_exists(AUTH_PATH):
		_auth_data = {}
		return
	var f: FileAccess = FileAccess.open(AUTH_PATH, FileAccess.READ)
	if f == null:
		_auth_data = {}
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_auth_data = parsed
	else:
		_auth_data = {}


func _save_auth_to_disk() -> void:
	var f: FileAccess = FileAccess.open(AUTH_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write auth save (err %d)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(_auth_data))


## 保存登录会话（AuthManager 登录成功后调用）。
func save_auth_session(user: Dictionary) -> void:
	_auth_data = user
	_save_auth_to_disk()


## 加载登录会话。返回空 Dictionary 表示无会话。
func load_auth_session() -> Dictionary:
	return _auth_data.duplicate()


## 清除登录会话（登出）。
func clear_auth_session() -> void:
	_auth_data = {}
	_save_auth_to_disk()
