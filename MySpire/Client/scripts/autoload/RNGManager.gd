## RNGManager.gd (Autoload)
## 种子化确定性随机（ADR-003）：所有随机走受管 RNG 通道，
## 同一 run seed + 同一通道 => 可复现序列，供存档恢复与服务端重放验证。
## 生命周期：整个应用存活期。每次新 run 重置。
extends Node

var master_seed: int = 0

var _channels: Dictionary = {}


func _ready() -> void:
	new_run_seed()


func new_run_seed() -> void:
	# 引导种子取自系统时间；进入 run 后所有内容随机均来自派生通道。
	master_seed = hash(Time.get_unix_time_from_system() + Time.get_ticks_msec())
	_channels.clear()


## 从存档恢复种子（地图等结构由它确定性重建）。
func restore_seed(seed_value: int) -> void:
	master_seed = seed_value
	_channels.clear()


## 获取（并缓存）某通道的 RNG。同通道连续调用返回同一实例，
## 保证序列推进 —— 这正是重放验证需要的语义。
func get_rng(channel: String) -> RandomNumberGenerator:
	if _channels.has(channel):
		return _channels[channel]
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = hash([master_seed, channel])
	_channels[channel] = r
	return r
