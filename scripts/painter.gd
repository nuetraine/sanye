extends Node2D
## 一个“画布”节点：把绘制交给 fn 回调（游戏逻辑集中在 game.gd 里）

var fn: Callable

func _draw() -> void:
	if fn.is_valid():
		fn.call(self)
