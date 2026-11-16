extends "res://scripts/game.gd"
## 暗潮试炼：《散页》的“幸存者”玩法（独立模式，不碰主线存档）。
##
## 一张地图、一局十五分钟左右，分八个阶段：每个阶段换一批生物（对应主线的一章），
## 阶段末尾来一个首领，八个首领一路打到「静默」。笔自动出手；打散生物掉页尘，
## 攒够就升级，从三张卡里挑：新笔 / 笔升级 / 字（被动）/ 技（自动放的技能）。
## 联动有三层：笔 + 字 = 成词进化（每支笔两种）；字 + 字 = 成词；技 + 字 = 加成。
##
## 只借用主线的画面（贴图、色板、陶灵、生物的样子）和音效，逻辑全部在这个文件里。

class SV extends Creature:
	var mhp := 1.0
	var xp := 1
	var spd := 30.0
	var dmg := 1
	var elite := false
	var boss := false
	var ai := "chase"
	var kx := 0.0          # 击退速度
	var ky := 0.0
	var blade_cd := 0.0    # 被绕身刻刀砍过后的冷却
	var fire_cd := 0.0     # 被火地烧过后的冷却
	var burn_dps := 0.0
	var gone_t := 0.0      # 跑出屏幕外多久了
	var tr_t := 0.0
	var frz := 0.0         # 被冻住 / 震晕还剩多久
	var t2 := 0.0          # 备用计时
	var n2 := 0            # 备用计数

class SB extends EBullet:
	var split_t := -1.0    # 棱镜虫的光弹：飞一会儿散成三发
	var slow := 0.0        # 打中不掉血，只是变慢（蛛网、墨团）

## 每种生物在试炼里的数值。hp 会再乘上随时间涨的系数
const MT := {
	# 第一章 · 星海散页
	"moth": {"hp": 4.0, "sp": 46.0, "xp": 1, "dmg": 1, "r": 3.0, "ai": "chase"},
	"hush": {"hp": 14.0, "sp": 24.0, "xp": 2, "dmg": 1, "r": 6.0, "ai": "chase"},
	"folio": {"hp": 9.0, "sp": 60.0, "xp": 2, "dmg": 1, "r": 6.0, "ai": "folio"},
	"leech": {"hp": 16.0, "sp": 36.0, "xp": 3, "dmg": 1, "r": 4.0, "ai": "lunge"},
	"mite": {"hp": 40.0, "sp": 27.0, "xp": 5, "dmg": 1, "r": 5.0, "ai": "mite"},
	"snail": {"hp": 55.0, "sp": 19.0, "xp": 6, "dmg": 2, "r": 5.0, "ai": "snail"},
	"borer": {"hp": 26.0, "sp": 62.0, "xp": 4, "dmg": 1, "r": 4.0, "ai": "worm"},
	"comet": {"hp": 60.0, "sp": 85.0, "xp": 0, "dmg": 0, "r": 4.0, "ai": "comet"},
	"clam": {"hp": 20.0, "sp": 0.0, "xp": 2, "dmg": 0, "r": 5.0, "ai": "still"},
	"grav": {"hp": 550.0, "sp": 20.0, "xp": 40, "dmg": 2, "r": 6.0, "ai": "chase"},
	# 暗潮
	"chill": {"hp": 22.0, "sp": 30.0, "xp": 3, "dmg": 1, "r": 5.0, "ai": "chase"},
	"icicle": {"hp": 12.0, "sp": 34.0, "xp": 3, "dmg": 1, "r": 4.0, "ai": "aimdash"},
	"mothq": {"hp": 380.0, "sp": 30.0, "xp": 30, "dmg": 2, "r": 8.0, "ai": "mothq"},
	# 第二章 · 阅览室残骸
	"comma": {"hp": 12.0, "sp": 40.0, "xp": 3, "dmg": 1, "r": 4.0, "ai": "shoot"},
	"blot": {"hp": 24.0, "sp": 36.0, "xp": 3, "dmg": 1, "r": 7.0, "ai": "hop"},
	"blotlet": {"hp": 7.0, "sp": 50.0, "xp": 1, "dmg": 1, "r": 4.0, "ai": "hop"},
	"worm": {"hp": 28.0, "sp": 56.0, "xp": 4, "dmg": 1, "r": 5.0, "ai": "worm"},
	"wisp": {"hp": 20.0, "sp": 32.0, "xp": 4, "dmg": 1, "r": 5.0, "ai": "wisp"},
	# 第三章 · 烛芯钟楼
	"dove": {"hp": 8.0, "sp": 46.0, "xp": 2, "dmg": 1, "r": 4.0, "ai": "lunge"},
	"tick": {"hp": 36.0, "sp": 30.0, "xp": 5, "dmg": 1, "r": 6.0, "ai": "lunge"},
	"cinder": {"hp": 12.0, "sp": 46.0, "xp": 3, "dmg": 0, "r": 4.0, "ai": "boom"},
	"stamp": {"hp": 48.0, "sp": 36.0, "xp": 6, "dmg": 2, "r": 7.0, "ai": "stamp"},
	# 第四章 · 冰封书库
	"spider": {"hp": 20.0, "sp": 34.0, "xp": 4, "dmg": 1, "r": 5.0, "ai": "shoot"},
	"roller": {"hp": 18.0, "sp": 62.0, "xp": 4, "dmg": 1, "r": 4.0, "ai": "roller"},
	"bat": {"hp": 9.0, "sp": 50.0, "xp": 2, "dmg": 1, "r": 4.0, "ai": "lunge"},
	# 第五章 · 镜之回廊
	"mimic": {"hp": 30.0, "sp": 64.0, "xp": 9, "dmg": 1, "r": 5.0, "ai": "mimic"},
	"prismbug": {"hp": 18.0, "sp": 36.0, "xp": 4, "dmg": 1, "r": 5.0, "ai": "shoot"},
	"shard": {"hp": 4.0, "sp": 85.0, "xp": 1, "dmg": 1, "r": 3.0, "ai": "shard"},
	"shade": {"hp": 22.0, "sp": 60.0, "xp": 4, "dmg": 1, "r": 5.0, "ai": "chase"},
	# 第六章 · 残烛之心
	"salamander": {"hp": 26.0, "sp": 52.0, "xp": 4, "dmg": 1, "r": 5.0, "ai": "sala"},
	"ashghost": {"hp": 18.0, "sp": 32.0, "xp": 3, "dmg": 1, "r": 6.0, "ai": "wisp"},
	"drip": {"hp": 34.0, "sp": 0.0, "xp": 5, "dmg": 1, "r": 6.0, "ai": "drip"},
	# 第七章 · 墨渊深井
	"angler": {"hp": 30.0, "sp": 30.0, "xp": 5, "dmg": 2, "r": 6.0, "ai": "lunge"},
	"urchin": {"hp": 24.0, "sp": 22.0, "xp": 4, "dmg": 1, "r": 5.0, "ai": "urchin"},
	"eel": {"hp": 28.0, "sp": 48.0, "xp": 5, "dmg": 1, "r": 5.0, "ai": "aimdash"},
	"squid": {"hp": 20.0, "sp": 40.0, "xp": 4, "dmg": 1, "r": 5.0, "ai": "shoot"},
	# 第八章 · 沉默视界
	"sat": {"hp": 14.0, "sp": 60.0, "xp": 3, "dmg": 1, "r": 4.0, "ai": "sat"},
	"nova": {"hp": 26.0, "sp": 40.0, "xp": 5, "dmg": 0, "r": 5.0, "ai": "boom"},
	"twin": {"hp": 22.0, "sp": 46.0, "xp": 4, "dmg": 1, "r": 4.0, "ai": "twin"},
	# 首领（hp 不随时间涨，按阶段另算）
	"serp": {"hp": 1.0, "sp": 62.0, "xp": 0, "dmg": 1, "r": 8.0, "ai": "boss"},
	"redact": {"hp": 1.0, "sp": 40.0, "xp": 0, "dmg": 2, "r": 11.0, "ai": "boss"},
	"binder": {"hp": 1.0, "sp": 38.0, "xp": 0, "dmg": 2, "r": 11.0, "ai": "boss"},
	"index": {"hp": 1.0, "sp": 26.0, "xp": 0, "dmg": 2, "r": 12.0, "ai": "boss"},
	"mirror": {"hp": 1.0, "sp": 70.0, "xp": 0, "dmg": 2, "r": 7.0, "ai": "boss"},
	"wick": {"hp": 1.0, "sp": 22.0, "xp": 0, "dmg": 2, "r": 13.0, "ai": "boss"},
	"kraken": {"hp": 1.0, "sp": 30.0, "xp": 0, "dmg": 2, "r": 14.0, "ai": "boss"},
	"silence": {"hp": 1.0, "sp": 24.0, "xp": 0, "dmg": 2, "r": 15.0, "ai": "boss"},
}

## 扑过来的那一类：[多近开始, 蓄力多久, 冲多快, 冲多久, 冷却, 蓄力时叫什么, 冲时叫什么, 冲完叫什么, 冲完喘多久]
const LG := {
	"leech": [70.0, 0.5, 190.0, 0.45, 2.5, "wind", "lunge", "", 0.0],
	"dove": [95.0, 0.4, 200.0, 0.55, 2.2, "aim", "dive", "", 0.0],
	"bat": [80.0, 0.35, 215.0, 0.5, 2.0, "wind", "dive", "", 0.0],
	"tick": [85.0, 0.6, 200.0, 0.6, 0.5, "wind", "lunge", "tired", 1.8],
	"angler": [62.0, 0.3, 235.0, 0.4, 1.0, "wind", "lunge", "rest", 1.6],
}
## 远程的那一类：[保持多远, 冷却, 子弹速度]
const SH := {
	"comma": [90.0, 2.4, 72.0],
	"spider": [100.0, 3.2, 58.0],
	"prismbug": [95.0, 2.8, 62.0],
	"squid": [110.0, 3.0, 52.0],
}

## 八个阶段：名字、这一阶段的生物和权重、首领
const STAGES := [
	{"name": "星海散页", "boss": "serp", "pool": [["moth", 6], ["hush", 3], ["folio", 2], ["leech", 2], ["mite", 1], ["snail", 1], ["borer", 1]]},
	{"name": "阅览室残骸", "boss": "redact", "pool": [["moth", 3], ["comma", 3], ["blot", 3], ["worm", 2], ["wisp", 2], ["leech", 1]]},
	{"name": "烛芯钟楼", "boss": "binder", "pool": [["moth", 2], ["dove", 5], ["tick", 2], ["cinder", 3], ["stamp", 1], ["comma", 1]]},
	{"name": "冰封书库", "boss": "index", "pool": [["bat", 4], ["spider", 2], ["roller", 3], ["chill", 3], ["icicle", 2], ["hush", 2]]},
	{"name": "镜之回廊", "boss": "mirror", "pool": [["shard", 6], ["prismbug", 2], ["shade", 3], ["mite", 3], ["mimic", 1], ["tick", 1]]},
	{"name": "残烛之心", "boss": "wick", "pool": [["cinder", 4], ["salamander", 3], ["ashghost", 3], ["drip", 1], ["dove", 2], ["stamp", 1]]},
	{"name": "墨渊深井", "boss": "kraken", "pool": [["blot", 3], ["angler", 2], ["urchin", 2], ["eel", 2], ["squid", 2], ["worm", 2], ["wisp", 1]]},
	{"name": "沉默视界", "boss": "silence", "pool": [["sat", 4], ["nova", 2], ["twin", 2], ["shard", 3], ["shade", 2], ["snail", 1], ["moth", 4]]},
]
const STAGE_LEN := 105.0      # 一个阶段多长
const BOSS_IN := 75.0         # 阶段开始多久后首领出现

## 七支笔：自动出手。lv 1~5；满级后配上搭档字可以成词进化，每支笔有甲、乙两种
const SPENS := [
	{"name": "毛笔", "lv": ["朝最近的敌人射字弹", "多射一发", "伤害 +40%", "多射一发", "出手更快，伤害 +40%"],
		"evo": ["雨", "寻"], "ename": ["暴雨", "寻踪"],
		"edesc": ["字弹连成一阵急雨，每隔两秒再朝四面八方泼一圈", "字弹打中后弹向下一个敌人，能弹三次"]},
	{"name": "排刷", "lv": ["朝敌人刷出一片短程字弹", "多刷两发", "伤害 +40%", "射程更远，多刷两发", "出手更快，伤害 +40%"],
		"evo": ["火", "霜"], "ename": ["燎原", "霜降"],
		"edesc": ["刷出去的字弹落地成火，烧出一整片", "刷到的敌人会被冻住一秒半"]},
	{"name": "刻刀", "lv": ["朝身前挥一刀，刀长伤害高", "刀更长", "前后各挥一刀", "伤害 +40%", "出手更快，刀更长"],
		"evo": ["环", "暴"], "ename": ["回环", "斩首"],
		"edesc": ["三把刻刀一直绕着你转，砍到什么都不停", "血不到三成的小怪一刀斩掉；砍满血的必定暴击"]},
	{"name": "砚雷", "lv": ["往敌人堆里扔一团墨，炸开一片", "多扔一团", "炸得更大", "多扔一团", "伤害 +50%"],
		"evo": ["裂", "重"], "ename": ["裂石", "墨涡"],
		"edesc": ["每团墨炸开后，再裂成四团小墨接着炸", "炸点留下一摊墨涡，把周围的敌人吸进来绞"]},
	{"name": "墨线", "lv": ["射出一道穿透一切的墨线", "更粗，伤害 +30%", "前后各射一道", "出手更快", "伤害 +50%"],
		"evo": ["穿", "连"], "ename": ["穿针", "惊雷"],
		"edesc": ["墨线变成十字，绕着你扫一整圈", "墨线扫到的每个敌人都劈出闪电，跳到旁边"]},
	{"name": "印章", "lv": ["往敌人堆里盖一个章，震晕一片", "章更大", "多盖一个", "伤害 +40%", "出手更快，多盖一个"],
		"evo": ["石", "火"], "ename": ["千钧", "朱砂"],
		"edesc": ["盖下去再震出一圈波，把敌人掀开", "印子留在地上烧四秒"]},
	{"name": "烛台", "lv": ["身边一圈烛光，持续灼伤靠近的敌人", "光圈更大", "伤害 +50%", "光圈更大", "伤害 +50%"],
		"evo": ["炉", "霜"], "ename": ["长明", "冷焰"],
		"edesc": ["光圈大一圈，每 30 秒回一颗心", "圈里的敌人慢六成，受到的烛光伤害翻倍"]},
]

## 字：升级时拿的被动。kind 沿用主线的形 / 动 / 性，另加三个“身”字
const SW := {
	"针": {"max": 5, "kind": "形", "d": "字弹更快、飞得更远（+15%）"},
	"雨": {"max": 3, "kind": "形", "d": "毛笔、排刷、砚雷、印章每次多出手一发"},
	"石": {"max": 5, "kind": "形", "d": "所有伤害 +15%"},
	"环": {"max": 5, "kind": "形", "d": "范围 +15%：刀更长、墨团更大、墨线更粗"},
	"穿": {"max": 3, "kind": "动", "d": "字弹多穿过 1 个敌人"},
	"寻": {"max": 3, "kind": "动", "d": "字弹会拐向附近的敌人"},
	"裂": {"max": 3, "kind": "动", "d": "字弹命中时，有机会裂出两枚小字弹"},
	"连": {"max": 3, "kind": "动", "d": "命中有机会电到旁边两个敌人"},
	"火": {"max": 3, "kind": "性", "d": "命中点燃敌人，每秒烧掉一截血"},
	"霜": {"max": 3, "kind": "性", "d": "命中让敌人变慢"},
	"暴": {"max": 3, "kind": "性", "d": "一成机会打出 2.5 倍伤害"},
	"重": {"max": 3, "kind": "性", "d": "吸页尘的范围 +50%"},
	"疾": {"max": 3, "kind": "身", "d": "跑得更快（+10%）"},
	"炉": {"max": 5, "kind": "身", "d": "所有笔和技的间隔 -8%"},
	"心": {"max": 3, "kind": "身", "d": "多两颗心，并且回满"},
}

## 字 + 字 = 成词：两个字都在手上就自动生效
const WCOMBO := [
	{"a": "火", "b": "石", "name": "火石", "d": "着火的敌人死掉时炸开"},
	{"a": "连", "b": "环", "name": "连环", "d": "闪电多跳三个敌人"},
	{"a": "霜", "b": "裂", "name": "冰裂", "d": "变慢的敌人死掉时迸出一圈冰棱"},
	{"a": "暴", "b": "针", "name": "锋芒", "d": "暴击伤害从 2.5 倍涨到 4 倍"},
	{"a": "重", "b": "心", "name": "厚土", "d": "每 25 秒自己回一颗心"},
	{"a": "寻", "b": "穿", "name": "追魂", "d": "字弹穿过敌人后，转头去找下一个"},
	{"a": "炉", "b": "疾", "name": "风火", "d": "跑动时身后留下一串火"},
]

## 技：自动放的技能，最多带两个，各 3 级。syn = 哪个字能加成它
const SK := {
	"shield": {"name": "墨盾", "cd": 18.0, "d": "每隔一阵子套上一层墨盾，替你挡一下，碎的时候把周围震开", "syn": "环", "sd": "盾碎时炸得更大，还会伤到敌人"},
	"nova": {"name": "炉息", "cd": 9.0, "d": "每隔一阵子喷出一圈炉火，烧伤周围的敌人", "syn": "火", "sd": "炉火落地，留下一圈火"},
	"freeze": {"name": "定格", "cd": 22.0, "d": "每隔一阵子让屏幕上的敌人和子弹全都停住", "syn": "霜", "sd": "被定住的敌人多受六成伤害"},
	"storm": {"name": "万页", "cd": 12.0, "d": "每隔一阵子召出一群书页，自己去找敌人", "syn": "雨", "sd": "书页多一半"},
}

## 四只陶灵：开局的笔和特点不一样
const SCH := [
	{"pen": 0, "hp": 0, "sp": 1.0, "dash": 1.0, "tag": "毛笔开局 · 均衡", "d": "各项均衡，没有短处。"},
	{"pen": 2, "hp": -2, "sp": 1.2, "dash": 0.6, "tag": "刻刀开局 · 轻快", "d": "跑得快冲得勤，少两颗心。"},
	{"pen": 5, "hp": 2, "sp": 0.92, "dash": 1.0, "tag": "印章开局 · 结实", "d": "多两颗心但跑得慢，冲刺能撞伤敌人。"},
	{"pen": 3, "hp": -1, "sp": 1.0, "dash": 1.0, "tag": "砚雷开局 · 多一个字", "d": "多带一个字，少一颗心。"},
]

## 局外的永久升级：用每局攒下的「书页」买
const META := [
	{"id": "shell", "name": "陶壳", "d": "开局多一颗心", "max": 3, "cost": [15, 40, 90]},
	{"id": "edge", "name": "笔锋", "d": "所有伤害 +6%", "max": 5, "cost": [10, 25, 50, 90, 150]},
	{"id": "wit", "name": "悟性", "d": "页尘经验 +8%", "max": 5, "cost": [10, 25, 50, 90, 150]},
	{"id": "pull", "name": "磁石", "d": "吸页尘的范围 +20%", "max": 3, "cost": [10, 30, 70]},
	{"id": "roll", "name": "重掷", "d": "升级时可以换一批卡，每局多一次", "max": 3, "cost": [20, 50, 100]},
	{"id": "kiln", "name": "余火", "d": "每局能原地复活一次", "max": 1, "cost": [120]},
]

## 藏品：每打倒一个首领，炉灯工坊开一次门，用路上攒的墨滴买。很多是有得有失的。
const RL := {
	"weight": {"n": "镇纸", "d": "伤害 +12%，跑得慢 5%", "c": 30, "max": 5},
	"quill": {"n": "羽毛笔", "d": "出手快 10%，伤害 -4%", "c": 30, "max": 5},
	"lens": {"n": "放大镜", "d": "范围 +15%", "c": 35, "max": 4},
	"feather": {"n": "轻羽", "d": "跑得快 10%", "c": 25, "max": 4},
	"shard": {"n": "陶片", "d": "多一颗心", "c": 40, "max": 5},
	"tea": {"n": "茶盏", "d": "每 40 秒回一颗心", "c": 45, "max": 3},
	"blotter": {"n": "吸墨纸", "d": "吸页尘的范围 +30%", "c": 20, "max": 3},
	"mark": {"n": "书签", "d": "页尘经验 +10%", "c": 30, "max": 4},
	"redpen": {"n": "朱批", "d": "暴击率 +6%", "c": 35, "max": 5},
	"jacket": {"n": "护封", "d": "挨打时有 15% 机会不掉心", "c": 45, "max": 3},
	"jar": {"n": "存钱罐", "d": "离开工坊时，剩下的墨滴生两成利息（最多 40）", "c": 30, "max": 2},
	"sand": {"n": "砂纸", "d": "精英和首领多受 20% 伤害", "c": 40, "max": 4},
	"clip": {"n": "回形针", "d": "字弹多穿一个敌人", "c": 55, "max": 2},
	"tape": {"n": "双面胶", "d": "立刻多两次重掷", "c": 20, "max": 9},
	"wax": {"n": "火漆", "d": "敌人掉余烬的机会翻倍", "c": 35, "max": 2},
	"glass": {"n": "沙漏", "d": "技能冷却快 18%", "c": 35, "max": 3},
	"lead": {"n": "铅坠", "d": "伤害 +25%，出手慢 10%", "c": 45, "max": 3},
	"tissue": {"n": "薄纸", "d": "出手快 20%，少一颗心", "c": 40, "max": 2},
	"gpen": {"n": "玻璃笔", "d": "伤害 +35%，每次挨打多掉一颗心", "c": 50, "max": 1},
	"thorn": {"n": "荆棘封皮", "d": "挨打时把周围的敌人炸一圈", "c": 35, "max": 3},
	"core": {"n": "备用墨芯", "d": "多一次原地复活", "c": 110, "max": 1},
	"clover": {"n": "三叶书签", "d": "升级时多一张卡可选", "c": 80, "max": 1},
	"sac": {"n": "墨囊", "d": "墨滴收入 +25%", "c": 30, "max": 3},
	"leaf": {"n": "残页", "d": "立刻升两级", "c": 60, "max": 99, "once": true},
	"candy": {"n": "余烬糖", "d": "把心回满", "c": 15, "max": 99, "once": true},
}

## 满级后的强化：笔、字、技都练满以后，升级时从这里补足三选一，全都能一直叠
const BOON := {
	"quick": {"n": "快手", "d": "所有笔出手快 4%（可以一直拿）", "m": 8},
	"wide": {"n": "扩印", "d": "所有范围 +5%（可以一直拿）", "m": 2},
	"swift": {"n": "健步", "d": "跑得快 4%（最多 5 次）", "m": 12, "max": 5},
	"thick": {"n": "厚胎", "d": "多一颗心并回一颗（最多 4 次）", "m": 4, "max": 4},
	"purse": {"n": "聚墨", "d": "立刻得到 30 墨滴，下一间工坊用", "m": 2},
}

## 誓约：开局三选一（也可以不立），一条规矩管一整局，有得有失
const PACT := {
	"solo": {"n": "独笔", "d": "伤害 +50%", "x": "最多只能带两支笔", "m": 4},
	"glass": {"n": "薄胎", "d": "伤害 +40%", "x": "陶心上限减半", "m": 10},
	"swarm": {"n": "群潮", "d": "页尘经验 +35%", "x": "怪多四成", "m": 11},
	"greed": {"n": "贪墨", "d": "墨滴收入翻倍", "x": "怪的血多两成", "m": 13},
	"scholar": {"n": "博学", "d": "多带两个字", "x": "少带一支笔", "m": 2},
	"rush": {"n": "疾书", "d": "所有笔出手快 25%", "x": "范围 -20%", "m": 8},
	"slow": {"n": "慢热", "d": "每打倒一个首领，伤害 +12%", "x": "开局伤害 -25%", "m": 3},
	"dealer": {"n": "藏家", "d": "工坊打八折，每次进门送 30 墨滴", "x": "升级时少一张卡", "m": 12},
}
## 地图上的事件点：走进圈里站一会儿才生效，去不去自己定
const POIK := {
	"trial": {"n": "试炼圈", "d": "守住 7 秒，得一张散页", "r": 30.0, "need": 7.0, "m": 13},
	"curse": {"n": "诅咒碑", "d": "招来 30 秒怪潮，换一次淬火和 30 墨滴", "r": 16.0, "need": 1.5, "m": 11},
	"spring": {"n": "暖泉", "d": "站进去慢慢回心", "r": 22.0, "need": 1.2, "m": 3},
	"stele": {"n": "字碑", "d": "读 2.5 秒，白拿一次升级", "r": 18.0, "need": 2.5, "m": 12},
}
const MAX_PENS := 4
const MAX_WORDS := 6
const MAX_SK := 2
var CAP := 480                # 同屏生物上限（网页版也要跑得动；机器吃力时会自动调低）
var qual := 0                 # 自动画质档：0 全开，1 少一些粒子和怪，2 再少一些
var _q_ms := 0
var _q_fr := 0
var _q_low := 0
const GCELL := 16.0

var E: Array[SV] = []
var G := {}                   # 空间网格：格子编号 → Array[SV]
var GCN := {}                 # 格子里的生物个数和重心 Vector3(sx, sy, n)
var gt2 := 0.0                # 这一局过了多久
var stage := 0
var pens := {}                # 笔序号 → 等级
var evo := {}                 # "笔序号_0/1" → true
var words := {}               # 字 → 等级
var sk := {}                  # 技 id → 等级
var sk_cd := {}
var combos := {}              # 已经成的词
var pen_cd := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var lv := 1
var xp := 0
var lv_q := 0                 # 还没选的升级次数
var opts: Array = []
var opt_sel := 0
var rerolls := 0
var boon := {}                # 满级强化 id -> 次数
var pact := ""                # 这一局立的誓约
var pact_opts: Array = []
var pact_sel := 0
var POI: Array = []           # 地图事件点 {k, x, y, p, life, left, on}
var curse_t := 0.0            # 诅咒碑招来的怪潮还剩多久
var banish := 0               # 还能封存几张卡
var BAN := {}                 # 这一局封存掉的卡
var ban_mode := false
var DS := {}                  # 伤害来源 -> 总伤害（结算时看）
var dsrc := "其他"
var temper := 0               # 「淬火」拿了几次
var revives := 0
var kills2 := 0
var boss_kills := 0
var spawn_acc := 0.0
var ev_done := {}
var bosses: Array[SV] = []
var SL: Array = []            # 刀光 {x, y, a, arc, r, t}
var BEAMS: Array = []         # 墨线
var BOOMS: Array = []         # 爆炸圈 {x, y, r, t, T, m}
var INKB: Array = []          # 飞行中的墨团
var FIRE: Array = []          # 我方地上的火 {x, y, r, t}
var VORT2: Array = []         # 墨涡 {x, y, r, t, tick}
var SEALS: Array = []         # 印章印子 {x, y, r, t, wave}
var ZAPS: Array = []          # 电弧
var NUMS: Array = []          # 伤害数字
var EA: Array = []            # 敌方：预告圈 {x, y, r, t, T, fire}
var EF: Array = []            # 敌方：地上的火 / 墨 {x, y, r, t, ink}
var EL: Array = []            # 敌方：预告线 {x, y, a, len, w, t, T}
var ER: Array = []            # 敌方：扩散的圈 {x, y, r, v, max}
var blade_a := 0.0
var sweep_t := 0.0
var rain_t := 0.0
var aura_t := 0.0
var heal_t2 := 0.0
var lamp_heal := 0.0
var trail_t := 0.0
var shield_on := false
var frz_all := 0.0            # 「定格」还剩多久
var hurt_t := 0.0
var banner := ""
var banner_t := 0.0
var banner_c := Color.WHITE
var snd_t := {}
var over_t := 0.0
var won := false
var earned := 0
var ink := 0                  # 墨滴：捡页尘时顺带攒下的钱，只在工坊里花
var ink_frac := 0.0
var rel := {}                 # 藏品 id -> 件数
var shop: Array = []          # 这次工坊摆出来的东西
var shop_n := 0               # 第几间工坊
var shop_rr := 0              # 这间工坊重掷了几次
var shop_t := -1.0            # 首领倒下后，过一小会儿再开门
var tea_t := 0.0
var new_danger := false
var danger := 0               # 暗潮等级：通关后解锁的更高难度
var meta := {"pages": 0, "up": {}, "best": {}, "ch": 0}
var hub_sel := 0
var slowmo := 0.0
var _fast := 1
var _dr_us := {}
var _shot_at := {}
var _perf_n := 0
var _perf_us := 0
var _perf_max := 0
var _fps_t := 0.0

# ======================================================================
# 启动
# ======================================================================
func _ready() -> void:
	super._ready()
	rock_layer.visible = false
	cr.clear()
	PK.clear()
	PB.clear()
	EB.clear()
	BEA.clear()
	LAMPS.clear()
	INK.clear()
	_load_meta()
	_fx_setup()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--fast="):
			_fast = maxi(1, int(a.substr(7)))
		if a.begins_with("--char="):
			meta.ch = clampi(int(a.substr(7)), 0, 3)
	S = "hub"
	P = PlayerState.new()
	if _autoplay and not OS.get_cmdline_user_args().has("--hub"):
		start_run()

## 试炼不需要主线的世界（省掉一秒多的生成时间）
func new_world() -> void:
	pass

func bn(id: String) -> int:
	return int(boon.get(id, 0))

func rl(id: String) -> int:
	return int(rel.get(id, 0))

func mu(id: String) -> int:
	return int((meta.up as Dictionary).get(id, 0))

func start_run() -> void:
	E.clear()
	PK.clear()
	PB.clear()
	EB.clear()
	PT.clear()
	for a in [SL, BEAMS, BOOMS, INKB, FIRE, VORT2, SEALS, ZAPS, NUMS, EA, EF, EL, ER]:
		a.clear()
	bosses.clear()
	toasts.clear()
	P = PlayerState.new()
	P.x = 0
	P.y = 0
	P.ch = int(meta.ch)
	var c: Dictionary = SCH[P.ch]
	P.maxhp = 8 + int(c.hp) + mu("shell")
	P.hp = P.maxhp
	cam_pos = Vector2.ZERO
	gt2 = 0.0
	stage = 0
	pens = {int(c.pen): 1}
	evo = {}
	words = {}
	sk = {}
	sk_cd = {}
	combos = {}
	pen_cd = [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3]
	lv = 1
	xp = 0
	lv_q = 0
	rerolls = mu("roll")
	ink = 0
	ink_frac = 0.0
	rel = {}
	shop = []
	shop_n = 0
	shop_t = -1.0
	tea_t = 0.0
	danger = clampi(int(meta.get("dl", 0)), 0, int(meta.get("dmax", 0)))
	revives = mu("kiln")
	temper = 0
	boon = {}
	pact = ""
	POI = []
	curse_t = 0.0
	banish = 2
	BAN = {}
	ban_mode = false
	DS = {}
	dsrc = "其他"
	kills2 = 0
	boss_kills = 0
	earned = 0
	spawn_acc = 0.0
	ev_done = {}
	won = false
	over_t = 0.0
	slowmo = 0.0
	shield_on = false
	frz_all = 0.0
	TIDE = 0.0
	var ids := PACT.keys()
	ids.shuffle()
	pact_opts = ids.slice(0, 3)
	pact_sel = 0
	S = "pact"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pact="):
			take_pact(a.substr(7))

func take_pact(id: String) -> void:
	pact = id if PACT.has(id) else ""
	if pact == "glass":
		P.maxhp = maxi(3, P.maxhp / 2)
		P.hp = P.maxhp
	S = "sv"
	Sfx.play("page" if pact != "" else "ping")
	if pact != "":
		set_banner("誓约「%s」" % PACT[pact].n, "%s；%s" % [PACT[pact].d, PACT[pact].x], C_GOLD)
	else:
		set_banner("暗潮试炼", "八个阶段、八个首领，撑到最后打倒「静默」", C_GOLD)
	if touch_mode:
		toast("拖动屏幕移动 · 笔会自动出手", C_DIM, 6)
	else:
		toast("WASD 或按住鼠标移动 · 空格冲刺 · 笔会自动出手 · Esc 暂停", C_DIM, 6)

func _load_meta() -> void:
	if FileAccess.file_exists("user://sanye-surv.json"):
		var f := FileAccess.open("user://sanye-surv.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in ["pages", "up", "best", "ch", "dl", "dmax", "pw"]:
				if d.has(k):
					meta[k] = d[k]
			if not (meta.up is Dictionary):
				meta.up = {}
			if not (meta.best is Dictionary):
				meta.best = {}
			meta.ch = clampi(int(meta.ch), 0, 3)
			meta.pages = int(meta.pages)

func _save_meta() -> void:
	if _autoplay:
		return
	var f := FileAccess.open("user://sanye-surv.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))

func set_banner(s: String, sub: String, c: Color) -> void:
	banner = s
	banner_c = c
	banner_t = 3.2
	if sub != "":
		toast(sub, c, 4)

func snd(n: String, pitch := 1.0, gap := 0.05) -> void:
	var t0: float = snd_t.get(n, -9.0)
	if T - t0 < gap:
		return
	snd_t[n] = T
	Sfx.play(n, pitch)

func w(c: String) -> int:
	return int(words.get(c, 0))

func plv(i: int) -> int:
	return int(pens.get(i, 0))

func ev(i: int, k: int) -> bool:
	return evo.has("%d_%d" % [i, k])

func skl(id: String) -> int:
	return int(sk.get(id, 0))

func cmb(n: String) -> bool:
	return combos.has(n)

func dmg_k() -> float:
	return (1.0 + 0.15 * w("石")) * (1.0 + 0.06 * mu("edge")) * (1.0 + 0.05 * temper) * maxf(0.3, 1.0 + 0.12 * rl("weight") + 0.25 * rl("lead") + 0.35 * rl("gpen") - 0.04 * rl("quill")) * pact_dmg()

func pact_dmg() -> float:
	match pact:
		"solo": return 1.5
		"glass": return 1.4
		"slow": return 0.75 + 0.12 * boss_kills
	return 1.0

func max_pens() -> int:
	return 2 if pact == "solo" else (MAX_PENS - 1 if pact == "scholar" else MAX_PENS)

func area_k() -> float:
	return (1.0 + 0.15 * w("环")) * (1.0 + 0.15 * rl("lens")) * (1.0 + 0.05 * bn("wide")) * (0.8 if pact == "rush" else 1.0)

func cd_k() -> float:
	return pow(0.92, w("炉")) * pow(0.96, bn("quick")) * pow(0.9, rl("quill")) * pow(0.8, rl("tissue")) * pow(1.1, rl("lead")) * (0.75 if pact == "rush" else 1.0)

func xp_need() -> int:
	# 12 级以后明显变慢：整套笔、字、技大约在第 11~12 分钟才练满，后半局每次升级还有分量
	return int(4 + lv * 3.5 + pow(maxf(0.0, lv - 8.0), 1.9) * 1.7 + pow(maxf(0.0, lv - 12.0), 2.1) * 2.2)

func max_words() -> int:
	return MAX_WORDS + (1 if P.ch == 3 else 0) + (2 if pact == "scholar" else 0)

func stage_t() -> float:
	return gt2 - stage * STAGE_LEN

func far_r() -> float:
	return Vector2(W, H).length() * 0.5 + 70

## 检查有没有新成的词（字 + 字）
func check_combos() -> void:
	for c in WCOMBO:
		if w(c.a) > 0 and w(c.b) > 0 and not combos.has(c.name):
			combos[c.name] = true
			Sfx.play("page")
			set_banner("成词「%s」" % c.name, "「%s」+「%s」：%s" % [c.a, c.b, c.d], C_GOLD)

# ======================================================================
# 输入：触屏整块屏幕都是摇杆；键盘鼠标交给主线的处理
# ======================================================================
func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		touch_mode = true
		var pos: Vector2 = e.position / U
		if e.pressed:
			click_q = true
			tap_pos = pos
			touches[e.index] = {"kind": "move", "start": pos, "pos": pos}
		else:
			touches.erase(e.index)
		_touch_sync()
	elif e is InputEventScreenDrag:
		if touches.has(e.index):
			var t: Dictionary = touches[e.index]
			t.pos = e.position / U
			# 摇杆跟着手指走，拉太远时起点跟上来
			var d: Vector2 = t.pos - t.start
			if d.length() > 22:
				t.start = t.pos - d.normalized() * 22
		_touch_sync()
	else:
		super._input(e)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		mouse_down = false
		touches.clear()
		_touch_sync()
		if S == "sv" and not _autoplay:
			S = "pause"

## 每两秒看一次实际帧率：连续两次不到 48 帧就降一档（少粒子、少伤害数字、同屏怪上限调低），
## 一局里只降不升，免得来回跳
func _q_check() -> void:
	var now := Time.get_ticks_msec()
	if _q_ms == 0 or S != "sv":
		_q_ms = now
		_q_fr = Engine.get_frames_drawn()
		return
	if now - _q_ms < 2000:
		return
	var fps := (Engine.get_frames_drawn() - _q_fr) * 1000.0 / float(now - _q_ms)
	_q_ms = now
	_q_fr = Engine.get_frames_drawn()
	if fps < 48.0 and gt2 > 6.0:
		_q_low += 1
		if _q_low >= 2 and qual < 2:
			_q_low = 0
			set_qual(qual + 1)
	else:
		_q_low = 0

func set_qual(q: int) -> void:
	qual = q
	CAP = [480, 360, 260][q]
	print("surv quality -> ", q)

func _physics_process(dt: float) -> void:
	if not _autoplay:
		_q_check()
	for i in _fast:
		if _autoplay:
			_sv_bot(dt)
		var t0 := Time.get_ticks_usec()
		step(dt)
		var us := Time.get_ticks_usec() - t0
		if S == "sv":
			_perf_n += 1
			_perf_us += us
			_perf_max = maxi(_perf_max, us)

# ======================================================================
# 主循环
# ======================================================================
func step(dt: float) -> void:
	T += dt
	match S:
		"hub":
			upd_hub()
		"sv":
			var k := 0.35 if slowmo > 0 else 1.0
			slowmo -= dt
			sv_update(dt * k)
			if pressed(KEY_ESCAPE) or pressed(KEY_P):
				S = "pause"
		"lvl":
			upd_lvl_panel()
		"pact":
			upd_pact()
		"shop":
			upd_shop()
		"pause":
			var mp := ppointer()
			if pressed(KEY_ESCAPE) or pressed(KEY_P) or pressed(KEY_ENTER) or pressed(KEY_SPACE) or (click_q and pause_btn(0).has_point(mp)):
				S = "sv"
			elif pressed(KEY_Q) or (click_q and pause_btn(1).has_point(mp)):
				end_run(false)
				over_t = 9.0
		"over":
			over_t += dt
			upd_particles(dt)
			upd_fx(dt)
			var mp := ppointer()
			if over_t > 1.2:
				if pressed(KEY_ENTER) or pressed(KEY_SPACE) or pressed(KEY_R) or (click_q and pause_btn(0).has_point(mp)):
					start_run()
				elif pressed(KEY_ESCAPE) or pressed(KEY_Q) or (click_q and pause_btn(1).has_point(mp)):
					S = "hub"
	if S != "hub":
		cam_pos += (Vector2(P.x, P.y) - cam_pos) * minf(1.0, dt * 8.0)
	else:
		cam_pos = Vector2(cos(T * 0.05) * 60, sin(T * 0.05) * 40)
	for t in toasts:
		t.t -= dt
	toasts = toasts.filter(func(t): return t.t > 0)
	banner_t -= dt
	shk = maxf(0.0, shk - dt * 14)
	Sfx.set_duck(1.0)
	Sfx.set_tide(TIDE * 0.6)
	jp.clear()
	click_q = false
	mouse_moved = false

func sv_update(dt: float) -> void:
	gt2 += dt
	# 调试：F9 快进一分钟（测试后期怪海用）
	if pressed(KEY_F9):
		gt2 += 60.0
	_fps_t += dt
	if _fps_t > 5.0:
		_fps_t = 0.0
		if not _autoplay:
			print("surv t=%d fps=%d enemies=%d step_ms=%.2f" % [int(gt2), Engine.get_frames_per_second(), E.size(), _perf_us / 1000.0 / maxf(1, _perf_n)])
			_perf_us = 0
			_perf_n = 0
	hurt_t = maxf(0.0, hurt_t - dt)
	frz_all = maxf(0.0, frz_all - dt)
	if shop_t > 0:
		shop_t -= dt
		if shop_t <= 0:
			open_shop()
			return
	upd_events()
	upd_spawn(dt)
	sv_player(dt)
	upd_poi(dt)
	build_grid()
	upd_enemies(dt)
	upd_pens(dt)
	upd_skills2(dt)
	upd_shots(dt)
	upd_inkb(dt)
	if frz_all <= 0:
		upd_eb(dt)
		upd_hazards(dt)
	upd_gems(dt)
	upd_fx(dt)
	upd_particles(dt)
	var tt := 1.0 if ev_tide() else 0.0
	TIDE += (tt - TIDE) * minf(1.0, dt * 1.5)
	if xp >= xp_need() and S == "sv":
		xp -= xp_need()
		lv += 1
		lv_q += 1
	if lv_q > 0 and S == "sv":
		open_lvl()

# ======================================================================
# 陶灵
# ======================================================================
func sv_player(dt: float) -> void:
	var ix := float(int(key(KEY_D) or key(KEY_RIGHT)) - int(key(KEY_A) or key(KEY_LEFT))) + joy.x
	var iy := float(int(key(KEY_S) or key(KEY_DOWN)) - int(key(KEY_W) or key(KEY_UP))) + joy.y
	if mouse_down and not touch_mode and absf(ix) + absf(iy) < 0.05:
		var m := get_global_mouse_position() - Vector2(P.x, P.y)
		if m.length() > 6:
			m = m.normalized()
			ix = m.x
			iy = m.y
	if _autoplay:
		ix = _bot_mv.x
		iy = _bot_mv.y
	var il := sqrt(ix * ix + iy * iy)
	if il > 1.0:
		ix /= il
		iy /= il
		il = 1.0
	P.moving = il > 0.05
	if P.moving:
		P.ax = ix / il
		P.ay = iy / il
		P.anim += dt * 8
	var c: Dictionary = SCH[P.ch]
	var spd: float = 78.0 * (1.0 + 0.1 * w("疾")) * float(c.sp) * (1.0 + 0.1 * rl("feather") - 0.05 * rl("weight") + 0.04 * bn("swift"))
	P.slow_t -= dt
	if P.slow_t > 0:
		spd *= 0.55
	P.dash_cd -= dt
	P.dash_t -= dt
	P.inv -= dt
	if (pressed(KEY_SPACE) or pressed(KEY_SHIFT) or pressed("dash")) and P.dash_cd <= 0:
		P.vx = P.ax * 260
		P.vy = P.ay * 260
		P.dash_t = 0.18
		P.inv = maxf(P.inv, 0.3)
		P.dash_cd = 2.2 * float(c.dash)
		P.slow_t = 0.0
		Sfx.play("dash")
		for i in 8:
			part(P.x, P.y, -P.ax * 60 + (randf() - 0.5) * 40, -P.ay * 60 + (randf() - 0.5) * 40, 0.4, CLAY, 4)
	if P.dash_t > 0:
		P.vx *= exp(-2.0 * dt)
		P.vy *= exp(-2.0 * dt)
		# 阿砖：冲刺会撞伤路上的敌人
		if P.ch == 2:
			for e: SV in near_list(P.x, P.y):
				if not e.dead and e.blade_cd <= 0 and absf(e.x - P.x) < e.r + 6 and absf(e.y - P.y) < e.r + 6:
					e.blade_cd = 0.3
					dsrc = "冲撞"
					dmg_e(e, 40.0 * dmg_k(), P.x, P.y, 120.0)
	else:
		var k := minf(1.0, dt * 14.0)
		P.vx += (ix * spd - P.vx) * k
		P.vy += (iy * spd - P.vy) * k
	# 引力胎、静默把人往里拽
	for e in E:
		if e.dead:
			continue
		var pull := 0.0
		var pr := 0.0
		if e.t == "grav":
			pull = 60.0
			pr = 110.0
		elif e.t == "silence":
			pull = 90.0 if e.sing > 0 else 26.0
			pr = 260.0
		if pull > 0:
			var gx := e.x - P.x
			var gy := e.y - P.y
			var gd := sqrt(gx * gx + gy * gy)
			if gd < pr and gd > 1:
				var f := pull * (1 - gd / pr)
				P.x += gx / gd * f * dt
				P.y += gy / gd * f * dt
		elif e.t == "binder" and e.sp > 0:
			var gx := e.x - P.x
			var gy := e.y - P.y
			var gd := maxf(1.0, sqrt(gx * gx + gy * gy))
			P.x += gx / gd * 45.0 * dt
			P.y += gy / gd * 45.0 * dt
	P.x += P.vx * dt
	P.y += P.vy * dt
	# 茶盏：慢慢回心
	if rl("tea") > 0:
		tea_t += dt * rl("tea")
		if tea_t > 40.0:
			tea_t = 0.0
			heal(1)
	# 厚土：自己回心
	if cmb("厚土"):
		heal_t2 += dt
		if heal_t2 > 25.0:
			heal_t2 = 0.0
			heal(1)
	# 风火：身后留火
	if cmb("风火") and P.moving:
		trail_t -= dt
		if trail_t <= 0:
			trail_t = 0.22
			add_fire(P.x - P.ax * 4, P.y - P.ay * 4, 7.0, 2.2)

func heal(n: int) -> void:
	if P.hp < P.maxhp:
		P.hp = mini(P.maxhp, P.hp + n)
		burst(P.x, P.y, 6, CLAY, 6, 30, 0.5)

func hurt(n: int, sx: float, sy: float) -> void:
	if P.inv > 0 or S != "sv":
		return
	if shield_on:
		shield_on = false
		sk_cd["shield"] = float(SK.shield.cd) - 3.0 * (skl("shield") - 1)
		P.inv = 0.8
		var big := w("环") > 0
		var R := 60.0 if big else 40.0
		BOOMS.append({"x": P.x, "y": P.y, "r": R, "t": 0.3, "T": 0.3, "m": ICE})
		Sfx.play("ping", 0.6)
		for e in E:
			var dx := e.x - P.x
			var dy := e.y - P.y
			var d := sqrt(dx * dx + dy * dy)
			if d < R and d > 0.1 and not e.boss:
				e.kx += dx / d * 220
				e.ky += dy / d * 220
				if big:
					dsrc = "墨盾"
					dmg_e(e, 40.0 * dmg_k(), P.x, P.y, 0.0)
		return
	if rl("jacket") > 0 and randf() < 0.15 * rl("jacket"):
		# 护封挡了一下
		P.inv = 0.8
		Sfx.play("ping", 1.6)
		burst(P.x, P.y, 8, PAPER, 6, 50, 0.4)
		return
	P.hp -= n + rl("gpen")
	P.inv = 1.3
	if rl("thorn") > 0:
		dsrc = "荆棘封皮"
		boom(P.x, P.y, 46.0, 50.0 * dmg_k() * rl("thorn"), false)
	if OS.get_cmdline_user_args().has("--hurtlog"):
		var ne := nearest(sx, sy, 30.0)
		print("HURT t=%.1f n=%d by=%s d=%.0f hp=%d E=%d lv=%d" % [gt2, n, ne.t if ne else "?", Vector2(sx - P.x, sy - P.y).length(), P.hp, E.size(), lv])
	hurt_t = 0.35
	shk = 6
	Sfx.play("hurt")
	burst(P.x, P.y, 10, CLAY, 5, 60, 0.5)
	# 挨打时把身边的东西推开一点，给自己留口气
	for e in E:
		var dx := e.x - P.x
		var dy := e.y - P.y
		var d := sqrt(dx * dx + dy * dy)
		if d < 34 and d > 0.1 and not e.elite and not e.boss:
			e.kx += dx / d * 160
			e.ky += dy / d * 160
	if P.hp <= 0:
		if revives > 0:
			revives -= 1
			P.hp = P.maxhp / 2
			P.inv = 2.5
			kiln_blast()
			set_banner("余火", "炉灯把你重新烧了出来", C_GOLD)
			return
		P.hp = 0
		end_run(false)

func end_run(win: bool) -> void:
	if S == "over":
		return
	won = win
	new_danger = false
	S = "over"
	over_t = 0.0
	earned = int((kills2 / 1000 + boss_kills * 6 + int(gt2 / 30.0) + (25 if win else 0)) * (1.0 + 0.3 * danger))
	if win and danger >= int(meta.get("dmax", 0)) and danger < 5:
		meta.dmax = danger + 1
		meta.dl = danger + 1
		new_danger = true
	meta.pages = int(meta.pages) + earned
	var b: Dictionary = meta.best
	b.time = maxf(float(b.get("time", 0.0)), gt2)
	b.lv = maxi(int(b.get("lv", 0)), lv)
	b.kills = maxi(int(b.get("kills", 0)), kills2)
	b.bosses = maxi(int(b.get("bosses", 0)), boss_kills)
	if win:
		b.wins = int(b.get("wins", 0)) + 1
		if pact != "":
			if not (meta.get("pw") is Dictionary):
				meta["pw"] = {}
			meta.pw[pact] = 1
	_save_meta()
	if win:
		Sfx.play("page")
		toast("炉灯重新亮了起来。", C_GOLD, 6)
	else:
		Sfx.play("die")
		burst(P.x, P.y, 30, CLAY, 6, 90, 1.0)
	print("SURV END win=%s t=%.1f stage=%d bosses=%d lv=%d kills=%d pens=%s evo=%s words=%s sk=%s god_saves=%d" % [win, gt2, stage + 1, boss_kills, lv, kills2, str(pens), str(evo.keys()), str(words), str(sk), _god_saves])
	print("   pact=%s rel=%s boon=%s dmg=%s" % [pact, str(rel), str(boon), str(ds_top(8))])

# ======================================================================
# 生物：生成、阶段、事件
# ======================================================================
func hp_k() -> float:
	return (1.0 + gt2 / 90.0 + pow(gt2 / 180.0, 2.45)) * (1.0 + 0.25 * danger) * (1.2 if pact == "greed" else 1.0)

func pick_type() -> String:
	var si := stage
	# 开局先只来最简单的两种，让人有时间摸清操作
	if gt2 < 22.0:
		return "moth" if randf() < 0.75 else "hush"
	if si > 0 and randf() < 0.2:
		si = randi() % si
	var p: Array = STAGES[si].pool
	var tot := 0.0
	for q in p:
		tot += q[1]
	var r := randf() * tot
	for q in p:
		r -= q[1]
		if r <= 0:
			if gt2 < 50.0 and q[0] in ["folio", "mite", "snail", "borer"]:
				return "moth"
			return q[0]
	return "moth"

func ring_pos(extra := 20.0) -> Vector2:
	var R := Vector2(W, H).length() * 0.5 + extra
	var a := randf() * TAU
	# 偏向小克前进的方向，免得一直从背后追
	if P.moving and randf() < 0.5:
		a = atan2(P.ay, P.ax) + (randf() - 0.5) * 2.2
	return Vector2(P.x + cos(a) * R, P.y + sin(a) * R)

func add_e(t: String, x: float, y: float) -> SV:
	var d: Dictionary = MT[t]
	var e := SV.new()
	e.t = t
	e.x = x
	e.y = y
	e.r = d.r
	e.ai = d.ai
	e.spd = d.sp * (0.9 + randf() * 0.2) * (1.0 + 0.04 * danger)
	e.mhp = d.hp * hp_k()
	e.hp = e.mhp
	e.xp = d.xp
	e.dmg = d.dmg
	e.ph = randf() * TAU
	e.cd = 1.0 + randf() * 2.0
	e.off = randi() % 2
	e.st = "chase"
	match t:
		"mothq", "grav":
			e.elite = true
		"clam":
			e.st = "open"
			e.open = 1.0
			e.na = -PI / 2
		"leech", "comet", "salamander", "eel":
			e.tr = PackedFloat32Array()
		"worm", "borer":
			e.seg = []
			for i in (6 if t == "worm" else 4):
				e.seg.append(Vector2(x, y))
			e.ang = atan2(P.y - y, P.x - x)
			if t == "borer":
				e.st = "burst"
		"mimic":
			e.st = "idle"
		"wisp", "ashghost", "angler":
			e.open = 1.0
	E.append(e)
	return e

## 按类型生成：有些要成对、有些要摆在屏幕里
func spawn_kind(t: String) -> void:
	var p := ring_pos()
	match t:
		"twin":
			var a := add_e("twin", p.x - 12, p.y)
			var b := add_e("twin", p.x + 12, p.y)
			a.mate = b
			b.mate = a
			a.off = 0
			b.off = 1
		"moth", "shard", "bat", "dove":
			for i in (3 + int(gt2 / 150.0)) if randf() < 0.5 else 1:
				if E.size() < CAP:
					add_e(t, p.x + (randf() - 0.5) * 18, p.y + (randf() - 0.5) * 18)
		"drip", "mimic":
			p = ring_pos(-40.0 - randf() * 40.0)
			add_e(t, p.x, p.y)
		_:
			add_e(t, p.x, p.y)

func upd_spawn(dt: float) -> void:
	var rate := 0.8 + gt2 * 0.036
	# 场上太空的时候补得更快，保证一直有一片怪海
	var want := minf(CAP - 40.0, 6.0 + gt2 * 0.5 + pow(gt2 / 260.0, 2.0) * 25.0)
	if E.size() < want:
		rate += (want - E.size()) * 0.6
	if not bosses.is_empty():
		# 首领战时小怪少一半；第一个首领再少一些，让新手能专心看招
		rate *= 0.5 if stage > 0 else 0.25
	if ev_tide():
		rate *= 0.5
	if pact == "swarm":
		rate *= 1.4
	if curse_t > 0:
		rate = rate * 2.0 + 1.0 + stage * 0.5
	spawn_acc += rate * dt
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if E.size() >= CAP:
			continue
		spawn_kind(pick_type())

func ev_tide() -> bool:
	return (stage == 1 or stage == 3 or stage == 5) and stage_t() >= 38.0 and stage_t() < 58.0

func once(id: String, at: float) -> bool:
	if gt2 >= at and not ev_done.has(id):
		ev_done[id] = true
		return true
	return false

func upd_events() -> void:
	var ns := mini(7, int(gt2 / STAGE_LEN))
	if ns != stage:
		stage = ns
		set_banner("第%s阶段 · %s" % ["一二三四五六七八"[stage], STAGES[stage].name], "新的生物来了", C_TEAL)
		Sfx.play("beacon")
	var t0 := stage * STAGE_LEN
	var sid := "s%d" % stage
	# 每个阶段：一只精英、一次小事件、一个首领
	if once(sid + "elite", t0 + 30):
		elite(["mothq", "blot", "stamp", "roller", "shade", "salamander", "angler", "grav"][stage])
	if once(sid + "ev", t0 + 52):
		match stage:
			0:
				flock(12)
				set_banner("书鳐迁徙", "一大群书鳐从旁边飞过", C_TEAL)
			2:
				flock(30)
			4:
				encircle(["shard"], 60)
				set_banner("碎镜", "碎镜片从四面八方飞过来", C_TEAL)
			6:
				encircle(["blotlet", "urchin"], 50)
			7:
				elite("grav")
				elite("mothq")
	if once(sid + "tide", t0 + 38) and ev_tide():
		set_banner("暗潮", "四面八方都围上来了", C_RED)
		Sfx.play("warn")
		encircle(["moth", "chill", "icicle"] if stage > 1 else ["moth", "chill"], 50 + stage * 8)
		if stage >= 3:
			elite("mothq")
	if once(sid + "comet", t0 + 12) and stage % 2 == 1:
		var p := ring_pos(-10)
		add_e("comet", p.x, p.y)
		toast("一条彗尾鱼游了过来，追上它！", C_TEAL, 4)
	if once(sid + "clam1", t0 + 20) or once(sid + "clam2", t0 + 66):
		var a := randf() * TAU
		var R := 70.0 + randf() * 50
		add_e("clam", P.x + cos(a) * R, P.y + sin(a) * R)
	if once(sid + "poi1", t0 + 7) or once(sid + "poi2", t0 + 46):
		add_poi()
	if once(sid + "warn", t0 + BOSS_IN - 5):
		set_banner("%s来了" % DEF[STAGES[stage].boss].name, BOSS_TIP[stage], C_RED)
		Sfx.play("roar")
		shk = 8
	if once(sid + "boss", t0 + BOSS_IN):
		spawn_boss(STAGES[stage].boss, stage)

func flock(n: int) -> void:
	var a := randf() * TAU
	var R := Vector2(W, H).length() * 0.5 + 30
	var sx := P.x + cos(a) * R
	var sy := P.y + sin(a) * R
	var dirx := -cos(a)
	var diry := -sin(a)
	for i in n:
		if E.size() >= CAP + 40:
			break
		var off := (i - n / 2.0) * 7.0
		var e := add_e("folio", sx - diry * off + dirx * (randf() * 30), sy + dirx * off + diry * (randf() * 30))
		e.st = "fly"
		e.hx = dirx * 75
		e.hy = diry * 75

func encircle(types: Array, n: int) -> void:
	var R := Vector2(W, H).length() * 0.5 + 10
	for i in n:
		var a := float(i) / n * TAU
		var e := add_e(types[i % types.size()], P.x + cos(a) * R, P.y + sin(a) * R)
		e.spd *= 0.8

func elite(t: String) -> void:
	var p := ring_pos()
	var e := add_e(t, p.x, p.y)
	if not e.elite:
		e.mhp *= 14.0
		e.hp = e.mhp
		e.xp *= 8
		e.dmg = maxi(e.dmg, 2)
	e.elite = true
	toast("精英：%s 来了，打倒它会掉一张散页" % DEF[t].name, C_GOLD, 4)

# ---------- 空间网格 ----------
func gk(x: float, y: float) -> int:
	return (floori(x / GCELL) + 4096) * 8192 + (floori(y / GCELL) + 4096)

func build_grid() -> void:
	G.clear()
	GCN.clear()
	for e in E:
		if e.dead:
			continue
		var k := gk(e.x, e.y)
		var a = G.get(k)
		if a == null:
			G[k] = [e]
			GCN[k] = Vector3(e.x, e.y, 1)
		else:
			a.append(e)
			GCN[k] += Vector3(e.x, e.y, 1)

## 附近的生物（查 3×3 个格子）
func near_list(x: float, y: float) -> Array:
	var out := []
	var cx := floori(x / GCELL)
	var cy := floori(y / GCELL)
	for j in range(-1, 2):
		for i in range(-1, 2):
			var a = G.get((cx + i + 4096) * 8192 + (cy + j + 4096))
			if a != null:
				out.append_array(a)
	return out

func can_tgt(e: SV) -> bool:
	if e.dead or e.t == "clam":
		return false
	if e.t == "wisp" and e.open < 0.25:
		return false
	if e.t == "mimic" and e.st == "idle":
		return false
	return true

func nearest(x: float, y: float, maxd: float, excl: Array = []) -> SV:
	var bd := maxd * maxd
	var best_e: SV = null
	for e in E:
		if not can_tgt(e) or excl.has(e):
			continue
		var dx := e.x - x
		var dy := e.y - y
		var d := dx * dx + dy * dy
		if d < bd:
			bd = d
			best_e = e
	return best_e

## 圆内的敌人：小范围查格子，大范围才扫全场
func in_radius(x: float, y: float, r: float) -> Array:
	if r > 56.0:
		return E
	var out := []
	var c0 := floori((x - r - 12.0) / GCELL)
	var c1 := floori((x + r + 12.0) / GCELL)
	var r0 := floori((y - r - 12.0) / GCELL)
	var r1 := floori((y + r + 12.0) / GCELL)
	for j in range(r0, r1 + 1):
		for i in range(c0, c1 + 1):
			var a = G.get((i + 4096) * 8192 + (j + 4096))
			if a != null:
				out.append_array(a)
	return out

## 子弹用的“附近最近的敌人"：只查周围 5×5 个格子，不扫全场
func near_e(x: float, y: float, excl: Array) -> SV:
	var bd := 1e9
	var best_e: SV = null
	var cx := floori(x / GCELL)
	var cy := floori(y / GCELL)
	for j in range(-2, 3):
		for i in range(-2, 3):
			var a = G.get((cx + i + 4096) * 8192 + (cy + j + 4096))
			if a == null:
				continue
			for e: SV in a:
				if not can_tgt(e) or excl.has(e):
					continue
				var d := (e.x - x) * (e.x - x) + (e.y - y) * (e.y - y)
				if d < bd:
					bd = d
					best_e = e
	return best_e

## 挑一个扎堆的地方（砚雷、印章用）
func crowd_target(maxd: float) -> Vector2:
	var bestk := -1
	var bestn := 0.0
	for k in GCN:
		var v: Vector3 = GCN[k]
		var c := Vector2(v.x / v.z, v.y / v.z)
		if c.distance_to(Vector2(P.x, P.y)) > maxd:
			continue
		var n := v.z + randf() * 2.0
		if n > bestn:
			bestn = n
			bestk = k
	if bestk >= 0:
		var v: Vector3 = GCN[bestk]
		return Vector2(v.x / v.z, v.y / v.z)
	var e := nearest(P.x, P.y, maxd)
	if e:
		return Vector2(e.x, e.y)
	return Vector2(P.x + P.ax * 50, P.y + P.ay * 50)

func add_sb(x: float, y: float, vx: float, vy: float, life: float, m: int, slow := 0.0, split_t := -1.0) -> void:
	if EB.size() > 260:
		return
	var b := SB.new()
	b.x = x
	b.y = y
	b.vx = vx
	b.vy = vy
	b.life = life
	b.m = m
	b.slow = slow
	b.split_t = split_t
	EB.append(b)

func add_fire(x: float, y: float, r: float, t: float) -> void:
	if FIRE.size() < 60:
		FIRE.append({"x": x, "y": y, "r": r, "t": t})

# ---------- 每只生物 ----------
func upd_enemies(dt: float) -> void:
	var far := far_r()
	var keep: Array[SV] = []
	for e in E:
		if e.dead:
			continue
		e.flash -= dt
		e.blade_cd -= dt
		e.fire_cd -= dt
		e.slow -= dt
		if e.burn_t > 0:
			e.burn_t -= dt
			e.burn += e.burn_dps * dt
			if e.burn >= 1.0:
				var b := floorf(e.burn)
				e.burn -= b
				dsrc = "灼烧"
				dmg_e(e, b, e.x, e.y, 0.0, false, false)
				if randf() < 0.3:
					part(e.x, e.y - 2, (randf() - 0.5) * 10, -20, 0.4, EMBER, 5, true)
				if e.dead:
					continue
		# 被冻住 / 定格：什么都不做
		if e.frz > 0 or frz_all > 0:
			e.frz -= dt
			e.x += e.kx * dt
			e.y += e.ky * dt
			e.kx *= exp(-9.0 * dt)
			e.ky *= exp(-9.0 * dt)
			keep.append(e)
			continue
		e.age += dt
		var dx := P.x - e.x
		var dy := P.y - e.y
		var d := sqrt(dx * dx + dy * dy)
		var ux := dx / maxf(d, 0.01)
		var uy := dy / maxf(d, 0.01)
		var sk_ := 0.5 if e.slow > 0 else 1.0
		var vx := 0.0
		var vy := 0.0
		var touch := true
		match e.ai:
			"boss":
				upd_boss(e, dt, d, ux, uy)
				if not e.dead:
					keep.append(e)
				continue
			"chase":
				var wob := sin(e.age * 2.5 + e.ph) * 0.35
				vx = (ux - uy * wob) * e.spd
				vy = (uy + ux * wob) * e.spd
				if e.t == "chill":
					e.sp = clampf(1.0 - d / 60.0, 0.0, 1.0)
				elif e.t == "shade":
					e.st = "hunt"
			"folio":
				if e.st == "fly":
					vx = e.hx
					vy = e.hy
					if d > far + 60:
						e.dead = true
						continue
				else:
					var wob := sin(e.age * 3 + e.ph) * 0.5
					vx = (ux - uy * wob) * e.spd
					vy = (uy + ux * wob) * e.spd
			"lunge":
				var L: Array = LG[e.t]
				e.cd -= dt
				if e.t == "angler":
					e.open = clampf(1.3 - d / 80.0, 0.0, 1.0)
				if e.st == "chase":
					vx = ux * e.spd
					vy = uy * e.spd
					e.ha = atan2(uy, ux)
					if d < L[0] and e.cd <= 0:
						e.st = L[5]
						e.tm = L[1]
				elif e.st == L[5]:
					e.tm -= dt
					vx = ux * 0.01
					vy = uy * 0.01
					e.ha = atan2(uy, ux)
					if e.tm <= 0:
						e.st = L[6]
						e.tm = L[3]
						e.hx = ux * L[2]
						e.hy = uy * L[2]
				elif e.st == L[6]:
					e.tm -= dt
					vx = e.hx
					vy = e.hy
					if e.tm <= 0:
						if L[7] != "":
							e.st = L[7]
							e.tm = L[8]
						else:
							e.st = "chase"
							e.cd = L[4]
				else:
					e.tm -= dt
					if e.tm <= 0:
						e.st = "chase"
						e.cd = L[4]
				if e.t == "leech":
					_trail(e, dt, 8)
			"aimdash":
				var eel := e.t == "eel"
				if e.st == "chase":
					e.ang = atan2(uy, ux)
					e.ha = e.ang
					vx = (ux - uy * 0.5) * e.spd if eel else ux * e.spd
					vy = (uy + ux * 0.5) * e.spd if eel else uy * e.spd
					e.cd -= dt
					if d < 120 and e.cd <= 0:
						e.st = "aim"
						e.tm = 0.8
				elif e.st == "aim":
					e.tm -= dt
					if e.tm > 0.35:
						e.ang = atan2(uy, ux)
						e.ha = e.ang
					vx = cos(e.ang) * 0.01
					vy = sin(e.ang) * 0.01
					if e.tm <= 0:
						e.st = "zap" if eel else "dash"
						e.tm = 0.7 if eel else 0.9
				else:
					e.tm -= dt
					vx = cos(e.ang) * (250.0 if eel else 230.0)
					vy = sin(e.ang) * (250.0 if eel else 230.0)
					if randf() < 0.5:
						part(e.x, e.y, 0, 0, 0.3, GOLD if eel else ICE, 5, eel)
					if e.tm <= 0:
						e.st = "chase"
						e.cd = 2.5 + randf()
				if eel:
					_trail(e, dt, 10)
			"shoot":
				var q: Array = SH[e.t]
				var side := 1.0 if e.off == 0 else -1.0
				e.cd -= dt
				if e.t == "squid":
					e.ang = atan2(uy, ux)
				if e.st == "aim":
					e.tm -= dt
					if e.tm <= 0:
						e.st = "chase"
						e.cd = q[1] * (0.8 + randf() * 0.4)
						e.sp = 0.0
						var bs: float = q[2]
						match e.t:
							"comma": add_sb(e.x, e.y, ux * bs, uy * bs, 4.0, JELLY)
							"spider": add_sb(e.x, e.y, ux * bs, uy * bs, 4.0, ICE, 2.5)
							"prismbug": add_sb(e.x, e.y, ux * bs, uy * bs, 4.0, MIRROR, 0.0, 0.7)
							"squid": add_sb(e.x, e.y, ux * bs, uy * bs, 4.5, GRAV, 2.0)
				else:
					if d > q[0]:
						vx = ux * e.spd
						vy = uy * e.spd
					elif d < q[0] * 0.6:
						vx = -ux * e.spd
						vy = -uy * e.spd
					else:
						vx = -uy * side * e.spd * 0.7
						vy = ux * side * e.spd * 0.7
					if e.cd <= 0 and d < q[0] * 1.5:
						e.st = "aim"
						e.tm = 0.45
						e.sp = 1.0
			"mite":
				e.ang = rotate_toward(e.ang, atan2(uy, ux), dt * 1.6)
				vx = ux * e.spd
				vy = uy * e.spd
			"snail":
				e.ang = atan2(uy, ux)
				e.w = 1.0 if ux >= 0 else -1.0
				vx = ux * e.spd
				vy = uy * e.spd
				e.cd -= dt
				if e.cd <= 0 and d < 110:
					e.cd = 4.0
					for i in 3:
						var a := atan2(uy, ux) + (i - 1) * 0.3
						add_sb(e.x, e.y, cos(a) * 60, sin(a) * 60, 3.0, ROCK)
			"worm":
				e.ang = rotate_toward(e.ang, atan2(uy, ux), dt * 2.2)
				var wv := sin(e.age * 5 + e.ph) * 0.4
				vx = cos(e.ang + wv) * e.spd
				vy = sin(e.ang + wv) * e.spd
				var prev := Vector2(e.x, e.y)
				for i in e.seg.size():
					var s := e.seg[i]
					var v := s - prev
					var L := v.length()
					if L > 3.2:
						s = prev + v / L * 3.2
					e.seg[i] = s
					prev = s
			"wisp":
				var wob := sin(e.age * 2 + e.ph) * 0.5
				vx = (ux - uy * wob) * e.spd
				vy = (uy + ux * wob) * e.spd
				if e.t == "wisp":
					e.open = clampf(0.55 + 0.75 * sin(e.age * 1.1 + e.ph), 0.0, 1.0)
					touch = e.open > 0.25
				else:
					e.open = 0.5 + 0.5 * sin(e.age * 1.6 + e.ph)
			"boom":
				var nova := e.t == "nova"
				if e.st == "chase":
					vx = ux * e.spd
					vy = uy * e.spd
					if d < (42.0 if nova else 20.0):
						e.st = "swell"
						e.tm = 1.2 if nova else 0.6
						e.sp = 0.0
				else:
					e.tm -= dt
					e.sp = minf(1.0, e.sp + dt / (1.2 if nova else 0.6))
					if e.tm <= 0:
						e.dead = true
						if nova:
							ER.append({"x": e.x, "y": e.y, "r": 6.0, "v": 85.0, "max": 55.0})
						else:
							BOOMS.append({"x": e.x, "y": e.y, "r": 24.0, "t": 0.3, "T": 0.3, "m": SERP})
							if d < 26:
								hurt(1, e.x, e.y)
						burst(e.x, e.y, 10, GOLD if nova else EMBER, 6, 70, 0.5)
						snd("rock", 0.8, 0.08)
						continue
			"stamp":
				e.cd -= dt
				if e.st == "chase":
					if e.cd <= 0:
						e.st = "jump"
						e.tm = 0.6
						var jl := minf(d, 62.0) / 0.6
						e.hx = ux * jl
						e.hy = uy * jl
				else:
					e.tm -= dt
					vx = e.hx
					vy = e.hy
					e.sp = sin((0.6 - e.tm) / 0.6 * PI) * 10.0
					touch = false
					if e.tm <= 0:
						e.sp = 0.0
						e.st = "chase"
						e.cd = 0.9
						ER.append({"x": e.x, "y": e.y, "r": 4.0, "v": 70.0, "max": 24.0})
			"hop":
				var hp_ := fposmod(e.age * 2.0 + e.ph, 1.0)
				if hp_ < 0.6:
					e.sp = sin(hp_ / 0.6 * PI)
					vx = ux * e.spd * 1.7
					vy = uy * e.spd * 1.7
				else:
					e.sp = 0.0
			"roller":
				if e.st == "chase":
					e.hx = ux
					e.hy = uy
					e.st = "roll"
					e.tm = 3.0
				else:
					e.tm -= dt
					var k := e.spd * (1.0 + (e.r - 4.0) * 0.12)
					vx = e.hx * k
					vy = e.hy * k
					e.ang += dt * 8.0
					e.r = minf(9.0, e.r + dt * 1.6)
					e.dmg = 2 if e.r > 7.0 else 1
					if e.tm <= 0 or (d > 120 and e.hx * ux + e.hy * uy < 0):
						e.st = "chase"
			"mimic":
				if e.st == "idle":
					touch = false
					if d < 34:
						e.st = "wake"
						e.tm = 0.4
						snd("warn", 2.0, 0.3)
				elif e.st == "wake":
					e.tm -= dt
					if e.tm <= 0:
						e.st = "bite"
				else:
					vx = ux * e.spd
					vy = uy * e.spd
			"shard":
				if e.st == "chase":
					var a := atan2(uy, ux) + (randf() - 0.5) * 0.7
					e.hx = cos(a)
					e.hy = sin(a)
					e.st = "fly"
				vx = e.hx * e.spd
				vy = e.hy * e.spd
				e.ang += dt * 6.0
			"sala":
				var wob := sin(e.age * 3 + e.ph) * 0.8
				vx = (ux - uy * wob) * e.spd
				vy = (uy + ux * wob) * e.spd
				e.ang = atan2(vy, vx)
				_trail(e, dt, 7)
				e.t2 -= dt
				if e.t2 <= 0 and d < far - 60 and EF.size() < 70:
					e.t2 = 0.35
					EF.append({"x": e.x, "y": e.y, "r": 5.0, "t": 2.2, "ink": false})
			"drip":
				e.cd -= dt
				e.sp = maxf(0.0, e.sp - dt * 2.0)
				if e.cd <= 0 and d < 170:
					e.cd = 3.2
					e.sp = 1.0
					EA.append({"x": P.x, "y": P.y, "r": 14.0, "t": 1.0, "T": 1.0, "fire": true})
			"urchin":
				e.cd -= dt
				if e.st == "puff":
					e.sp += dt * 2.0
					if e.sp >= 1.0:
						for i in 8:
							var a := i * TAU / 8.0 + e.off * TAU / 16.0
							add_sb(e.x, e.y, cos(a) * 70, sin(a) * 70, 2.5, SERP)
						e.sp = 0.0
						e.off = 1 - e.off
						e.st = "chase"
						e.cd = 3.5
				else:
					vx = ux * e.spd
					vy = uy * e.spd
					if e.cd <= 0 and d < 100:
						e.st = "puff"
			"sat":
				var side := 1.0 if e.off == 0 else -1.0
				var rad := clampf((d - 72.0) * 1.5, -50.0, 60.0)
				vx = -uy * side * e.spd + ux * rad
				vy = ux * side * e.spd + uy * rad
				e.cd -= dt
				e.sp = maxf(0.0, e.sp - dt)
				if e.cd <= 0 and d < 110:
					e.cd = 2.8
					e.sp = 0.3
					add_sb(e.x, e.y, ux * 62, uy * 62, 3.0, EMBER)
			"twin":
				var m := e.mate as SV
				if m != null and not m.dead:
					var side := 1.0 if e.off == 0 else -1.0
					var mid := Vector2((e.x + m.x) * 0.5, (e.y + m.y) * 0.5)
					var ax := Vector2(P.x, P.y) - mid
					var al := maxf(1.0, ax.length())
					ax /= al
					var tg := Vector2(P.x, P.y) + Vector2(-ax.y, ax.x) * 40.0 * side + ax * 25.0
					var tv := tg - Vector2(e.x, e.y)
					var tl := maxf(1.0, tv.length())
					vx = tv.x / tl * e.spd
					vy = tv.y / tl * e.spd
					if e.off == 0:
						# 两颗星中间的光会烫人
						var sv := Vector2(m.x - e.x, m.y - e.y)
						var sl := sv.length()
						if sl > 1 and sl < 150:
							var tt := clampf(((P.x - e.x) * sv.x + (P.y - e.y) * sv.y) / (sl * sl), 0.0, 1.0)
							if Vector2(e.x + sv.x * tt - P.x, e.y + sv.y * tt - P.y).length() < 3.0:
								hurt(1, P.x, P.y)
				else:
					vx = ux * e.spd * 1.6
					vy = uy * e.spd * 1.6
			"mothq":
				vx = ux * e.spd
				vy = uy * e.spd
				e.cd -= dt
				if e.cd <= 0 and E.size() < CAP + 30:
					e.cd = 1.4
					for i in 2:
						var m := add_e("moth", e.x + (randf() - 0.5) * 8, e.y + (randf() - 0.5) * 8)
						m.xp = 0
			"comet":
				var a := atan2(-uy, -ux) + sin(e.age * 1.3) * 0.9
				vx = cos(a) * e.spd
				vy = sin(a) * e.spd
				_trail(e, dt, 12)
				if e.age > 30 and d > far:
					e.dead = true
					toast("彗尾鱼游走了……", C_DIM, 2)
					continue
			"still":
				touch = false
		var still := e.ai == "still" or e.ai == "drip" or (e.ai == "mimic" and e.st == "idle")
		# 挤一挤：从自己所在格子的重心往外推
		var gc = GCN.get(gk(e.x, e.y))
		if gc != null and gc.z > 1.5 and not still:
			var cx: float = gc.x / gc.z
			var cy: float = gc.y / gc.z
			var px := e.x - cx
			var py := e.y - cy
			var pl := sqrt(px * px + py * py)
			if pl < 0.01:
				px = randf() - 0.5
				py = randf() - 0.5
				pl = 0.7
			var f := minf(60.0, (gc.z - 1.0) * 9.0)
			vx += px / pl * f
			vy += py / pl * f
		e.vx = vx
		e.vy = vy
		e.x += (vx * sk_ + e.kx) * dt
		e.y += (vy * sk_ + e.ky) * dt
		var kd := exp(-9.0 * dt)
		e.kx *= kd
		e.ky *= kd
		# 碰到小克
		if touch and e.dmg > 0 and d < e.r + 3.5:
			hurt(e.dmg, e.x, e.y)
		# 落在屏幕外太远的，挪到前面去（不浪费）
		if d > far:
			if still:
				if d > far * 2.0:
					e.dead = true
					continue
			elif e.st != "fly" or e.t == "shard":
				if not e.elite and e.t != "comet":
					e.gone_t += dt
					if e.gone_t > 1.5:
						e.gone_t = 0.0
						var p := ring_pos()
						e.x = p.x
						e.y = p.y
						if e.ai == "shard" or e.ai == "roller":
							e.st = "chase"
							if e.ai == "roller":
								e.r = 4.0
						for i in e.seg.size():
							e.seg[i] = p
						if e.tr.size() > 0:
							e.tr = PackedFloat32Array()
		else:
			e.gone_t = 0.0
		keep.append(e)
	E = keep

func _trail(e: SV, dt: float, n: int) -> void:
	e.tr_t -= dt
	if e.tr_t > 0:
		return
	e.tr_t = 0.04
	e.tr.insert(0, e.y)
	e.tr.insert(0, e.x)
	if e.tr.size() > n * 2:
		e.tr.resize(n * 2)

# ======================================================================
# 首领：八个，各有自己的招
# ======================================================================
const BOSS_HP := [2600.0, 10000.0, 20000.0, 32000.0, 48000.0, 76000.0, 110000.0, 200000.0]
const BOSS_TIP := [
	"它会停下来瞄准，然后直直撞过来",
	"看见细线就让开，线过一会儿才落下",
	"针会飞，线会绷成五角星，还会把你往它那边拉",
	"会飞卡片、画网格线，还会刮暴风雪",
	"它学你开枪，身子一抖就是要冲过来",
	"落点先出现圈；两道火光会绕着它转",
	"触手会沿着一条线砸下来，墨会拖住脚步",
	"它一直在把你往里拽；圈扩过来时冲刺穿过去",
]

func spawn_boss(t: String, i: int) -> void:
	var p := ring_pos(-20)
	var e := add_e(t, p.x, p.y)
	e.boss = true
	e.elite = true
	e.mhp = BOSS_HP[i] * (1.0 + 0.25 * danger)
	e.hp = e.mhp
	e.st = "fight"
	e.ha = atan2(P.y - p.y, P.x - p.x)
	e.cd = 3.0
	e.burst_t = 3.0
	e.n2 = 0
	e.sp = 0.0
	e.sing = 0.0
	e.orR = 0.0
	if t == "serp":
		e.st = "chase"
		e.seg = []
		for k in 16:
			e.seg.append(Vector2(p.x, p.y))
		e.cd = 5.0
	bosses.append(e)

func b_ring(e: SV, n: int, sp: float, m: int, a0 := 0.0, life := 5.0) -> void:
	for i in n:
		var a := float(i) / n * TAU + a0
		add_sb(e.x, e.y, cos(a) * sp, sin(a) * sp, life, m)

func b_fan(e: SV, a: float, n: int, spread: float, sp: float, m: int) -> void:
	for i in n:
		var aa := a + (float(i) / maxf(1, n - 1) - 0.5) * spread if n > 1 else a
		add_sb(e.x, e.y, cos(aa) * sp, sin(aa) * sp, 4.5, m)

func e_line(x: float, y: float, a: float, ln: float, wd: float, delay: float) -> void:
	EL.append({"x": x, "y": y, "a": a, "len": ln, "w": wd, "t": delay, "T": delay})

func e_circle(x: float, y: float, r: float, delay: float, fire := false) -> void:
	EA.append({"x": x, "y": y, "r": r, "t": delay, "T": delay, "fire": fire})

func upd_boss(e: SV, dt: float, d: float, ux: float, uy: float) -> void:
	var rage := e.hp < e.mhp * 0.5
	var slowk := 0.6 if e.slow > 0 else 1.0
	e.cd -= dt
	e.burst_t -= dt
	e.sing = maxf(0.0, e.sing - dt)
	var vx := 0.0
	var vy := 0.0
	var pa := atan2(uy, ux)
	match e.t:
		"serp":
			var sp := e.spd * (1.25 if rage else 1.0)
			match e.st:
				"chase":
					e.ha = rotate_toward(e.ha, pa, dt * (2.6 if rage else 2.0))
					vx = cos(e.ha) * sp
					vy = sin(e.ha) * sp
					if e.cd <= 0 and d < 170:
						e.st = "aim"
						e.tm = 0.9
						Sfx.play("warn", 1.4)
					if e.burst_t <= 0:
						e.burst_t = 2.6 if rage else 3.6
						b_ring(e, 12 if rage else 8, 54, SERP, e.age)
						Sfx.play("note", 0.7)
				"aim":
					e.tm -= dt
					if e.tm > 0.3:
						e.ha = pa
					if e.tm <= 0:
						e.st = "charge"
						e.tm = 1.0
						shk = 5
						Sfx.play("roar", 1.5)
				"charge":
					e.tm -= dt
					vx = cos(e.ha) * 250
					vy = sin(e.ha) * 250
					if randf() < 0.6:
						part(e.x, e.y, 0, 0, 0.5, SERP, 5, true)
					if e.tm <= 0:
						e.st = "chase"
						e.cd = 4.5 if rage else 6.0
		"redact":
			e.ha = pa
			var k := 1.0 if d > 100 else (-0.6 if d < 60 else 0.0)
			vx = ux * e.spd * k - uy * 12.0
			vy = uy * e.spd * k + ux * 12.0
			if e.cd <= 0:
				e.cd = 1.7 if rage else 2.4
				e.sing = 0.7
				e.n2 += 1
				snd("warn", 1.8, 0.2)
				match e.n2 % 3:
					0:
						var a0 := randf() * PI
						for i in 3 if rage else 2:
							var a := a0 + i * PI / (3 if rage else 2)
							e_line(P.x - cos(a) * 200, P.y - sin(a) * 200, a, 400, 4.0, 0.9)
					1:
						var a := pa + PI / 2
						for i in range(-2, 3):
							e_line(P.x + cos(pa) * i * 26 - cos(a) * 200, P.y + sin(pa) * i * 26 - sin(a) * 200, a, 400, 4.0, 0.8 + absi(i) * 0.15)
					2:
						for i in 4:
							if E.size() < CAP:
								add_e("comma", e.x + (randf() - 0.5) * 30, e.y + (randf() - 0.5) * 30)
		"binder":
			e.ha = pa
			e.ang = rotate_toward(e.ang, pa, dt * 3.0)
			e.sp = maxf(0.0, e.sp - dt)
			var k := 1.0 if d > 80 else 0.0
			vx = ux * e.spd * k
			vy = uy * e.spd * k
			if e.cd <= 0:
				e.cd = 1.6 if rage else 2.3
				e.n2 += 1
				match e.n2 % 3:
					0:
						b_fan(e, pa, 7 if rage else 5, 0.7, 115, MIRROR)
						snd("shoot", 0.6, 0.1)
					1:
						# 五角星
						var a0 := randf() * TAU
						for i in 5:
							var p1 := Vector2(P.x + cos(a0 + i * TAU / 5) * 75, P.y + sin(a0 + i * TAU / 5) * 75)
							var p2 := Vector2(P.x + cos(a0 + (i + 2) * TAU / 5) * 75, P.y + sin(a0 + (i + 2) * TAU / 5) * 75)
							e_line(p1.x, p1.y, (p2 - p1).angle(), p1.distance_to(p2), 3.0, 1.0)
						snd("warn", 1.6, 0.2)
					2:
						e.sp = 2.2
						toast("装订师在拉线！往外跑", C_RED, 2)
						if rage:
							b_ring(e, 12, 60, WINE, e.age)
		"index":
			e.sp = maxf(0.0, e.sp - dt)
			e.orR = 1.0 if rage else 0.0
			vx = ux * e.spd
			vy = uy * e.spd
			if e.sp > 0:
				# 暴风雪：把人往一边吹
				P.x += cos(e.ang) * 32.0 * dt
				P.y += sin(e.ang) * 32.0 * dt
				if randf() < 0.5:
					part(P.x + (randf() - 0.5) * W, P.y + (randf() - 0.5) * H, cos(e.ang) * 160, sin(e.ang) * 160, 0.6, PAPER, 5)
			if e.cd <= 0:
				e.cd = 1.9 if rage else 2.7
				e.n2 += 1
				match e.n2 % 3:
					0:
						e.sing = 0.8
						for k in 3:
							b_fan(e, pa + (k - 1) * 0.9, 5, 0.5, 80 + k * 10, PAPER)
					1:
						for i in range(-1, 2):
							e_line(P.x - 220, P.y + i * 44, 0.0, 440, 4.0, 1.1)
							e_line(P.x + i * 44, P.y - 220, PI / 2, 440, 4.0, 1.1)
						snd("warn", 1.6, 0.2)
					2:
						e.sp = 3.0
						e.ang = randf() * TAU
						toast("暴风雪！", C_TEAL, 2)
						for i in 3 if rage else 2:
							var p := ring_pos(-30)
							add_e("icicle", p.x, p.y)
		"mirror":
			e.orR = 1.0 if rage else 0.0
			if e.sp > 0:
				e.sp -= dt
				if e.sp > 0.45:
					e.ang = pa
				else:
					vx = cos(e.ang) * 300
					vy = sin(e.ang) * 300
			else:
				var side := 1.0 if e.n2 % 2 == 0 else -1.0
				var rad := clampf((d - 85.0) * 1.5, -60.0, 70.0)
				vx = -uy * side * e.spd + ux * rad
				vy = ux * side * e.spd + uy * rad
				if e.cd <= 0:
					e.cd = 1.0 if rage else 1.4
					e.n2 += 1
					if e.n2 % 4 == 3:
						e.sp = 0.9
						snd("warn", 2.0, 0.2)
					else:
						b_fan(e, pa, 3, 0.3, 120, CLAY)
				if rage and e.burst_t <= 0:
					e.burst_t = 6.0
					for i in 6:
						if E.size() < CAP:
							add_e("shard", e.x + (randf() - 0.5) * 20, e.y + (randf() - 0.5) * 20)
		"wick":
			e.orR = 2.0 if e.hp < e.mhp * 0.33 else (1.0 if e.hp < e.mhp * 0.66 else 0.0)
			vx = ux * e.spd
			vy = uy * e.spd
			if e.sing > 0:
				e.ang += dt * (1.1 if rage else 0.85)
				for q in 2:
					var a := e.ang + q * PI
					var fx := cos(a)
					var fy := sin(a)
					var al := (P.x - e.x) * fx + (P.y - e.y) * fy
					if al > 10 and al < 240 and absf(-(P.x - e.x) * fy + (P.y - e.y) * fx) < 3.5:
						hurt(1, P.x, P.y)
			if e.cd <= 0:
				e.cd = 1.8 if rage else 2.5
				e.n2 += 1
				match e.n2 % 3:
					0:
						for i in 6 if rage else 4:
							e_circle(P.x + (randf() - 0.5) * 90 * minf(1.0, float(i)), P.y + (randf() - 0.5) * 90 * minf(1.0, float(i)), 16.0, 1.0 + i * 0.12, true)
					1:
						b_ring(e, 14, 62, EMBER, e.age)
						b_ring(e, 14, 44, GOLD, e.age + 0.22)
					2:
						if e.sing <= 0:
							e.sing = 4.5
							e.ang = pa + PI / 2
							toast("火光在转！跟着它绕", C_GOLD, 2)
						if e.orR >= 1 and E.size() < CAP:
							for i in 3:
								add_e("salamander", e.x + (randf() - 0.5) * 30, e.y + (randf() - 0.5) * 30)
		"kraken":
			e.ha = pa
			e.orR = 2.0 if e.hp < e.mhp * 0.33 else (1.0 if e.hp < e.mhp * 0.66 else 0.0)
			var k := 1.0 if d > 70 else 0.0
			vx = ux * e.spd * k
			vy = uy * e.spd * k
			if e.cd <= 0:
				e.cd = 1.7 if rage else 2.4
				e.n2 += 1
				match e.n2 % 3:
					0:
						for i in 7:
							e_circle(e.x + ux * (24 + i * 24), e.y + uy * (24 + i * 24), 13.0, 0.6 + i * 0.12)
						if rage:
							for i in 8:
								var a := i * TAU / 8
								e_circle(P.x + cos(a) * 46, P.y + sin(a) * 46, 12.0, 1.3)
					1:
						for i in 3:
							EF.append({"x": P.x + (randf() - 0.5) * 100, "y": P.y + (randf() - 0.5) * 100, "r": 26.0, "t": 6.0, "ink": true})
						b_fan(e, pa, 5, 1.0, 55, GRAV)
					2:
						for i in 3:
							if E.size() < CAP:
								add_e("urchin" if i < 2 else "angler", e.x + (randf() - 0.5) * 40, e.y + (randf() - 0.5) * 40)
		"silence":
			e.ha = pa
			e.ang += dt * 0.5
			e.orR = 2.0 if e.hp < e.mhp * 0.33 else (1.0 if e.hp < e.mhp * 0.66 else 0.0)
			vx = ux * e.spd
			vy = uy * e.spd
			if e.burst_t > 0 and e.n2 % 4 == 1:
				e.t2 -= dt
				if e.t2 <= 0:
					e.t2 = 0.07 if rage else 0.1
					e.na += 0.47
					add_sb(e.x, e.y, cos(e.na) * 70, sin(e.na) * 70, 5.0, SERP)
					if e.orR >= 2:
						add_sb(e.x, e.y, -cos(e.na) * 70, -sin(e.na) * 70, 5.0, GOLD)
			if e.cd <= 0:
				e.cd = 1.9 if rage else 2.6
				e.n2 += 1
				match e.n2 % 4:
					0:
						ER.append({"x": e.x, "y": e.y, "r": 18.0, "v": 75.0, "max": 250.0})
						if rage:
							ER.append({"x": e.x, "y": e.y, "r": 2.0, "v": 75.0, "max": 250.0})
						snd("roar", 1.8, 0.3)
					1:
						e.burst_t = 2.2
					2:
						e.sing = 3.0
						toast("它在吸！往外冲", C_RED, 2)
						for i in 5:
							e_circle(P.x + (randf() - 0.5) * 70, P.y + (randf() - 0.5) * 70, 15.0, 1.2 + i * 0.25)
					3:
						if E.size() < CAP - 10:
							if e.orR >= 1:
								spawn_kind("twin")
							for i in 3:
								var p := ring_pos(-40)
								add_e("nova", p.x, p.y)
	e.vx = vx
	e.vy = vy
	e.x += (vx * slowk + e.kx) * dt
	e.y += (vy * slowk + e.ky) * dt
	e.kx *= exp(-9 * dt)
	e.ky *= exp(-9 * dt)
	if e.t == "serp":
		# 身子一节跟一节
		var prev := Vector2(e.x, e.y)
		for i in e.seg.size():
			var s := e.seg[i]
			var v := s - prev
			var L := v.length()
			if L > 5.0:
				s = prev + v / L * 5.0
			e.seg[i] = s
			prev = s
			if s.distance_to(Vector2(P.x, P.y)) < 7:
				hurt(1, s.x, s.y)
	if d < e.r + 4:
		hurt(e.dmg, e.x, e.y)
	# 跑太远就从前面绕回来
	if d > far_r() + 90:
		var p := ring_pos()
		e.x = p.x
		e.y = p.y
		for i in e.seg.size():
			e.seg[i] = p

# ---------- 敌方的子弹和预告 ----------
func upd_eb(dt: float) -> void:
	var keep: Array[EBullet] = []
	var add: Array = []
	for b in EB:
		b.life -= dt
		b.x += b.vx * dt
		b.y += b.vy * dt
		if b.life <= 0:
			continue
		var s := b as SB
		if s != null and s.split_t > 0:
			s.split_t -= dt
			if s.split_t <= 0:
				var a := atan2(b.vy, b.vx)
				var spd := Vector2(b.vx, b.vy).length()
				for i in 3:
					add.append([b.x, b.y, a + (i - 1) * 0.45, spd, [EMBER, GOLD, ICE][i]])
				continue
		if absf(b.x - P.x) < 3.5 and absf(b.y - P.y) < 3.5:
			if s != null and s.slow > 0:
				if P.inv <= 0:
					P.slow_t = s.slow
					toast("被粘住了，冲刺能甩掉", C_DIM, 1.5)
			else:
				hurt(1, b.x, b.y)
			continue
		keep.append(b)
	EB = keep
	for q in add:
		add_sb(q[0], q[1], cos(q[2]) * q[3], sin(q[2]) * q[3], 2.5, q[4])

func upd_hazards(dt: float) -> void:
	var px := P.x
	var py := P.y
	for a in EA:
		a.t -= dt
		if a.t <= 0:
			var dx: float = a.x - px
			var dy: float = a.y - py
			if dx * dx + dy * dy < a.r * a.r:
				hurt(1, a.x, a.y)
			BOOMS.append({"x": a.x, "y": a.y, "r": a.r, "t": 0.25, "T": 0.25, "m": SERP})
			if a.fire and EF.size() < 70:
				EF.append({"x": a.x, "y": a.y, "r": a.r * 0.8, "t": 2.0, "ink": false})
			snd("rock", 0.7, 0.08)
	EA = EA.filter(func(a): return a.t > 0)
	for f in EF:
		f.t -= dt
		var dx: float = f.x - px
		var dy: float = f.y - py
		if dx * dx + dy * dy < f.r * f.r:
			if f.ink:
				if P.dash_t <= 0:
					P.slow_t = maxf(P.slow_t, 0.25)
			else:
				hurt(1, f.x, f.y)
	EF = EF.filter(func(f): return f.t > 0)
	for l in EL:
		l.t -= dt
		if l.t <= 0:
			var fx := cos(l.a)
			var fy := sin(l.a)
			var dx: float = px - l.x
			var dy: float = py - l.y
			var al := dx * fx + dy * fy
			if al > 0 and al < l.len and absf(-dx * fy + dy * fx) < l.w:
				hurt(1, px, py)
	EL = EL.filter(func(l): return l.t > -0.25)
	for r in ER:
		r.r += r.v * dt
		var d := Vector2(px - r.x, py - r.y).length()
		if absf(d - r.r) < 3.5:
			hurt(1, px, py)
	ER = ER.filter(func(r): return r.r < r.max)

# ======================================================================
# 伤害
# ======================================================================
var _kdepth := 0

## 打一只生物。proc = 能不能触发火/霜/连这些附加效果
func dmg_e(e: SV, d: float, sx: float, sy: float, kb := 40.0, proc := true, crit_ok := true, force_crit := false) -> void:
	if e.dead:
		return
	if e.t == "wisp" and e.open < 0.25:
		return
	if e.t == "mimic" and e.st == "idle":
		e.st = "bite"
	var crit := false
	if crit_ok and (force_crit or randf() < 0.1 * w("暴") + 0.06 * rl("redpen")):
		d *= 4.0 if cmb("锋芒") else 2.5
		crit = true
	if e.frz > 0 or frz_all > 0:
		d *= 1.6 if w("霜") > 0 else 1.25
	if (e.elite or e.boss) and rl("sand") > 0:
		d *= 1.0 + 0.2 * rl("sand")
	if e.t == "mite":
		# 镜螨的正面打不动
		var fx := cos(e.ang)
		var fy := sin(e.ang)
		var vx := sx - e.x
		var vy := sy - e.y
		var vl := maxf(0.01, sqrt(vx * vx + vy * vy))
		if (vx * fx + vy * fy) / vl > 0.35:
			d *= 0.35
			if randf() < 0.3:
				part(e.x + fx * 4, e.y + fy * 4, fx * 30, fy * 30, 0.3, MIRROR, 6, true)
	elif e.t == "tick" and e.st != "tired" and e.frz <= 0:
		# 发条甲虫：钥匙转着的时候壳很硬
		d *= 0.3
	elif e.t == "mirror" and e.orR > 0 and proc and randf() < 0.12:
		# 镜中人：把字弹弹回来
		var a := atan2(P.y - e.y, P.x - e.x)
		add_sb(e.x, e.y, cos(a) * 95, sin(a) * 95, 3.0, MIRROR)
	DS[dsrc] = float(DS.get(dsrc, 0.0)) + minf(d, e.hp)
	e.hp -= d
	if crit_ok:
		e.flash = 0.08
	if kb > 0 and not e.elite:
		var kx := e.x - sx
		var ky := e.y - sy
		var kl := maxf(0.01, sqrt(kx * kx + ky * ky))
		e.kx += kx / kl * kb
		e.ky += ky / kl * kb
	if NUMS.size() < [36, 18, 10][qual] and crit_ok and d >= 1.0 and (qual < 2 or crit):
		NUMS.append({"x": e.x + (randf() - 0.5) * 4, "y": e.y - e.r - 2, "v": roundi(d), "t": 0.6, "c": crit})
	if proc:
		if w("火") > 0:
			e.burn_t = 3.0
			e.burn_dps = maxf(e.burn_dps, 4.0 * w("火") * dmg_k())
		if w("霜") > 0:
			e.slow = 0.6 + 0.5 * w("霜")
		if w("连") > 0 and randf() < 0.12 * w("连"):
			var ks := dsrc
			dsrc = "连"
			chain(e, d * 0.6, 5 if cmb("连环") else 2)
			dsrc = ks
	if e.hp <= 0:
		kill_e(e)
	else:
		snd("hit", 0.9 + randf() * 0.3, 0.06)

func chain(src: SV, d: float, n: int) -> void:
	var cur := src
	var hit := [src]
	for i in n:
		var best_e: SV = null
		var bd := 50.0 * 50.0
		for e: SV in near_list(cur.x, cur.y) + near_list(cur.x + 30, cur.y) + near_list(cur.x - 30, cur.y):
			if e.dead or hit.has(e):
				continue
			var dd: float = (e.x - cur.x) * (e.x - cur.x) + (e.y - cur.y) * (e.y - cur.y)
			if dd < bd:
				bd = dd
				best_e = e
		if best_e == null:
			break
		if ZAPS.size() < 40:
			ZAPS.append({"ax": cur.x, "ay": cur.y, "bx": best_e.x, "by": best_e.y, "t": 0.18})
		hit.append(best_e)
		dmg_e(best_e, d, cur.x, cur.y, 20.0, false, false)
		cur = best_e

func kill_e(e: SV) -> void:
	if e.dead:
		return
	e.dead = true
	kills2 += 1
	var m: int = DEF[e.t].m if DEF.has(e.t) else PAPER
	burst(e.x, e.y, 6 if E.size() < 200 else 3, m, 5, 45, 0.45)
	snd("kill", 0.8 + randf() * 0.5, 0.045)
	if e.xp > 0:
		drop_gem(e.x, e.y, e.xp)
	if randf() < 0.02 * (1 + rl("wax")):
		add_pick(e.x, e.y, "ember")
	if randf() < 0.002:
		add_pick(e.x, e.y, "mag")
	# 成词：火石、冰裂
	_kdepth += 1
	var ks := dsrc
	if _kdepth <= 2:
		if cmb("火石") and e.burn_t > 0:
			dsrc = "火石"
			boom(e.x, e.y, 16.0 * area_k(), 12.0 * dmg_k(), false)
			dsrc = ks
		if cmb("冰裂") and e.slow > 0 and PB.size() < 110:
			for i in 6:
				var b := shot(e.x, e.y, i * TAU / 6 + e.ph, 9.0 * dmg_k(), 0)
				b.small = true
				b.mat = ICE
				b.split = 0
				b.life = 0.3
				b.hit = [e]
	_kdepth -= 1
	if e.boss:
		kill_boss(e)
		return
	if e.elite:
		add_pick(e.x, e.y, "page")
		add_pick(e.x + 8, e.y, "mag")
		for i in 6:
			drop_gem(e.x + (randf() - 0.5) * 16, e.y + (randf() - 0.5) * 16, 5)
		shk = 6
		Sfx.play("buy")
	match e.t:
		"clam":
			add_pick(e.x, e.y, "ember")
			if randf() < 0.5:
				add_pick(e.x, e.y, "kiln")
			Sfx.play("ember")
		"comet":
			for i in 14:
				drop_gem(e.x + (randf() - 0.5) * 20, e.y + (randf() - 0.5) * 20, 6)
			add_pick(e.x, e.y, "ember")
			add_pick(e.x, e.y, "kiln")
			toast("抓到彗尾鱼！", C_TEAL, 3)
		"blot":
			for i in 2:
				if E.size() < CAP + 20:
					var c := add_e("blotlet", e.x + (i - 0.5) * 8, e.y)
					c.kx = (i - 0.5) * 120
		"ashghost":
			for i in 6:
				add_sb(e.x, e.y, cos(i * TAU / 6) * 50, sin(i * TAU / 6) * 50, 1.6, EMBER)
		"cinder":
			if randf() < 0.12:
				add_pick(e.x, e.y, "ember")
		"twin":
			var mt := e.mate as SV
			if mt != null and not mt.dead:
				mt.flash = 0.3

func kill_boss(e: SV) -> void:
	bosses.erase(e)
	boss_kills += 1
	shk = 14
	slowmo = 1.4
	Sfx.play("roar", 0.8)
	burst(e.x, e.y, 60, DEF[e.t].m, 6, 120, 1.4)
	for s in e.seg:
		burst(s.x, s.y, 6, SERP, 5, 60, 0.8)
	EB.clear()
	EA.clear()
	EL.clear()
	ER.clear()
	if e.t == "silence":
		# 最后一个：屏幕上剩下的都散掉
		for o in E:
			if not o.dead and o != e:
				o.dead = true
				burst(o.x, o.y, 3, DEF[o.t].m if DEF.has(o.t) else PAPER, 5, 40, 0.5)
		set_banner("宇宙安静了下来", "", C_GOLD)
		get_tree().create_timer(2.4).timeout.connect(func(): if S == "sv": end_run(true))
		return
	set_banner("%s安静了" % DEF[e.t].name, "炉灯工坊马上开门", C_GOLD)
	shop_t = 1.2
	# 首领的赏金
	ink += (30 + 10 * boss_kills) * (2 if pact == "greed" else 1)
	add_pick(e.x, e.y, "page")
	add_pick(e.x + 10, e.y, "kiln")
	add_pick(e.x - 10, e.y, "ember")
	add_pick(e.x, e.y + 10, "ember")
	for i in 16:
		drop_gem(e.x + (randf() - 0.5) * 40, e.y + (randf() - 0.5) * 40, 8)

func drop_gem(x: float, y: float, v: int) -> void:
	if PK.size() > 240:
		# 太多了就并进一颗离得远的
		var p: Pick = PK[randi() % PK.size()]
		if p.k == "dust":
			p.v += v
			return
	add_pick(x, y, "dust", 0, 0, v)

# ======================================================================
# 笔
# ======================================================================
func upd_pens(dt: float) -> void:
	for i in 6:
		var l := plv(i)
		if l <= 0:
			continue
		pen_cd[i] -= dt
		if pen_cd[i] > 0:
			continue
		dsrc = SPENS[i].name
		match i:
			0: pen_cd[i] = fire_brush(l)
			1: pen_cd[i] = fire_broom(l)
			2: pen_cd[i] = fire_knife(l)
			3: pen_cd[i] = fire_inkb(l)
			4: pen_cd[i] = fire_line(l)
			5: pen_cd[i] = fire_seal(l)
	# 烛台：身边一圈光
	if plv(6) > 0:
		aura_t -= dt
		if aura_t <= 0:
			aura_t = 0.45
			dsrc = SPENS[6].name
			var R := aura_r()
			var dmg := (5.0 + 1.5 * plv(6)) * (1.5 if plv(6) >= 3 else 1.0) * (1.5 if plv(6) >= 5 else 1.0) * dmg_k()
			if ev(6, 1):
				dmg *= 2.0
			for e in E:
				if e.dead:
					continue
				var dx := e.x - P.x
				var dy := e.y - P.y
				if dx * dx + dy * dy < (R + e.r) * (R + e.r):
					dmg_e(e, dmg, P.x, P.y, 0.0, true, false)
					if ev(6, 1):
						e.slow = 0.6
						if not e.boss:
							e.kx -= dx * 0.6
							e.ky -= dy * 0.6
		if ev(6, 0):
			lamp_heal += dt
			if lamp_heal > 30.0:
				lamp_heal = 0.0
				heal(1)
	# 回环：绕身刻刀
	if ev(2, 0):
		blade_a += dt * 4.2
		var R := 26.0 * area_k()
		for k in 3:
			var a := blade_a + k * TAU / 3
			var bx := P.x + cos(a) * R
			var by := P.y + sin(a) * R
			for e: SV in near_list(bx, by):
				if e.dead or e.blade_cd > 0:
					continue
				if absf(e.x - bx) < e.r + 5 and absf(e.y - by) < e.r + 5:
					e.blade_cd = 0.35
					dsrc = SPENS[2].name
					dmg_e(e, 22.0 * dmg_k(), P.x, P.y, 60.0)
	# 地上的火（燎原、朱砂、炉息、风火）
	for f in FIRE:
		for e: SV in near_list(f.x, f.y):
			if e.dead or e.fire_cd > 0:
				continue
			if (e.x - f.x) * (e.x - f.x) + (e.y - f.y) * (e.y - f.y) < (f.r + e.r) * (f.r + e.r):
				e.fire_cd = 0.4
				dsrc = "地火"
				dmg_e(e, 7.0 * dmg_k(), e.x, e.y, 0.0, false, false)
				e.burn_t = 2.0
				e.burn_dps = maxf(e.burn_dps, 6.0 * dmg_k())
	# 墨涡：把周围的吸进来绞
	for v in VORT2:
		v.t -= dt
		v.tick -= dt
		var hit: bool = v.tick <= 0
		if hit:
			v.tick = 0.4
		for e in E:
			if e.dead or e.boss:
				continue
			var dx: float = v.x - e.x
			var dy: float = v.y - e.y
			var d := sqrt(dx * dx + dy * dy)
			if d < v.r * 1.8 and d > 1:
				e.x += dx / d * 55.0 * dt
				e.y += dy / d * 55.0 * dt
				if hit and d < v.r:
					dsrc = "墨涡"
					dmg_e(e, 9.0 * dmg_k(), e.x, e.y, 0.0, false, false)
	VORT2 = VORT2.filter(func(v): return v.t > 0)
	# 千钧：印章的第二圈
	for s in SEALS:
		if s.wave > 0:
			s.wave -= dt
			if s.wave <= 0:
				var R: float = s.r * 1.9
				BOOMS.append({"x": s.x, "y": s.y, "r": R, "t": 0.3, "T": 0.3, "m": GOLD})
				for e in E:
					if e.dead:
						continue
					var dx: float = e.x - s.x
					var dy: float = e.y - s.y
					if dx * dx + dy * dy < R * R:
						dsrc = SPENS[5].name
						dmg_e(e, s.dmg * 0.6, s.x, s.y, 160.0)
	# 暴雨：每两秒泼一圈
	if ev(0, 0):
		rain_t -= dt
		if rain_t <= 0:
			rain_t = 2.0
			dsrc = SPENS[0].name
			for k in 20:
				shot(P.x, P.y, k / 20.0 * TAU, 11.0 * dmg_k(), 0)
	# 穿针：十字墨线扫一圈
	if ev(4, 0):
		sweep_t -= dt
		if sweep_t <= 0:
			sweep_t = 3.2
			for k in 4:
				BEAMS.append({"x": P.x, "y": P.y, "a": k * PI / 2, "len": 210.0, "w": 5.0 * area_k(), "t": 1.3, "max": 1.3, "sweep": true, "dmg": 26.0 * dmg_k(), "hit": {}, "zap": 0})
			Sfx.play("roar", 2.2)

func aura_r() -> float:
	var l := plv(6)
	return (24.0 + (6 if l >= 2 else 0) + (6 if l >= 4 else 0)) * area_k() * (1.35 if ev(6, 0) else 1.0)

func target_angle(maxd := 190.0) -> float:
	var e := nearest(P.x, P.y, maxd)
	if e:
		return atan2(e.y - P.y, e.x - P.x)
	return atan2(P.ay, P.ax)

## kind：0 毛笔字弹，1 排刷，2 万页的书页
func shot(x: float, y: float, a: float, dmg: float, kind: int) -> Bullet:
	var b := Bullet.new()
	var spk := 1.0 + 0.15 * w("针")
	b.x = x
	b.y = y
	b.sp = (230.0 if kind == 0 else (200.0 if kind == 1 else 150.0)) * spk
	b.vx = cos(a) * b.sp
	b.vy = sin(a) * b.sp
	b.life = (0.85 if kind == 0 else (0.28 + 0.06 * mini(plv(1), 5) if kind == 1 else 2.6)) * spk
	b.max_life = b.life
	b.dmg = 0
	b.crit = dmg
	b.pierce = w("穿") + (1 if kind >= 1 else 0) + rl("clip")
	b.home = 0.0 if kind == 1 else (3.0 * w("寻") if kind == 0 else 6.0)
	b.split = w("裂") if kind == 0 else 0
	b.small = kind == 1
	b.big = kind == 2
	b.burn = 1.0 if kind == 1 and ev(1, 0) else 0.0
	b.frost = 1.0 if kind == 1 and ev(1, 1) else 0.0
	b.bounce = 3 if kind == 0 and ev(0, 1) else 0
	b.mat = EMBER if b.burn > 0 else (ICE if b.frost > 0 else (CLAY if kind == 0 else (GOLD if kind == 1 else PAPER)))
	b.hit = []
	b.src = dsrc
	# 场上字弹有上限：再多也看不清，还拖帧率
	if PB.size() < [170, 140, 110][qual]:
		PB.append(b)
	return b

func fire_brush(l: int) -> float:
	var n := 1 + (1 if l >= 2 else 0) + (1 if l >= 4 else 0) + w("雨")
	var dmg := 9.0 * (1.4 if l >= 3 else 1.0) * (1.4 if l >= 5 else 1.0) * dmg_k()
	# 每发找不同的目标
	var tg: Array = []
	for e in E:
		if not can_tgt(e):
			continue
		var dd := (e.x - P.x) * (e.x - P.x) + (e.y - P.y) * (e.y - P.y)
		if dd < 200 * 200:
			tg.append([dd, e])
	tg.sort_custom(func(a, b): return a[0] < b[0])
	for k in n:
		var a := atan2(P.ay, P.ax) + (k - n / 2.0) * 0.15
		if not tg.is_empty():
			var e: SV = tg[k % tg.size()][1]
			a = atan2(e.y - P.y, e.x - P.x) + (randf() - 0.5) * 0.06
		shot(P.x, P.y, a, dmg, 0)
	snd("shoot", 1.0 + randf() * 0.2, 0.08)
	var cd := (0.42 if l < 5 else 0.34) * cd_k()
	if ev(0, 0):
		cd = 0.16 * cd_k()
	return cd

func fire_broom(l: int) -> float:
	var n := 5 + (2 if l >= 2 else 0) + (2 if l >= 4 else 0) + w("雨") * 2
	var dmg := 6.0 * (1.4 if l >= 3 else 1.0) * (1.4 if l >= 5 else 1.0) * dmg_k()
	var a0 := target_angle(120)
	var wide := 1.6 if ev(1, 1) else 1.1
	for k in n:
		var a := a0 + (float(k) / maxf(1, n - 1) - 0.5) * wide + (randf() - 0.5) * 0.08
		var b := shot(P.x, P.y, a, dmg, 1)
		b.sp *= 0.85 + randf() * 0.3
		b.vx = cos(a) * b.sp
		b.vy = sin(a) * b.sp
	snd("dash", 1.6, 0.1)
	return (1.15 if l < 5 else 0.85) * cd_k()

func fire_knife(l: int) -> float:
	var R := (40.0 + (8 if l >= 2 else 0) + (8 if l >= 5 else 0)) * area_k()
	var dmg := 20.0 * (1.4 if l >= 4 else 1.0) * dmg_k()
	var a0 := target_angle(R + 40)
	var dirs := [a0]
	if l >= 3:
		dirs.append(a0 + PI)
	if ev(2, 0):
		dirs = [a0, a0 + PI * 2 / 3, a0 + PI * 4 / 3]
	for a in dirs:
		slash_at(a, R, dmg, 1.9)
	snd("hit", 0.6, 0.1)
	return (0.8 if l < 5 else 0.65) * cd_k()

func slash_at(a: float, R: float, dmg: float, arc: float) -> void:
	SL.append({"x": P.x, "y": P.y, "a": a, "arc": arc, "r": R, "t": 0.16})
	var exe := ev(2, 1)
	for e in E:
		if e.dead:
			continue
		var dx := e.x - P.x
		var dy := e.y - P.y
		var d := sqrt(dx * dx + dy * dy)
		if d > R + e.r:
			continue
		var da := absf(angle_difference(a, atan2(dy, dx)))
		if da < arc * 0.5 or d < 8:
			if exe and not e.elite and e.hp < e.mhp * 0.3:
				# 斩首
				NUMS.append({"x": e.x, "y": e.y - e.r - 2, "v": roundi(e.hp), "t": 0.6, "c": true})
				kill_e(e)
			else:
				dmg_e(e, dmg, P.x, P.y, 90.0, true, true, exe and e.hp >= e.mhp)
	# 刻刀能劈开敌人的子弹
	var keep: Array[EBullet] = []
	for b in EB:
		var dx := b.x - P.x
		var dy := b.y - P.y
		if dx * dx + dy * dy < R * R and absf(angle_difference(a, atan2(dy, dx))) < arc * 0.5:
			burst(b.x, b.y, 3, PAPER, 6, 30, 0.3)
			continue
		keep.append(b)
	EB = keep

func fire_inkb(l: int) -> float:
	var n := 1 + (1 if l >= 2 else 0) + (1 if l >= 4 else 0) + w("雨")
	var r := (24.0 + (8 if l >= 3 else 0)) * area_k()
	var dmg := 18.0 * (1.5 if l >= 5 else 1.0) * dmg_k()
	for k in n:
		var t := crowd_target(170)
		t += Vector2((randf() - 0.5) * 30, (randf() - 0.5) * 30) * (1.0 if k > 0 else 0.3)
		var fl := 0.45 + Vector2(P.x, P.y).distance_to(t) / 400.0
		INKB.append({"x": P.x, "y": P.y, "sx": P.x, "sy": P.y, "tx": t.x, "ty": t.y, "t": 0.0, "T": fl, "r": r, "dmg": dmg, "split": ev(3, 0), "vort": ev(3, 1) and k == 0})
	return 1.6 * cd_k()

func upd_inkb(dt: float) -> void:
	var keep := []
	dsrc = SPENS[3].name
	for b in INKB:
		b.t += dt
		var k: float = minf(1.0, b.t / b.T)
		b.x = lerpf(b.sx, b.tx, k)
		b.y = lerpf(b.sy, b.ty, k) - sin(k * PI) * 26.0
		if k >= 1.0:
			boom(b.tx, b.ty, b.r, b.dmg)
			if b.vort and VORT2.size() < 6:
				VORT2.append({"x": b.tx, "y": b.ty, "r": b.r * 0.9, "t": 3.0, "tick": 0.0})
			if b.split:
				for q in 4:
					var a := q * PI / 2 + PI / 4
					keep.append({"x": b.tx, "y": b.ty, "sx": b.tx, "sy": b.ty, "tx": b.tx + cos(a) * b.r * 1.3, "ty": b.ty + sin(a) * b.r * 1.3, "t": 0.0, "T": 0.3, "r": b.r * 0.6, "dmg": b.dmg * 0.6, "split": false, "vort": false})
			continue
		keep.append(b)
	INKB = keep

func boom(x: float, y: float, r: float, dmg: float, proc := true) -> void:
	if BOOMS.size() < 50:
		BOOMS.append({"x": x, "y": y, "r": r, "t": 0.3, "T": 0.3, "m": ICE})
	snd("rock", 0.6 + randf() * 0.2, 0.06)
	shk = maxf(shk, 2.5)
	if PT.size() < 600:
		for i in 8:
			var a := randf() * TAU
			part(x + cos(a) * r * 0.5, y + sin(a) * r * 0.5, cos(a) * 40, sin(a) * 40, 0.5, GRAV, 4)
	for e: SV in in_radius(x, y, r):
		if e.dead:
			continue
		var dx := e.x - x
		var dy := e.y - y
		if dx * dx + dy * dy < (r + e.r) * (r + e.r):
			dmg_e(e, dmg, x, y, 70.0, proc, proc)

func fire_line(l: int) -> float:
	var a := target_angle(220)
	var wd := (4.0 + (2.0 if l >= 2 else 0.0)) * area_k()
	var dmg := 24.0 * (1.3 if l >= 2 else 1.0) * (1.5 if l >= 5 else 1.0) * dmg_k()
	var dirs := [a]
	if l >= 3:
		dirs.append(a + PI)
	for d in dirs:
		BEAMS.append({"x": P.x, "y": P.y, "a": d, "len": 230.0, "w": wd, "t": 0.22, "max": 0.22, "sweep": false, "dmg": dmg, "hit": {}, "zap": 10 if ev(4, 1) else 0})
	Sfx.play("ping", 0.7)
	shk = maxf(shk, 2.0)
	return (2.3 if l < 4 else 1.7) * cd_k()

func upd_beams(dt: float) -> void:
	var keep := []
	dsrc = SPENS[4].name
	for b in BEAMS:
		b.t -= dt
		if b.t <= 0:
			continue
		b.x = P.x
		b.y = P.y
		if b.sweep:
			b.a += dt * TAU / 1.3 * 0.5
		var fx := cos(b.a)
		var fy := sin(b.a)
		var hit: Dictionary = b.hit
		for e in E:
			if e.dead:
				continue
			var dx: float = e.x - b.x
			var dy: float = e.y - b.y
			var along := dx * fx + dy * fy
			if along < 0 or along > b.len:
				continue
			var side := absf(-dx * fy + dy * fx)
			if side > b.w + e.r:
				continue
			var last: float = hit.get(e, -9.0)
			if T - last < (0.3 if b.sweep else 99.0):
				continue
			hit[e] = T
			dmg_e(e, b.dmg, b.x, b.y, 50.0)
			if b.zap > 0 and not e.dead:
				b.zap -= 1
				chain(e, b.dmg * 0.5, 3)
		keep.append(b)
	BEAMS = keep

func fire_seal(l: int) -> float:
	var n := 1 + (1 if l >= 3 else 0) + (1 if l >= 5 else 0) + w("雨")
	var r := (18.0 + (6 if l >= 2 else 0)) * area_k()
	var dmg := 24.0 * (1.4 if l >= 4 else 1.0) * dmg_k()
	for k in n:
		var t := crowd_target(130)
		if k > 0:
			t += Vector2((randf() - 0.5) * 60, (randf() - 0.5) * 60)
		SEALS.append({"x": t.x, "y": t.y, "r": r, "t": 0.5, "wave": 0.3 if ev(5, 0) else 0.0, "dmg": dmg})
		for e in E:
			if e.dead:
				continue
			if absf(e.x - t.x) < r + e.r and absf(e.y - t.y) < r + e.r:
				dmg_e(e, dmg, t.x, t.y, 0.0)
				if not e.boss:
					e.frz = maxf(e.frz, 0.6)
		if ev(5, 1):
			add_fire(t.x, t.y, r, 4.0)
	snd("rock", 0.45, 0.1)
	shk = maxf(shk, 3.0)
	return (2.0 if l < 5 else 1.5) * cd_k()

# ---------- 字弹 ----------
func retarget(b: Bullet) -> bool:
	var e := near_e(b.x, b.y, b.hit)
	if e == null:
		return false
	var a := atan2(e.y - b.y, e.x - b.x)
	b.vx = cos(a) * b.sp
	b.vy = sin(a) * b.sp
	b.life = maxf(b.life, 0.45)
	return true

func upd_shots(dt: float) -> void:
	var keep: Array[Bullet] = []
	for b in PB:
		b.life -= dt
		if b.life <= 0:
			if b.burn > 0:
				add_fire(b.x, b.y, 9.0 * area_k(), 2.6)
			continue
		# 拐弯的字弹三帧才重新找一次目标，省得每帧都查格子
		if b.home > 0 and (int(gt2 * 60.0) + int(b.max_life * 997.0) + int(b.x)) % 3 == 0:
			var e := near_e(b.x, b.y, b.hit)
			if e:
				var a := atan2(b.vy, b.vx)
				a = rotate_toward(a, atan2(e.y - b.y, e.x - b.x), b.home * dt * 3.0)
				b.vx = cos(a) * b.sp
				b.vy = sin(a) * b.sp
		b.x += b.vx * dt
		b.y += b.vy * dt
		var dead := false
		var stop := false
		var bcx := floori(b.x / GCELL)
		var bcy := floori(b.y / GCELL)
		for cj in range(-1, 2):
			if stop:
				break
			for ci in range(-1, 2):
				if stop:
					break
				var cell = G.get((bcx + ci + 4096) * 8192 + (bcy + cj + 4096))
				if cell == null:
					continue
				for e: SV in cell:
					if e.dead or b.hit.has(e):
						continue
					var rr := e.r + (2.5 if not b.small else 2.0)
					if absf(e.x - b.x) > rr or absf(e.y - b.y) > rr:
						continue
					b.hit.append(e)
					dsrc = b.src
					dmg_e(e, b.crit, b.x, b.y, 35.0)
					if b.frost > 0 and not e.boss:
						e.frz = maxf(e.frz, 1.5)
					if b.split > 0 and not b.small and randf() < 0.2 * b.split and PB.size() < 130:
						var a := atan2(b.vy, b.vx)
						for s in [-0.6, 0.6]:
							var nb := shot(b.x, b.y, a + s, b.crit * 0.5, 0)
							nb.small = true
							nb.split = 0
							nb.bounce = 0
							nb.life = 0.35
							nb.hit = [e]
					if b.burn > 0:
						add_fire(b.x, b.y, 9.0 * area_k(), 2.6)
						b.burn = 0.0
					if b.bounce > 0:
						b.bounce -= 1
						if not retarget(b):
							b.bounce = 0
						stop = true
						break
					elif b.pierce > 0:
						b.pierce -= 1
						if cmb("追魂"):
							retarget(b)
							stop = true
							break
					else:
						dead = true
						stop = true
						break
		if not dead:
			keep.append(b)
	PB = keep
	upd_beams(dt)

# ======================================================================
# 技：自动放
# ======================================================================
func upd_skills2(dt: float) -> void:
	for id in sk:
		var l := skl(id)
		var cd: float = float(sk_cd.get(id, 2.0)) - dt * (1.0 + 0.18 * rl("glass"))
		sk_cd[id] = cd
		if cd > 0:
			continue
		var base: float = SK[id].cd
		dsrc = SK[id].name
		match id:
			"shield":
				if shield_on:
					continue
				shield_on = true
				sk_cd[id] = 0.0
				Sfx.play("ping", 1.4)
			"nova":
				var R := (46.0 + 8.0 * l) * area_k()
				BOOMS.append({"x": P.x, "y": P.y, "r": R, "t": 0.4, "T": 0.4, "m": EMBER})
				for e in E:
					if e.dead:
						continue
					var dx := e.x - P.x
					var dy := e.y - P.y
					if dx * dx + dy * dy < R * R:
						dmg_e(e, 28.0 * l * dmg_k(), P.x, P.y, 110.0)
						e.burn_t = 3.0
						e.burn_dps = maxf(e.burn_dps, 5.0 * l * dmg_k())
				if w("火") > 0:
					for k in 8:
						add_fire(P.x + cos(k * TAU / 8) * R * 0.7, P.y + sin(k * TAU / 8) * R * 0.7, 9.0, 3.0)
				Sfx.play("roar", 1.6)
				shk = maxf(shk, 4.0)
				sk_cd[id] = base * cd_k()
			"freeze":
				frz_all = 1.5 + 0.5 * l
				Sfx.play("cold")
				set_banner("定格", "", C_TEAL)
				banner_t = 1.2
				sk_cd[id] = base * cd_k()
			"storm":
				var n := 5 + 3 * l
				if w("雨") > 0:
					n = n * 3 / 2
				for k in n:
					var b := shot(P.x, P.y, k * TAU / n, 16.0 * dmg_k(), 2)
					b.x += cos(k * TAU / n) * 8
					b.y += sin(k * TAU / n) * 8
				Sfx.play("page", 1.5)
				sk_cd[id] = base * cd_k()

# ======================================================================
# 掉落：页尘（经验）、余烬（回心）、炉心（清屏）、散页（宝箱）
# ======================================================================
func mag_r() -> float:
	return 26.0 * (1.0 + 0.5 * w("重")) * (1.0 + 0.2 * mu("pull")) * (1.0 + 0.3 * rl("blotter"))

func upd_gems(dt: float) -> void:
	var keep: Array[Pick] = []
	var mr := mag_r()
	var damp := exp(-4 * dt)
	for p in PK:
		p.age += dt
		var dx := P.x - p.x
		var dy := P.y - p.y
		if not p.gold and p.vx == 0.0 and p.vy == 0.0 and (absf(dx) > mr or absf(dy) > mr):
			# 躺在地上没动的页尘：不用算
			if (absf(dx) > 600 or absf(dy) > 600) and p.k == "dust":
				continue
			keep.append(p)
			continue
		var d := sqrt(dx * dx + dy * dy)
		var pull := d < mr or p.gold
		if not pull:
			p.vx *= damp
			p.vy *= damp
			if absf(p.vx) < 1.0 and absf(p.vy) < 1.0:
				p.vx = 0.0
				p.vy = 0.0
		else:
			var sp := 120.0 + p.age * 40.0 if not p.gold else 260.0
			p.vx += (dx / maxf(d, 0.1) * sp - p.vx) * minf(1.0, dt * 8)
			p.vy += (dy / maxf(d, 0.1) * sp - p.vy) * minf(1.0, dt * 8)
		p.x += p.vx * dt
		p.y += p.vy * dt
		if d < 5:
			collect(p)
			continue
		if d > 600 and p.k == "dust":
			continue
		keep.append(p)
	PK = keep

var xp_frac := 0.0

func collect(p: Pick) -> void:
	match p.k:
		"dust":
			xp_frac += p.v * (1.0 + 0.08 * mu("wit") + 0.1 * rl("mark")) * (1.35 if pact == "swarm" else 1.0)
			# 墨滴按“升一级的页尘值多少墨”来折算，后期怪海再大，每间工坊的预算也差不多
			ink_frac += float(p.v) / xp_need() * INK_PER_LV * (1.0 + 0.25 * rl("sac")) * (2.0 if pact == "greed" else 1.0)
			ink += int(ink_frac)
			ink_frac -= int(ink_frac)
			xp += int(xp_frac)
			xp_frac -= int(xp_frac)
			chime_i = (chime_i + 1) % 8
			snd("dust%d" % chime_i, 1.0, 0.035)
		"ember":
			if P.hp < P.maxhp:
				toast("余烬暖了一下陶心 +1", C_CLAY, 1.5)
			heal(1)
			Sfx.play("ember")
		"kiln":
			kiln_blast()
		"page":
			open_page()
		"mag":
			for q in PK:
				if q.k == "dust":
					q.gold = true
			toast("吸页石：地上的页尘全飞过来", C_TEAL, 2)
			Sfx.play("beacon")

## 炉心：一圈热浪，屏幕上的小东西全散掉，页尘都吸过来
func kiln_blast() -> void:
	Sfx.play("roar", 1.2)
	shk = 10
	BOOMS.append({"x": P.x, "y": P.y, "r": Vector2(W, H).length() * 0.5, "t": 0.6, "T": 0.6, "m": GOLD})
	for e in E:
		if e.dead:
			continue
		if absf(e.x - P.x) < W * 0.6 and absf(e.y - P.y) < H * 0.6:
			if e.elite or e.boss:
				dsrc = "炉心"
				dmg_e(e, 80.0 * dmg_k(), P.x, P.y, 0.0, false, false)
			elif e.t != "clam" and e.t != "comet":
				kill_e(e)
	EB.clear()
	for p in PK:
		if p.k == "dust":
			p.gold = true
	set_banner("炉心", "一圈热浪扫过去，页尘全飞过来", C_GOLD)

## 散页（精英和首领掉的）：能进化就进化，否则随机给几次升级
func open_page() -> void:
	Sfx.play("page")
	shk = 4
	var er := evo_ready()
	if not er.is_empty():
		do_evo(er[0][0], er[0][1])
		return
	var n := 1 + (1 if randf() < 0.5 else 0) + (1 if randf() < 0.2 else 0)
	var got := []
	for i in n:
		var c := owned_upgrades()
		if c.is_empty():
			break
		var o: Dictionary = c[randi() % c.size()]
		apply_opt(o)
		got.append(opt_title(o, true))
	if got.is_empty():
		temper += 1
		heal(99)
		set_banner("散页", "淬火：伤害 +5%，陶心回满", C_GOLD)
	else:
		set_banner("散页", "、".join(got), C_GOLD)

func owned_upgrades() -> Array:
	var c := []
	for i in pens:
		if plv(i) < 5:
			c.append({"k": "pen", "i": i})
	for s in words:
		if w(s) < SW[s].max:
			c.append({"k": "word", "c": s})
	for id in sk:
		if skl(id) < 3:
			c.append({"k": "skill", "id": id})
	return c

# ======================================================================
# 升级三选一
# ======================================================================
## 现在能做的成词进化：[[笔序号, 甲乙], …]
func evo_ready() -> Array:
	var out := []
	for i in pens:
		if plv(i) == 5:
			for k in 2:
				if not ev(i, k) and w(SPENS[i].evo[k]) > 0:
					out.append([i, k])
	return out

## 这个字拿了以后能跟什么联动（给卡片上写提示用）
func word_links(c: String) -> Array:
	var out := []
	for i in pens:
		for k in 2:
			if SPENS[i].evo[k] == c and not ev(i, k):
				out.append("%s满级后成词「%s」" % [SPENS[i].name, SPENS[i].ename[k]])
	for q in WCOMBO:
		if not combos.has(q.name):
			if q.a == c and w(q.b) > 0:
				out.append("与「%s」成词「%s」：%s" % [q.b, q.name, q.d])
			elif q.b == c and w(q.a) > 0:
				out.append("与「%s」成词「%s」：%s" % [q.a, q.name, q.d])
	for id in sk:
		if SK[id].syn == c and w(c) == 0:
			out.append("%s：%s" % [SK[id].name, SK[id].sd])
	return out

func gen_opts() -> Array:
	var out := []
	for q in evo_ready():
		if out.size() < 2:
			out.append({"k": "evo", "i": q[0], "e": q[1]})
	var c := []   # [选项, 权重]
	for i in SPENS.size():
		var l := plv(i)
		if BAN.has("pen%d" % i):
			continue
		if l > 0 and l < 5:
			c.append([{"k": "pen", "i": i}, 10.0])
		elif l == 0 and pens.size() < max_pens():
			c.append([{"k": "pen", "i": i}, 7.0])
	for s in SW:
		var l := w(s)
		if BAN.has("word" + s):
			continue
		if l > 0 and l < SW[s].max:
			c.append([{"k": "word", "c": s}, 8.0])
		elif l == 0 and words.size() < max_words():
			# 能跟手上的东西联动的字更容易出现
			c.append([{"k": "word", "c": s}, 5.0 + minf(6.0, 3.0 * word_links(s).size())])
	for id in SK:
		var l := skl(id)
		if BAN.has("skill" + id):
			continue
		if l > 0 and l < 3:
			c.append([{"k": "skill", "id": id}, 7.0])
		elif l == 0 and sk.size() < MAX_SK:
			c.append([{"k": "skill", "id": id}, 5.0])
	var want := 3 + rl("clover") - (1 if pact == "dealer" else 0)
	while out.size() < want and not c.is_empty():
		var tot := 0.0
		for q in c:
			tot += q[1]
		var r := randf() * tot
		for j in c.size():
			r -= c[j][1]
			if r <= 0:
				out.append(c[j][0])
				c.remove_at(j)
				break
	# 都练满了：用能一直叠的强化补足，保证每次升级都有得选
	if out.size() < want:
		var fill := [{"k": "temper"}]
		if P.hp < P.maxhp:
			fill.append({"k": "heal"})
		var ids := BOON.keys()
		ids.shuffle()
		for id in ids:
			if bn(id) < int(BOON[id].get("max", 999)):
				fill.append({"k": "boon", "id": id})
		# 淬火总在；其余随机
		var first = fill.pop_front()
		fill.shuffle()
		fill.push_front(first)
		for f in fill:
			if out.size() < want:
				out.append(f)
	return out

func open_lvl() -> void:
	opts = gen_opts()
	opt_sel = 0
	S = "lvl"
	Sfx.play("buy")

func opt_title(o: Dictionary, short := false) -> String:
	match o.k:
		"pen":
			var l := plv(o.i)
			if short:
				return "%s Lv%d" % [SPENS[o.i].name, l]
			return "%s%s" % [SPENS[o.i].name, " · 新笔" if l == 0 else " Lv%d→%d" % [l, l + 1]]
		"word":
			if short:
				return "「%s」Lv%d" % [o.c, w(o.c)]
			return "「%s」" % o.c
		"skill":
			if short:
				return "%s Lv%d" % [SK[o.id].name, skl(o.id)]
			return SK[o.id].name
		"evo":
			return "成词「%s」" % SPENS[o.i].ename[o.e]
		"heal":
			return "余烬"
		"temper":
			return "淬火"
		"boon":
			return BOON[o.id].n
	return ""

func opt_desc(o: Dictionary) -> String:
	match o.k:
		"pen":
			var l := plv(o.i)
			var s: String = SPENS[o.i].lv[l]
			if l == 4 or l == 0:
				s += "\n满级后配「%s」成「%s」，配「%s」成「%s」" % [SPENS[o.i].evo[0], SPENS[o.i].ename[0], SPENS[o.i].evo[1], SPENS[o.i].ename[1]]
			return s
		"word":
			var s: String = SW[o.c].d
			if w(o.c) == 0:
				for ln in word_links(o.c):
					s += "\n" + ln
			return s
		"skill":
			var s: String = SK[o.id].d
			if skl(o.id) > 0:
				s = "%s更强、更久" % SK[o.id].name
			s += "\n有「%s」时：%s" % [SK[o.id].syn, SK[o.id].sd]
			return s
		"evo":
			return "%s +「%s」\n%s" % [SPENS[o.i].name, SPENS[o.i].evo[o.e], SPENS[o.i].edesc[o.e]]
		"heal":
			return "回满陶心"
		"temper":
			return "所有伤害 +5%（可以一直拿）"
		"boon":
			return BOON[o.id].d
	return ""

func apply_opt(o: Dictionary) -> void:
	match o.k:
		"pen":
			pens[o.i] = plv(o.i) + 1
		"word":
			words[o.c] = w(o.c) + 1
			if o.c == "心":
				P.maxhp += 2
				P.hp = P.maxhp
			check_combos()
		"skill":
			sk[o.id] = skl(o.id) + 1
			if not sk_cd.has(o.id):
				sk_cd[o.id] = 1.0
		"evo":
			do_evo(o.i, o.e)
		"heal":
			P.hp = P.maxhp
		"temper":
			temper += 1
		"boon":
			boon[o.id] = bn(o.id) + 1
			match o.id:
				"thick":
					P.maxhp += 1
					P.hp = mini(P.maxhp, P.hp + 1)
				"purse":
					ink += 30

func do_evo(i: int, k: int) -> void:
	evo["%d_%d" % [i, k]] = true
	Sfx.play("page")
	shk = 8
	slowmo = 0.6
	burst(P.x, P.y, 40, GOLD, 6, 100, 1.0)
	set_banner("成词「%s」" % SPENS[i].ename[k], SPENS[i].edesc[k], C_GOLD)

func card_rect(i: int) -> Rect2:
	var n := opts.size()
	var cw := 94.0 if n <= 3 else 73.0
	var gap := 8.0 if n <= 3 else 5.0
	var x0 := 160.0 - (n * cw + (n - 1) * gap) / 2.0
	return Rect2(x0 + i * (cw + gap), 40, cw, 112)

func pause_btn(i: int) -> Rect2:
	return Rect2(88 + i * 76, 146, 68, 17)

func lvl_btn(i: int) -> Rect2:
	return Rect2(70 + i * 62, 156, 56, 13)

func reroll_rect() -> Rect2:
	return lvl_btn(0)

## 封存用的名字：只有笔、字、技能封存
func opt_key(o: Dictionary) -> String:
	match o.k:
		"pen": return "pen%d" % o.i
		"word": return "word" + str(o.c)
		"skill": return "skill" + str(o.id)
	return ""

func lvl_done() -> void:
	lv_q -= 1
	ban_mode = false
	if lv_q > 0:
		opts = gen_opts()
		opt_sel = 0
	else:
		S = "sv"
		P.inv = maxf(P.inv, 0.5)

func upd_lvl_panel() -> void:
	var n := opts.size()
	var pick := -1
	for i in n:
		if pressed(KEY_1 + i) or pressed(KEY_KP_1 + i):
			pick = i
	if pressed(KEY_A) or pressed(KEY_LEFT):
		opt_sel = (opt_sel + n - 1) % n
	if pressed(KEY_D) or pressed(KEY_RIGHT):
		opt_sel = (opt_sel + 1) % n
	if pressed(KEY_ENTER) or pressed(KEY_KP_ENTER) or pressed(KEY_SPACE):
		pick = opt_sel
	var mp := ppointer()
	for i in n:
		if card_rect(i).has_point(mp):
			if mouse_moved:
				opt_sel = i
			if click_q:
				pick = i
	if rerolls > 0 and (pressed(KEY_R) or (click_q and reroll_rect().has_point(mp))):
		rerolls -= 1
		opts = gen_opts()
		opt_sel = 0
		ban_mode = false
		Sfx.play("ping")
		return
	if banish > 0 and (pressed(KEY_X) or (click_q and lvl_btn(1).has_point(mp))):
		ban_mode = not ban_mode
		Sfx.play("ping", 0.8)
		return
	if pressed(KEY_C) or (click_q and lvl_btn(2).has_point(mp)):
		# 跳过：这次不拿卡，换一点墨滴
		ink += 15
		Sfx.play("ping", 1.3)
		lvl_done()
		return
	if ban_mode and pick >= 0:
		var key := opt_key(opts[pick])
		if key == "":
			Sfx.play("deny")
			return
		BAN[key] = true
		banish -= 1
		ban_mode = false
		Sfx.play("deny", 0.7)
		# 只换掉这一张
		var have := {}
		for o in opts:
			have[str(o)] = true
		var put := false
		for f in gen_opts():
			if not have.has(str(f)):
				opts[pick] = f
				put = true
				break
		if not put:
			opts.remove_at(pick)
			if opts.is_empty():
				opts = gen_opts()
		opt_sel = mini(opt_sel, opts.size() - 1)
		return
	if _autoplay:
		_lvl_wait += get_physics_process_delta_time()
		if _lvl_wait < 0.4:
			var full: bool = opts[0].k == "temper"
			if not _shot_at.has("lvl") or (not _shot_at.has("evo") and opts[0].k == "evo") or (full and not _shot_at.has("full")):
				var nm := "evo" if opts[0].k == "evo" else ("full" if full else "lvl")
				_shot_at[nm] = true
				_shot(nm)
			return
		_lvl_wait = 0.0
		pick = _bot_pick()
	if pick >= 0:
		apply_opt(opts[pick])
		Sfx.play("eat")
		lvl_done()

# ======================================================================
# 一闪而过的效果
# ======================================================================
func upd_fx(dt: float) -> void:
	for a in [SL, BOOMS, ZAPS, FIRE, SEALS]:
		for f in a:
			f.t -= dt
	SL = SL.filter(func(f): return f.t > 0)
	BOOMS = BOOMS.filter(func(f): return f.t > 0)
	ZAPS = ZAPS.filter(func(f): return f.t > 0)
	FIRE = FIRE.filter(func(f): return f.t > 0)
	SEALS = SEALS.filter(func(f): return f.t > 0)
	for n in NUMS:
		n.t -= dt
		n.y -= dt * 18
	NUMS = NUMS.filter(func(f): return f.t > 0)
	if PT.size() < 500:
		for f in FIRE:
			if randf() < 0.2:
				part(f.x + (randf() - 0.5) * f.r * 1.6, f.y + (randf() - 0.5) * f.r, (randf() - 0.5) * 6, -18 - randf() * 10, 0.5, EMBER if randf() < 0.7 else GOLD, 5, true)

# ======================================================================
# 画面
# ======================================================================
func shift_at(_x: float, _y: float) -> int:
	return -1 if TIDE > 0.5 else 0

func present() -> void:
	bg_mat.set_shader_parameter("chap", float(stage + 1) if S != "hub" else 1.0)
	bg_mat.set_shader_parameter("dim", 0.0 if S == "hub" else 0.5)
	fx_mat.set_shader_parameter("time", T)
	super.present()
	fx_lo.queue_redraw()
	fx_hi.queue_redraw()

# ---------- 特效：交给 fx.gdshader，一个特效只画一个四边形 ----------
var fx_mat: ShaderMaterial
var fx_lo: Node2D             # 在怪下面的一层（地上的火、预告圈、光圈）
var fx_hi: Node2D             # 在怪上面的一层（爆炸圈、光束、护盾）
var FXQ_LO: Array = []
var FXQ_HI: Array = []
var _fxq: Array = []

func _fx_setup() -> void:
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = load("res://shaders/fx.gdshader")
	fx_mat.set_shader_parameter("pal", Pal.pal_tex)
	fx_lo = PAINTER.new()
	fx_lo.fn = _draw_fx.bind(false)
	fx_lo.material = fx_mat
	add_child(fx_lo)
	move_child(fx_lo, zone_painter.get_index() + 1)
	fx_hi = PAINTER.new()
	fx_hi.fn = _draw_fx.bind(true)
	fx_hi.material = fx_mat
	add_child(fx_hi)
	move_child(fx_hi, ent_painter.get_index() + 1)

func _draw_fx(c: CanvasItem, hi: bool) -> void:
	if S == "hub":
		return
	for q in (FXQ_HI if hi else FXQ_LO):
		c.draw_primitive(q[0], q[1], q[2])

func _fx_col(m: int, l: float, ty: int, si: int, r: float, a: float) -> Color:
	return Color((m + 16 * si) / 128.0, (_lv(l) + 8 * ty) / 64.0, r / 512.0, a)

func _fx_quad(x: float, y: float, h: float, col: Color) -> void:
	if _fxq.size() > 160:
		return
	x = snap(x)
	y = snap(y)
	_fxq.append([
		PackedVector2Array([Vector2(x - h, y - h), Vector2(x + h, y - h), Vector2(x + h, y + h), Vector2(x - h, y + h)]),
		PackedColorArray([col, col, col, col]),
		PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])])

## 一条从 (x, y) 朝 a 方向、长 len、半宽 hw 的带子
func _fx_strip(x: float, y: float, a: float, len_: float, hw: float, col: Color) -> void:
	if _fxq.size() > 160:
		return
	var f := Vector2(cos(a), sin(a))
	var n := Vector2(-f.y, f.x)
	var o := Vector2(x, y)
	var w := hw + 1.0
	_fxq.append([
		PackedVector2Array([o - n * w, o + f * len_ - n * w, o + f * len_ + n * w, o + n * w]),
		PackedColorArray([col, col, col, col]),
		PackedVector2Array([Vector2(0, -w), Vector2(len_, -w), Vector2(len_, w), Vector2(0, w)])])

## 一圈点
func ring(x: float, y: float, r: float, m: int, l: float, step := 1.6, ph := 0.0) -> void:
	if r < 1.0 or not on_screen(x, y, r + 4):
		return
	_fx_quad(x, y, r + 1.0, _fx_col(m, l, 0, clampi(roundi((step - 1.0) / 0.5), 0, 7), r, fposmod(ph / TAU, 1.0)))

## 一个圆里稀疏地撒点（地上的火、墨、预告圈的底）
func disc(x: float, y: float, r: float, m: int, l: float, k: float, _seed := 0.0) -> void:
	if not on_screen(x, y, r + 4):
		return
	_fx_quad(x, y, r + 1.0, _fx_col(m, l, 1, 0, r, clampf(0.07 * k, 0.0, 1.0)))

## 光束：ours = 我方（青白芯），否则敌方（白芯）
func beam_fx(x: float, y: float, a: float, len_: float, hw: float, m: int, l: float, ours: bool) -> void:
	_fx_strip(x, y, a, len_, hw, _fx_col(m, l, 2 if ours else 4, 0, hw, 0.0))

## 预告用的流动虚线
func dash_fx(x: float, y: float, a: float, len_: float, m: int, l: float) -> void:
	_fx_strip(x, y, a, len_, 0.5, _fx_col(m, l, 3, 0, 0.0, 0.0))

func _p_dust(big: bool, tw: bool) -> void:
	var m := GOLD if big else ORE
	var s := 2 if big else 1
	for q in s:
		for r in s:
			ipx(q, r, m, 6 if tw else 5)
			ipx(q - s, r, m, 4)
			ipx(q + s, r, m, 4)
			ipx(q, r - s, m, 4)
			ipx(q, r + s, m, 3)

## 我方字弹：细长、青白色、偏暗，一眼看得出不是冲着自己来的
func _p_shot(ai: int, kind: int, mat: int) -> void:
	var a := ai * TAU / 16.0
	var ux := cos(a)
	var uy := sin(a)
	var tail := 5 if kind == 1 else 9
	var tm := ORE if mat == CLAY or mat == PAPER or mat == GOLD else mat
	for k in range(tail, 0, -1):
		ip(-ux * k * 0.5, -uy * k * 0.5, tm, 4.5 - k * 0.4)
	if kind == 2:
		for q in [[0, 0], [-1, 0], [0, -1], [-1, -1]]:
			ipx(q[0], q[1], ICE, 6, true)
		for q in [[1, 0], [1, -1], [-2, 0], [-2, -1], [0, 1], [-1, 1], [0, -2], [-1, -2]]:
			ipx(q[0], q[1], ORE, 4)
	else:
		ipx(0, 0, ICE, 6, true)
		if kind == 0:
			ip(ux * 0.5, uy * 0.5, PAPER, 6, true)

var _shot_sprs := {}

func draw_shots() -> void:
	for b in PB:
		if not on_screen(b.x, b.y, 6):
			continue
		var ai := posmod(roundi(atan2(b.vy, b.vx) / TAU * 16.0), 16)
		var kind := 2 if b.big else (1 if b.small else 0)
		var id: int = ai + kind * 16 + b.mat * 64
		var s: Spr = _shot_sprs.get(id)
		if s == null:
			s = bake("svshot|%d" % id, 5, 5, _p_shot.bind(ai, kind, b.mat))
			_shot_sprs[id] = s
		sd(s, b.x, b.y)

## 敌方子弹：统一成大一号的品红圆球，白芯、黑边，会闪
func _p_eb(fr: int) -> void:
	for j in range(-3, 4):
		for i in range(-3, 4):
			var d := i * i + j * j
			if d <= 2:
				ipx(i, j, PAPER, 6, true)
			elif d <= 6:
				ipx(i, j, SERP, 6 if fr == 0 else 5, true)
			elif d <= 10:
				ipx(i, j, WINE if fr == 0 else SERP, 4, true)
			elif d <= 13:
				ipx(i, j, SPACE, 0, true)

func draw_eb() -> void:
	if EB.is_empty():
		return
	var e0 := bake("sveb|0", 2, 2, _p_eb.bind(0))
	var e1 := bake("sveb|1", 2, 2, _p_eb.bind(1))
	for b in EB:
		if not on_screen(b.x, b.y, 6):
			continue
		sd(e0 if int(T * 8 + b.x * 0.1) % 2 == 0 else e1, b.x, b.y)

## 试炼的字：宽度查缓存、阴影只描一遍（主线是三遍），每帧能少画一半的字
var _tw_cache := {}

func text(s: String, cx: float, y: float, size: int, col: Color, sh = null, alpha := 1.0, bold := false) -> void:
	if alpha <= 0:
		return
	var f: Font = font_b if bold else font
	var key := "%s|%d|%s" % [s, size, bold]
	var tw = _tw_cache.get(key)
	if tw == null:
		if _tw_cache.size() > 3000:
			_tw_cache.clear()
		tw = text_w(s, size, bold)
		_tw_cache[key] = tw
	var x: float = (cx - float(tw) / 2.0 + OFS.x) * U
	var base := (y + OFS.y) * U + f.get_ascent(size * U)
	if sh != null:
		var c2: Color = sh
		c2.a = alpha
		cv.draw_string(f, Vector2(x + 1, base + 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size * U, c2)
	col.a = alpha
	cv.draw_string(f, Vector2(x, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size * U, col)

## 粒子有上限：怪海里一秒几十次命中，满了就不再加
func part(x: float, y: float, vx: float, vy: float, life: float, m: int, l: float, emit := false) -> void:
	if PT.size() >= [260, 130, 60][qual]:
		return
	super.part(x, y, vx, vy, life, m, l, emit)

func upd_particles(dt: float) -> void:
	var keep: Array[Part] = []
	var damp := exp(-1.8 * dt)
	for p in PT:
		p.life -= dt
		if p.life <= 0:
			continue
		p.vx *= damp
		p.vy *= damp
		p.x += p.vx * dt
		p.y += p.vy * dt
		keep.append(p)
	PT = keep

func _draw_zones(c: CanvasItem) -> void:
	var t0 := Time.get_ticks_usec()
	_dz(c)
	_dr_us["dz"] = int(_dr_us.get("dz", 0)) + Time.get_ticks_usec() - t0
	_dr_us["n_dz"] = int(_dr_us.get("n_dz", 0)) + 1

func _dz(c: CanvasItem) -> void:
	cv = c
	FXQ_LO = []
	_fxq = FXQ_LO
	if S == "hub":
		return
	# 我方地上的火
	for f in FIRE:
		disc(f.x, f.y, f.r, EMBER, 4, 0.8, f.x)
	# 墨涡
	for v in VORT2:
		for k in 3:
			ring(v.x, v.y, v.r * (1.0 - k * 0.3), ORE, 4 - k, 2.4, -T * (3.0 + k))
	# 印章的印子
	for s in SEALS:
		var k: float = s.t / 0.5
		var r: float = s.r
		var q := -r
		while q <= r:
			if Pal.bay(int(q), 0) < k + 0.2:
				sp(s.x + q, s.y - r, GOLD, 6, 0, 1.0)
				sp(s.x + q, s.y + r, GOLD, 6, 0, 1.0)
				sp(s.x - r, s.y + q, GOLD, 6, 0, 1.0)
				sp(s.x + r, s.y + q, GOLD, 6, 0, 1.0)
			q += 1.5
		if k > 0.4:
			for i in 5:
				sp(s.x - r * 0.5 + i * r * 0.25, s.y, GOLD, 5, 0, 1.0)
				sp(s.x, s.y - r * 0.5 + i * r * 0.25, GOLD, 5, 0, 1.0)
	# 烛台的光圈
	if plv(6) > 0:
		var R := aura_r()
		ring(P.x, P.y, R, ICE if ev(6, 1) else GOLD, 4, 2.6, T * 0.6)
		ring(P.x, P.y, R * 0.6, ICE if ev(6, 1) else GOLD, 3, 4.0, -T * 0.4)
	# 敌方：地上的火和墨
	for f in EF:
		if f.ink:
			disc(f.x, f.y, f.r, WINE, 4, 0.9, f.x)
			ring(f.x, f.y, f.r, SERP, 6, 1.5)
		else:
			disc(f.x, f.y, f.r, WINE, 6, 1.2, f.x)
			ring(f.x, f.y, f.r, SERP, 6, 1.5)
	# 敌方：预告圈
	for a in EA:
		var k: float = 1.0 - a.t / a.T
		ring(a.x, a.y, a.r, SERP, 6 if a.t < 0.25 or int(T * 10) % 2 == 0 else 4, 1.4)
		ring(a.x, a.y, a.r * k, WINE, 5, 2.0)
	# 敌方：预告线
	for l in EL:
		if l.t <= 0:
			beam_fx(l.x, l.y, l.a, l.len, maxf(1.5, l.w * 0.5), SERP, 6, false)
		else:
			dash_fx(l.x, l.y, l.a, l.len, SERP, 6 if l.t < 0.3 else 4)
	# 敌方：扩散的圈
	for r in ER:
		ring(r.x, r.y, r.r, SERP, 6, 1.3)
		ring(r.x, r.y, r.r - 2.0, WINE, 5, 2.5)
	# 地图事件点
	for q in POI:
		var d: Dictionary = POIK[q.k]
		var m: int = d.m
		var r: float = d.r
		if q.life > 8.0 or int(T * 6) % 2 == 0:
			ring(q.x, q.y, r, m, 5, 2.2, T * 0.5)
		if q.p > 0:
			disc(q.x, q.y, r * q.p, m, 3, 0.5, q.x)
			ring(q.x, q.y, r * q.p, m, 6, 1.4)
		ball(q.x, q.y + sin(T * 2.0) * 1.0 - 1.0, 3.5, m, 5, 0)
		for k in 4:
			var a := T * 1.6 + k * TAU / 4
			sp(q.x + cos(a) * 7.0, q.y + sin(a) * 3.5 - 1.0, m, 6 if k % 2 == 0 else 4)
	# 页尘、余烬、散页
	var dust_s: Array = []
	for q in 4:
		dust_s.append(bake("svdust|%d" % q, 2, 2, _p_dust.bind(q >= 2, q % 2 == 1)))
	for p in PK:
		if not on_screen(p.x, p.y):
			continue
		var tw := sin(T * 8 + p.age * 3) > 0
		match p.k:
			"dust":
				var big := p.v >= 5
				sd(dust_s[(2 if big else 0) + (1 if tw else 0)], p.x, p.y)
			"ember":
				sp(p.x - 1, p.y - 1, EMBER, 4, 0, 2.0)
				sp(p.x - 0.5, p.y - 1, EMBER, 6, 0, 1.0)
				sp(p.x, p.y, GOLD, 6 if tw else 5)
			"mag":
				ball(p.x, p.y + sin(T * 3) * 1.0, 2.5, ICE, 5, 0)
				for k in 4:
					var a := -T * 3 + k * TAU / 4
					sp(p.x + cos(a) * 4.5, p.y + sin(a) * 4.5, ORE, 6 if tw else 5)
			"kiln":
				ball(p.x, p.y + sin(T * 3) * 1.0, 3.0, GOLD, 5, 0)
				for k in 8:
					var a := T * 2 + k * TAU / 8
					sp(p.x + cos(a) * 5.5, p.y + sin(a) * 5.5, EMBER, 6 if tw else 5)
			"page":
				draw_page_icon(p.x, p.y + sin(T * 3) * 1.5, 1.0)
				for k in 6:
					var a := T * 1.5 + k * TAU / 6
					sp(p.x + cos(a) * 9, p.y + sin(a) * 9, GOLD, 6 if (k + int(T * 6)) % 2 == 0 else 4)
	# 生物自己的预告：回声蛇瞄准、墨鳗画线、残烛的火光
	for e in E:
		if e.dead:
			continue
		if (e.t == "serp" or e.t == "eel") and e.st == "aim":
			dash_fx(e.x + cos(e.ha) * 6.0, e.y + sin(e.ha) * 6.0, e.ha, 214.0 if e.t == "serp" else 164.0, SERP, 6 if e.tm < 0.3 else 4)
		elif e.t == "wick" and e.sing > 0:
			for q in 2:
				var a := e.ang + q * PI
				beam_fx(e.x + cos(a) * 12.0, e.y + sin(a) * 12.0, a, 228.0, 1.5, SERP, 6, false)

func _draw_world(c: CanvasItem) -> void:
	var t0 := Time.get_ticks_usec()
	_dw(c)
	_dr_us["dw"] = int(_dr_us.get("dw", 0)) + Time.get_ticks_usec() - t0
	_dr_us["n_dw"] = int(_dr_us.get("n_dw", 0)) + 1

func _dw(c: CanvasItem) -> void:
	cv = c
	FXQ_HI = []
	_fxq = FXQ_HI
	if S == "hub":
		return
	for e in E:
		if e.dead or not on_screen(e.x, e.y, 40):
			continue
		# 试炼里不按光照压暗：离得远的怪也要看得清
		var sh := 2 if e.flash > 0 else 0
		draw_creature(e, sh)
		if e.elite and not e.boss:
			# 精英头上一圈金点
			for k in 6:
				var a := T * 2.5 + k * TAU / 6
				sp(e.x + cos(a) * (e.r + 5), e.y + sin(a) * (e.r + 5) * 0.5 - 1, GOLD, 6 if k % 2 == 0 else 4)
		if e.burn_t > 0 and int(T * 10 + e.ph * 3) % 3 == 0:
			sp(e.x - 0.5, e.y - e.r - 1, EMBER, 6, 0, 1.0)
		if e.frz > 0 or frz_all > 0:
			sp(e.x - 1.5, e.y - e.r, ICE, 6, 0, 1.0)
			sp(e.x + 0.5, e.y - e.r + 1, ICE, 5, 0, 1.0)
			sp(e.x - 0.5, e.y + e.r - 1, ICE, 6)
		elif e.slow > 0 and int(T * 6 + e.ph) % 4 == 0:
			sp(e.x + 2, e.y - e.r, ICE, 6)
	draw_shots()
	# 飞行中的墨团
	for b in INKB:
		ball(b.x, b.y, 2.5, GRAV, 3, 0)
		sp(b.x - 0.5, b.y - 1.5, GRAV, 6)
	# 回环：绕身刻刀
	if ev(2, 0):
		var R := 26.0 * area_k()
		for k in 3:
			var a := blade_a + k * TAU / 3
			for q in 7:
				var aa := a - q * 0.06
				var rr := R + (q % 2) * 0.5
				sp(P.x + cos(aa) * rr, P.y + sin(aa) * rr, PAPER if q < 2 else MIRROR, 6 - q * 0.6, 0, 1.0 if q < 3 else 0.5)
			for q in 6:
				sp(P.x + cos(a) * (R - 3 + q), P.y + sin(a) * (R - 3 + q), PAPER, 6)
	# 刀光
	for s in SL:
		var k: float = s.t / 0.16
		var n := int(s.arc * s.r / 1.2)
		for i in n:
			var a: float = s.a - s.arc * 0.5 + s.arc * float(i) / n
			for q in 4:
				var rr: float = s.r - q * 2.0
				if Pal.bay(i, q) > k + 0.2:
					continue
				sp(s.x + cos(a) * rr, s.y + sin(a) * rr, PAPER if q == 0 else MIRROR, 6 - q, 0, 1.0 if q == 0 else 0.5)
	# 爆炸圈
	for b in BOOMS:
		var k: float = 1.0 - b.t / b.T
		var rr: float = b.r * (0.4 + 0.6 * k)
		ring(b.x, b.y, rr, b.m, 6, 1.3 if b.r < 100 else 2.0)
		if b.r < 100 and k < 0.4:
			ball(b.x, b.y, minf(6.0, b.r * 0.3) * (1.0 - k), b.m, 3, 0, 0.6)
	# 墨线
	for b in BEAMS:
		var k: float = b.t / b.max
		var wd: float = b.w * (0.4 + 0.6 * minf(1.0, k * 3.0))
		beam_fx(b.x + cos(b.a) * 4.0, b.y + sin(b.a) * 4.0, b.a, b.len - 4.0, maxf(1.0, wd * 0.5), ORE, 4, true)
	# 电弧
	for z in ZAPS:
		var L := Vector2(z.bx - z.ax, z.by - z.ay)
		var n := int(L.length() / 2.0)
		for i in n:
			var t := float(i) / maxf(1, n)
			sp(z.ax + L.x * t + (randf() - 0.5) * 3, z.ay + L.y * t + (randf() - 0.5) * 3, MIRROR, 6, 0, 1.0)
	draw_particles()
	draw_eb()
	# 陶灵画在最上面，怪再多也找得到自己
	if S != "over" or won:
		if P.inv <= 0 or int(T * 16) % 2 == 0 or P.inv > 0.6:
			draw_player()
		if shield_on:
			ring(P.x, P.y, 9.0, ICE, 6, 1.5, T * 2.0)
			ring(P.x, P.y, 10.5, MIRROR, 5, 3.0, -T * 1.5)
		if P.slow_t > 0:
			for k in 4:
				sp(P.x - 4 + k * 2.5, P.y + 5, ICE, 5, 0, 1.0)

func _draw_hud(c: CanvasItem) -> void:
	var t0 := Time.get_ticks_usec()
	_dh(c)
	_dr_us["dh"] = int(_dr_us.get("dh", 0)) + Time.get_ticks_usec() - t0
	_dr_us["n_dh"] = int(_dr_us.get("n_dh", 0)) + 1

func _dh(c: CanvasItem) -> void:
	cv = c
	OFS = Vector2.ZERO
	if S == "hub":
		dim(0.5)
		OFS = PO
		draw_hub()
		OFS = Vector2.ZERO
		return
	# 伤害数字（世界坐标换成屏幕坐标）
	for n in NUMS:
		var a: float = minf(1.0, n.t * 3.0)
		text(str(n.v), n.x - ox, n.y - oy, 9 if n.c else 7, C_GOLD if n.c else C_TXT, C_SH if n.c else null, a, n.c)
	if hurt_t > 0:
		rect(0, 0, W, H, Color(0.8, 0.1, 0.1, hurt_t * 0.5))
	if frz_all > 0:
		rect(0, 0, W, H, Color(0.5, 0.8, 1.0, 0.08))
	draw_sv_hud()
	if S == "lvl":
		dim(0.55)
		OFS = PO
		draw_lvl()
	elif S == "pact":
		dim(0.72)
		OFS = PO
		draw_pact()
	elif S == "shop":
		dim(0.72)
		OFS = PO
		draw_shop()
	elif S == "pause":
		dim(0.7)
		OFS = PO
		text("暂停", 160, 14, 16, C_GOLD, C_SH, 1.0, true)
		draw_build(160, 44)
		draw_btns(["继续", "结束这一局"])
	elif S == "over" and over_t > 0.6:
		dim(minf(0.75, (over_t - 0.6) * 1.5))
		OFS = PO
		if won:
			text("炉灯重新亮了", 160, 8, 16, C_GOLD, C_SH, 1.0, true)
			if new_danger:
				text("八个首领全倒了。解锁暗潮等级 %d：怪更硬更快，书页更多" % int(meta.dmax), 160, 32, 9, C_RED, C_SH)
			else:
				text("你撑过了 %s，打倒了全部八个首领" % fmt_t(gt2), 160, 32, 9, C_TXT, C_SH)
		else:
			text("陶身碎了", 160, 8, 16, C_RED, C_SH, 1.0, true)
			text("撑了 %s，走到第%s阶段「%s」" % [fmt_t(gt2), "一二三四五六七八"[stage], STAGES[stage].name], 160, 32, 9, C_TXT, C_SH)
		text("等级 %d · 打散 %d 只 · 首领 %d/8 · 得到书页 +%d" % [lv, kills2, boss_kills, earned], 160, 45, 9, C_GOLD, C_SH)
		draw_build(160, 60, true)
		draw_btns(["再来一局", "回营地"])
	OFS = Vector2.ZERO
	if H > W:
		rect(0, H / 2.0 - 12, W, 24, Color(0.02, 0.02, 0.06, 0.85))
		text("把手机横过来玩，画面更大", W / 2.0, H / 2.0 - 6, 10, C_GOLD, C_SH)

func _draw_hud_sprites(c: CanvasItem) -> void:
	if S != "hub":
		return
	cv = c
	no_cull = true
	var o := PO * U
	for i in 4:
		var r := hub_char(i)
		var sel := i == int(meta.ch)
		c.draw_set_transform(o + Vector2(r.position.x + r.size.x / 2.0, r.position.y + 13 + (sin(T * 3) * 1.0 if sel else 0.0)) * U, 0, Vector2(2 * U, 2 * U))
		draw_pc(i, 0, 0, int(T * 4) % 2 if sel else 0, 0, fmod(T + i, 3.0) < 0.15)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	no_cull = false

func fmt_t(t: float) -> String:
	return "%d:%02d" % [int(t / 60), int(fmod(t, 60))]

func draw_btns(names: Array) -> void:
	for i in 2:
		var r := pause_btn(i)
		box(r.position.x, r.position.y, r.size.x, r.size.y, Pal.rc(CLAY, 2) if i == 0 else Pal.rc(SPACE, 2), Pal.rc(GOLD, 5) if i == 0 else Pal.rc(RUIN, 5))
		text(names[i], r.get_center().x, r.position.y + 2, 10, C_GOLD if i == 0 else C_DIM, C_SH)
	if not touch_mode:
		text("Enter %s · %s %s" % [names[0], "Q" if S == "pause" else "Esc", names[1]], 160, 166, 8, C_DIM, C_SH)

func pen_label(i: int) -> String:
	var a := ev(i, 0)
	var b := ev(i, 1)
	if a and b:
		return "%s·%s" % [SPENS[i].ename[0], SPENS[i].ename[1]]
	if a:
		return SPENS[i].ename[0]
	if b:
		return SPENS[i].ename[1]
	return SPENS[i].name

## 这一局拿到的笔、字、技、成词
func draw_build(cx: float, y: float, stats := false) -> void:
	var ps := []
	for i in pens:
		ps.append(("「%s」" % pen_label(i)) if (ev(i, 0) or ev(i, 1)) else "%s %d" % [SPENS[i].name, plv(i)])
	var ws := []
	for s in words:
		ws.append("%s%d" % [s, w(s)])
	var ss := []
	for id in sk:
		ss.append("%s %d" % [SK[id].name, skl(id)])
	text("笔：" + "  ".join(ps), cx, y, 9, C_CLAY, C_SH)
	text("字：" + ("  ".join(ws) if not ws.is_empty() else "（还没有）"), cx, y + 13, 9, C_TEAL, C_SH)
	text("技：" + ("  ".join(ss) if not ss.is_empty() else "（还没有）"), cx, y + 26, 9, C_TXT, C_SH)
	if not combos.is_empty():
		text("成词：" + "  ".join(combos.keys()), cx, y + 39, 9, C_GOLD, C_SH)
	if not rel.is_empty():
		for ln in wrap_text("藏品：" + rel_line(), 6, 300):
			text(ln, cx, y + 76, 6, C_TEAL, C_SH)
			break
	if stats:
		# 结算：谁打了多少伤害
		var top := ds_top(6)
		var tot := 0.0
		for v in DS.values():
			tot += float(v)
		for i in top.size():
			var x := 44.0 + (i % 2) * 128.0
			var yy := y + 51.0 + (i / 2) * 8.0
			var fr: float = top[i][1] / maxf(1.0, tot)
			text_l(str(top[i][0]), x, yy, 7, C_TXT, C_SH)
			rect(x + 36, yy + 3, 50.0, 3, Pal.rc(RUIN, 3))
			rect(x + 36, yy + 3, 50.0 * top[i][1] / maxf(1.0, top[0][1]), 3, Pal.rc(GOLD if i == 0 else CLAY, 5))
			text_l("%d%%" % roundi(fr * 100), x + 89, yy, 7, C_GOLD if i == 0 else C_DIM, C_SH)
		return
	var hint := []
	for i in pens:
		for k in 2:
			if not ev(i, k):
				hint.append("%s+%s→%s" % [SPENS[i].name, SPENS[i].evo[k], SPENS[i].ename[k]])
	var hy := y + 53
	var row := []
	for h in hint:
		row.append(h)
		if row.size() == 4:
			text("  ".join(row), cx, hy, 7, C_DIM, C_SH)
			hy += 9
			row = []
	if not row.is_empty():
		text("  ".join(row), cx, hy, 7, C_DIM, C_SH)

func draw_sv_hud() -> void:
	# 顶上一条经验
	var k := clampf(float(xp) / xp_need(), 0.0, 1.0)
	rect(0, 0, W, 4, Color(0.03, 0.03, 0.08, 0.9))
	rect(0, 0, W * k, 4, Pal.rc(ORE, 4))
	rect(0, 0, W * k, 1, Pal.rc(ORE, 6))
	text_l("Lv %d" % lv, 3, 4, 9, C_GOLD, C_SH)
	# 生命
	for i in P.maxhp:
		icon(HEART, 4 + i * 6.5, 16, Pal.rc(CLAY, 5) if i < P.hp else Pal.rc(RUIN, 5))
	text_l("墨滴 %d" % ink, 4, 22, 7, C_TEAL, C_SH)
	if revives > 0:
		text_l("余火 ×%d" % revives, 44, 22, 7, C_GOLD, C_SH)
	if pact != "":
		text_l("誓约 · %s" % PACT[pact].n, 4, 30, 7, C_GOLD, C_SH)
	if curse_t > 0:
		text_r("诅咒怪潮 %d" % ceili(curse_t), W - 4, 36, 8, C_RED, C_SH)
	draw_poi_hud()
	# 时间和击退数
	var tc := C_RED if not bosses.is_empty() else C_TXT
	text(fmt_t(gt2), W / 2.0, 5, 12, tc, C_SH, 1.0, true)
	text("打散 %d" % kills2, W / 2.0, 20, 8, C_DIM, C_SH)
	# 右上：阶段
	text_r("第%s阶段 · %s" % ["一二三四五六七八"[stage], STAGES[stage].name], W - 4, 6, 8, C_TEAL, C_SH)
	var left := stage * STAGE_LEN + BOSS_IN - gt2
	if left > 0:
		text_r("%s %s 后出现" % [DEF[STAGES[stage].boss].name, fmt_t(left)], W - 4, 16, 8, C_DIM, C_SH)
	if P.dash_cd > 0:
		text_r("冲刺 %.1f" % P.dash_cd, W - 4, 26, 8, C_DIM, C_SH)
	# 左下：笔、字、技
	var x := 4.0
	var y := H - 26.0
	for i in pens:
		var gold := ev(i, 0) or ev(i, 1)
		var name := pen_label(i)
		var tw := text_w(name, 8) + 6
		box(x, y, tw, 11, Color(0.05, 0.05, 0.1, 0.8), Pal.rc(GOLD if gold else CLAY, 5))
		text_l(name, x + 3, y + 0.5, 8, C_GOLD if gold else C_CLAY)
		var l := mini(plv(i), 5)
		for q in 5:
			rect(x + 1.5 + q * (tw - 3) / 5.0, y + 9.5, (tw - 3) / 5.0 - 0.5, 1, Pal.rc(GOLD if q < l else RUIN, 5 if q < l else 3))
		x += tw + 3
	for id in sk:
		var name: String = SK[id].name
		var tw := text_w(name, 8) + 6
		var cdm: float = SK[id].cd
		var ck := clampf(float(sk_cd.get(id, 0.0)) / cdm, 0.0, 1.0)
		box(x, y, tw, 11, Color(0.05, 0.05, 0.1, 0.8), Pal.rc(MIRROR, 5))
		rect(x + 0.5, y + 0.5, (tw - 1) * (1.0 - ck), 10, Color(0.6, 0.7, 0.9, 0.18))
		text_l(name, x + 3, y + 0.5, 8, C_TXT)
		for q in 3:
			rect(x + 1.5 + q * (tw - 3) / 3.0, y + 9.5, (tw - 3) / 3.0 - 0.5, 1, Pal.rc(MIRROR if q < skl(id) else RUIN, 5 if q < skl(id) else 3))
		x += tw + 3
	x = 4.0
	y = H - 13.0
	for s in words:
		box(x, y, 16, 11, Color(0.05, 0.05, 0.1, 0.8), kind_col(SW[s].kind))
		text_l(s, x + 2, y + 0.5, 8, C_TXT)
		text_l(str(w(s)), x + 11, y + 2, 6, C_DIM)
		x += 18
	for n in combos:
		var tw := text_w(n, 8) + 5
		box(x, y, tw, 11, Color(0.18, 0.12, 0.04, 0.85), Pal.rc(GOLD, 6))
		text_l(n, x + 2.5, y + 0.5, 8, C_GOLD)
		x += tw + 2
	# 首领血条
	var by := 32.0
	for b in bosses:
		if b.dead:
			continue
		var bw := minf(200.0, W - 120)
		var bx := W / 2.0 - bw / 2.0
		box(bx - 1, by, bw + 2, 5, C_SH, Pal.rc(SERP, 5))
		rect(bx, by + 1, bw * maxf(0.0, b.hp / b.mhp), 3, Pal.rc(SERP, 4))
		text(DEF[b.t].name, W / 2.0, by + 5, 8, C_RED, C_SH)
		by += 16
	# 大字横幅
	if banner_t > 0:
		var a := minf(1.0, banner_t * 2.0) * minf(1.0, (3.2 - banner_t) * 4.0)
		text(banner, W / 2.0, H * 0.2, 18, banner_c, C_SH, a, true)
	# 提示
	var ty := H * 0.2 + 26
	for t in toasts:
		text(t.s, W / 2.0, ty, 9, t.c, C_SH, minf(1.0, t.t))
		ty += 12
	# 触屏摇杆
	for t in touches.values():
		if t.kind == "move":
			var c0: Vector2 = t.start
			for i in 16:
				var a := i * TAU / 16
				rect(c0.x + cos(a) * 22, c0.y + sin(a) * 22, 1, 1, Color(1, 1, 1, 0.25))
			rect(t.pos.x - 2, t.pos.y - 2, 4, 4, Color(1, 0.85, 0.6, 0.5))

func kind_col(c: String) -> Color:
	match c:
		"形": return Pal.rc(ORE, 5)
		"动": return Pal.rc(GOLD, 5)
		"性": return Pal.rc(EMBER, 5)
	return Pal.rc(CLAY, 5)

func draw_lvl() -> void:
	if ban_mode:
		text("封存哪一张？", 160, 8, 14, C_RED, C_SH, 1.0, true)
		text("封存的卡这一局不会再出现", 160, 27, 8, C_DIM, C_SH)
	else:
		text("升级！挑一个", 160, 8, 14, C_GOLD, C_SH, 1.0, true)
		text("Lv %d" % lv if touch_mode else "Lv %d · 点卡片，或按 1/2/3" % lv, 160, 27, 8, C_DIM, C_SH)
	for i in opts.size():
		var o: Dictionary = opts[i]
		var r := card_rect(i)
		var sel := i == opt_sel
		var is_evo: bool = o.k == "evo"
		var fill := Color(0.18, 0.12, 0.04, 0.95) if is_evo else Color(0.06, 0.06, 0.12, 0.95)
		var line := Pal.rc(GOLD, 6) if sel or is_evo else Pal.rc(RUIN, 5)
		if ban_mode:
			line = Pal.rc(SERP, 6) if sel and opt_key(o) != "" else Pal.rc(RUIN, 4)
		var yy := r.position.y - (3.0 if sel else 0.0)
		box(r.position.x, yy, r.size.x, r.size.y, fill, line)
		if sel:
			box(r.position.x + 1, yy + 1, r.size.x - 2, r.size.y - 2, null, Pal.rc(GOLD, 4))
		var cx := r.get_center().x
		var big := ""
		var col := C_CLAY
		var tag := ""
		match o.k:
			"pen":
				big = SPENS[o.i].name
				tag = "笔 · 新的" if plv(o.i) == 0 else "笔 · Lv%d→%d" % [plv(o.i), plv(o.i) + 1]
			"word":
				big = o.c
				col = kind_col(SW[o.c].kind)
				tag = "%s字 · 新的" % SW[o.c].kind if w(o.c) == 0 else "%s字 · Lv%d→%d" % [SW[o.c].kind, w(o.c), w(o.c) + 1]
			"skill":
				big = SK[o.id].name
				col = Pal.rc(MIRROR, 6)
				tag = "技 · 新的" if skl(o.id) == 0 else "技 · Lv%d→%d" % [skl(o.id), skl(o.id) + 1]
			"evo":
				big = SPENS[o.i].ename[o.e]
				col = C_GOLD
				tag = "成词进化！"
			"heal":
				big = "余烬"
				col = C_RED
			"temper":
				big = "淬火"
				col = C_TEAL
				tag = "强化 · 已拿 %d 次" % temper
			"boon":
				big = BOON[o.id].n
				col = Pal.rc(int(BOON[o.id].m), 6)
				tag = "强化 · 已拿 %d 次" % bn(o.id)
		text(big, cx, yy + 4, 18 if big.length() <= 2 else 14, col, C_SH, 1.0, true)
		text(tag, cx, yy + 29, 8, C_GOLD if is_evo else C_DIM, C_SH)
		var ly := yy + 41
		var first := true
		for para in opt_desc(o).split("\n"):
			for ln in wrap_text(para, 7 if not first else 8, r.size.x - 8):
				if ly < yy + r.size.y - 9:
					text(ln, cx, ly, 8 if first else 7, C_TXT if first else C_TEAL, C_SH)
				ly += 10 if first else 9
			first = false
			ly += 1
		if not touch_mode:
			text(str(i + 1), r.position.x + 5, yy + 2, 8, C_DIM)
	var labs := ["重掷 ×%d" % rerolls, "封存 ×%d" % banish, "跳过 +15墨"]
	var keys := ["R", "X", "C"]
	var live := [rerolls > 0, banish > 0, true]
	for i in 3:
		var rr := lvl_btn(i)
		var on: bool = live[i]
		var hot := i == 1 and ban_mode
		box(rr.position.x, rr.position.y, rr.size.x, rr.size.y, Pal.rc(WINE, 3) if hot else Pal.rc(SPACE, 2), Pal.rc(SERP, 6) if hot else Pal.rc(MIRROR if on else RUIN, 5 if on else 3))
		var lab: String = labs[i]
		if not touch_mode and on:
			lab += " " + keys[i]
		text(lab, rr.get_center().x, rr.position.y + 1.5, 8, C_TXT if on else C_DIM, C_SH)

# ======================================================================
# 营地：选陶灵、买永久升级、出发
# ======================================================================
# ---------- 炉灯工坊：首领之间的小店 ----------
const INK_PER_LV := 9.0

func rel_cost(id: String) -> int:
	var it: Dictionary = RL[id]
	var k := 1.0 + 0.15 * (shop_n - 1)
	if not it.get("once", false):
		k *= 1.0 + 0.25 * rl(id)
	return int(float(it.c) * k * (0.8 if pact == "dealer" else 1.0))

func rr_cost() -> int:
	return 3 + 2 * shop_n + 4 * shop_rr

func roll_shop() -> void:
	var c := []
	for id in RL:
		if rl(id) >= int(RL[id].max):
			continue
		if id == "candy" and P.hp >= P.maxhp:
			continue
		if id == "tissue" and P.maxhp <= 3:
			continue
		c.append(id)
	c.shuffle()
	shop = []
	for i in mini(4, c.size()):
		shop.append({"id": c[i], "cost": rel_cost(c[i]), "sold": false})

func open_shop() -> void:
	shop_n += 1
	shop_rr = 0
	if pact == "dealer":
		ink += 30
	roll_shop()
	S = "shop"
	Sfx.play("buy")
	for p in PK:
		if p.k == "dust":
			p.gold = true
	if _autoplay:
		print("SHOP %d t=%d ink=%d lv=%d" % [shop_n, int(gt2), ink, lv])

func buy_rel(i: int) -> void:
	if i < 0 or i >= shop.size():
		return
	var it: Dictionary = shop[i]
	if it.sold:
		return
	if ink < int(it.cost):
		Sfx.play("deny")
		return
	ink -= int(it.cost)
	it.sold = true
	Sfx.play("eat")
	var id: String = it.id
	match id:
		"leaf":
			lv += 2
			lv_q += 2
			return
		"candy":
			P.hp = P.maxhp
			return
		"shard":
			P.maxhp += 1
			P.hp += 1
		"tissue":
			P.maxhp = maxi(1, P.maxhp - 1)
			P.hp = mini(P.hp, P.maxhp)
		"tape":
			rerolls += 2
		"core":
			revives += 1
	rel[id] = rl(id) + 1

func close_shop() -> void:
	if rl("jar") > 0:
		ink += mini(40 * rl("jar"), int(ink * 0.2 * rl("jar")))
	S = "sv"
	P.inv = maxf(P.inv, 1.2)

func shop_card(i: int) -> Rect2:
	return Rect2(7 + i * 77, 36, 72, 98)

func shop_rr_rect() -> Rect2:
	return Rect2(62, 140, 92, 15)

func shop_go_rect() -> Rect2:
	return Rect2(166, 140, 92, 15)

func upd_shop() -> void:
	var mp := ppointer()
	for i in shop.size():
		if pressed(KEY_1 + i) or pressed(KEY_KP_1 + i) or (click_q and shop_card(i).has_point(mp)):
			buy_rel(i)
	if pressed(KEY_R) or (click_q and shop_rr_rect().has_point(mp)):
		if ink >= rr_cost():
			ink -= rr_cost()
			shop_rr += 1
			roll_shop()
			Sfx.play("ping")
		else:
			Sfx.play("deny")
	if _autoplay:
		_lvl_wait += get_physics_process_delta_time()
		if _lvl_wait < 0.5:
			if not _shot_at.has("shop%d" % shop_n) and (shop_n == 1 or shop_n == 4):
				_shot_at["shop%d" % shop_n] = true
				_shot("shop%d" % shop_n)
			return
		_lvl_wait = 0.0
		for i in shop.size():
			buy_rel(i)
		close_shop()
		return
	if pressed(KEY_ENTER) or pressed(KEY_KP_ENTER) or pressed(KEY_SPACE) or pressed(KEY_ESCAPE) or (click_q and shop_go_rect().has_point(mp)):
		close_shop()

func rel_line() -> String:
	var a := []
	for id in rel:
		a.append("%s×%d" % [RL[id].n, rl(id)] if rl(id) > 1 else str(RL[id].n))
	return "  ".join(a)

func draw_shop() -> void:
	text("炉灯工坊", 160, 4, 14, C_GOLD, C_SH, 1.0, true)
	text("首领倒下，炉灯亮一会儿。用路上攒的墨滴换点东西再走。", 160, 23, 7, C_DIM, C_SH)
	text_r("墨滴 %d" % ink, 312, 8, 10, C_TEAL, C_SH)
	text_l("第 %d 间" % shop_n, 8, 9, 8, C_DIM, C_SH)
	var mp := ppointer()
	for i in shop.size():
		var it: Dictionary = shop[i]
		var d: Dictionary = RL[it.id]
		var r := shop_card(i)
		var can: bool = not it.sold and ink >= int(it.cost)
		var hov: bool = r.has_point(mp) and not it.sold
		box(r.position.x, r.position.y, r.size.x, r.size.y, Color(0.1, 0.09, 0.05, 0.95) if hov else Color(0.06, 0.06, 0.12, 0.95), Pal.rc(GOLD, 6 if hov else 5) if can else Pal.rc(RUIN, 4))
		var cx := r.get_center().x
		var a: float = 0.35 if it.sold else 1.0
		text(d.n, cx, r.position.y + 4, 11, C_GOLD if can else C_TXT, C_SH, a, true)
		if rl(it.id) > 0:
			text("已有 %d" % rl(it.id), cx, r.position.y + 20, 6, C_DIM, null, a)
		var ly := r.position.y + 30
		for ln in wrap_text(d.d, 7, r.size.x - 6):
			text(ln, cx, ly, 7, C_TXT, C_SH, a)
			ly += 9
		if it.sold:
			text("已买", cx, r.position.y + r.size.y - 14, 9, C_DIM, C_SH)
		else:
			text("%d 墨" % int(it.cost), cx, r.position.y + r.size.y - 14, 9, C_TEAL if can else C_RED, C_SH, 1.0, true)
		if not touch_mode:
			text(str(i + 1), r.position.x + 5, r.position.y + 2, 8, C_DIM)
	var rr := shop_rr_rect()
	box(rr.position.x, rr.position.y, rr.size.x, rr.size.y, Pal.rc(SPACE, 2), Pal.rc(MIRROR, 5) if ink >= rr_cost() else Pal.rc(RUIN, 4))
	text("换一批 %d 墨%s" % [rr_cost(), "" if touch_mode else " (R)"], rr.get_center().x, rr.position.y + 2.5, 8, C_TXT if ink >= rr_cost() else C_DIM, C_SH)
	var g := shop_go_rect()
	box(g.position.x, g.position.y, g.size.x, g.size.y, Pal.rc(CLAY, 2), Pal.rc(GOLD, 5 if sin(T * 3) > 0 else 6))
	text("继续上路" if touch_mode else "继续上路 (Enter)", g.get_center().x, g.position.y + 2.5, 8, C_GOLD, C_SH, 1.0, true)
	if not rel.is_empty():
		for ln in wrap_text("藏品：" + rel_line(), 6, 300):
			text(ln, 160, 160, 6, C_DIM, C_SH)
			break

func hub_char(i: int) -> Rect2:
	return Rect2(9 + i * 76, 28, 72, 56)

func hub_shop(i: int) -> Rect2:
	return Rect2(9 + (i % 3) * 102, 90 + (i / 3) * 25, 98, 22)

func hub_dl() -> Rect2:
	return Rect2(214, 139, 98, 10)

func hub_go() -> Rect2:
	return Rect2(112, 143, 96, 18)

func hub_back() -> Rect2:
	return Rect2(9, 146, 58, 13)

func meta_cost(i: int) -> int:
	var it: Dictionary = META[i]
	var l := mu(it.id)
	if l >= int(it.max):
		return -1
	return int(it.cost[l])

func try_meta(i: int) -> void:
	var cst := meta_cost(i)
	if cst < 0:
		return
	if int(meta.pages) < cst:
		toast("书页不够：打一局就有", C_RED, 2)
		Sfx.play("hurt", 1.5)
		return
	meta.pages = int(meta.pages) - cst
	meta.up[META[i].id] = mu(META[i].id) + 1
	Sfx.play("buy")
	_save_meta()

func upd_hub() -> void:
	var mp := ppointer()
	if pressed(KEY_A) or pressed(KEY_LEFT):
		meta.ch = (int(meta.ch) + 3) % 4
	if pressed(KEY_D) or pressed(KEY_RIGHT):
		meta.ch = (int(meta.ch) + 1) % 4
	for i in META.size():
		if pressed(KEY_1 + i) or (click_q and hub_shop(i).has_point(mp)):
			try_meta(i)
	for i in 4:
		if click_q and hub_char(i).has_point(mp):
			meta.ch = i
			Sfx.play("ping")
	var dmax := int(meta.get("dmax", 0))
	if dmax > 0:
		var dl := int(meta.get("dl", 0))
		if pressed(KEY_E) or (click_q and hub_dl().has_point(mp)):
			meta.dl = (dl + 1) % (dmax + 1)
			Sfx.play("ping")
		elif pressed(KEY_Q):
			meta.dl = (dl + dmax) % (dmax + 1)
			Sfx.play("ping")
	if pressed(KEY_ENTER) or pressed(KEY_KP_ENTER) or pressed(KEY_SPACE) or (click_q and hub_go().has_point(mp)):
		_save_meta()
		start_run()
	elif pressed(KEY_ESCAPE) or (click_q and hub_back().has_point(mp)):
		_save_meta()
		get_tree().change_scene_to_file("res://main.tscn")

func draw_hub() -> void:
	text("暗潮试炼", 160, 4, 15, C_GOLD, C_SH, 1.0, true)
	text_r("书页 %d" % int(meta.pages), 311, 8, 9, C_GOLD, C_SH)
	text_l("选一只陶灵", 9, 12, 8, C_DIM, C_SH)
	for i in 4:
		var r := hub_char(i)
		var sel := i == int(meta.ch)
		box(r.position.x, r.position.y, r.size.x, r.size.y, Color(0.12, 0.08, 0.05, 0.9) if sel else Color(0.05, 0.05, 0.1, 0.85), Pal.rc(GOLD, 6) if sel else Pal.rc(RUIN, 5))
		var cx := r.get_center().x
		text(CHARS[i].name, cx, r.position.y + 22, 9, C_GOLD if sel else C_TXT, C_SH, 1.0, true)
		text(SCH[i].tag, cx, r.position.y + 34, 7, C_CLAY, C_SH)
		var ly := r.position.y + 43
		for ln in wrap_text(SCH[i].d, 6, r.size.x - 6):
			text(ln, cx, ly, 6, C_DIM)
			ly += 7
	for i in META.size():
		var it: Dictionary = META[i]
		var r := hub_shop(i)
		var l := mu(it.id)
		var cst := meta_cost(i)
		var ok := cst >= 0 and int(meta.pages) >= cst
		box(r.position.x, r.position.y, r.size.x, r.size.y, Color(0.05, 0.05, 0.1, 0.85), Pal.rc(GOLD, 5) if ok else Pal.rc(RUIN, 4))
		text_l("%s %d/%d" % [it.name, l, int(it.max)], r.position.x + 3, r.position.y + 1, 8, C_TXT if cst >= 0 else C_GOLD, C_SH)
		text_r("已满" if cst < 0 else "%d 页" % cst, r.position.x + r.size.x - 3, r.position.y + 1, 8, C_GOLD if ok else C_DIM, C_SH)
		text_l(it.d, r.position.x + 3, r.position.y + 12, 6, C_DIM)
	var g := hub_go()
	box(g.position.x, g.position.y, g.size.x, g.size.y, Pal.rc(CLAY, 2), Pal.rc(GOLD, 5 if sin(T * 3) > 0 else 6))
	text("出发" if touch_mode else "出发 (Enter)", g.get_center().x, g.position.y + 2.5, 10, C_GOLD, C_SH, 1.0, true)
	var b := hub_back()
	box(b.position.x, b.position.y, b.size.x, b.size.y, Pal.rc(SPACE, 2), Pal.rc(RUIN, 5))
	text("回主线", b.get_center().x, b.position.y + 1.5, 8, C_DIM, C_SH)
	var bs: Dictionary = meta.best
	text("最好成绩：%s · 等级 %d · 首领 %d/8 · 通关 %d 次" % [fmt_t(float(bs.get("time", 0.0))), int(bs.get("lv", 0)), int(bs.get("bosses", 0)), int(bs.get("wins", 0))], 160, 164, 7, C_DIM, C_SH)
	if not touch_mode:
		text("←→ 换陶灵 · 1~6 买升级", 262, 152, 7, C_DIM, C_SH)
	if int(meta.get("dmax", 0)) > 0:
		var dr := hub_dl()
		var dl := int(meta.get("dl", 0))
		box(dr.position.x, dr.position.y, dr.size.x, dr.size.y, Color(0.05, 0.05, 0.1, 0.85), Pal.rc(SERP, 5) if dl > 0 else Pal.rc(RUIN, 4))
		text("暗潮等级 %d/%d%s" % [dl, int(meta.dmax), "" if touch_mode else "（Q/E）"], dr.get_center().x, dr.position.y + 0.5, 7, C_RED if dl > 0 else C_TXT, C_SH)
	var ty := 76.0
	for t in toasts:
		text(t.s, 160, ty, 9, t.c, C_SH, minf(1.0, t.t))

# ======================================================================
# 自动试玩（测试用）：godot -- --surv --autoplay [--fast=4] [--god] [--char=N]
# ======================================================================
var _bot_mv := Vector2.ZERO
var _god_saves := 0
var _lvl_wait := 0.0
var _sbt := 0.0
var _bot_a := 0.0

func _sv_bot(dt: float) -> void:
	_sbt += dt
	if S == "over":
		if over_t > 2.0:
			_shot("over")
			get_tree().quit()
		return
	if S == "hub":
		if _sbt > 1.0 and not _shot_at.has("hub"):
			_shot_at["hub"] = true
			_shot("hub")
		if _sbt > 2.0:
			get_tree().quit()
		return
	if S != "sv":
		return
	_bot_a += dt * 0.35
	var v := Vector2(cos(_bot_a), sin(_bot_a)) * 0.6
	for e in E:
		var d := Vector2(P.x - e.x, P.y - e.y)
		var L := d.length()
		if L < 56 and L > 0.1:
			v += d / L * pow((56 - L) / 56, 2.0) * (6.0 if e.elite or e.boss else 3.5)
	for b in EB:
		var d := Vector2(P.x - b.x, P.y - b.y)
		var L := d.length()
		if L < 30 and L > 0.1:
			v += d / L * 1.5
	for a in EA:
		var d := Vector2(P.x - a.x, P.y - a.y)
		var L := d.length()
		if L < a.r + 8:
			v += (d / maxf(L, 0.1) if L > 0.5 else Vector2(1, 0)) * 4.0
	for q in POI:
		if P.hp < 3 or (q.k == "curse" and P.hp < P.maxhp - 1) or OS.get_cmdline_user_args().has("--nopoi"):
			continue
		var dv := Vector2(q.x - P.x, q.y - P.y)
		if dv.length() < 300 and dv.length() > float(POIK[q.k].r) * 0.4:
			v += dv.normalized() * 2.0
	for q in POI:
		if not _shot_at.has("poi_" + str(q.k)) and absf(q.x - P.x) < 60 and absf(q.y - P.y) < 40:
			_shot_at["poi_" + str(q.k)] = true
			_shot("poi_" + str(q.k))
	var g: Pick = null
	var gd := 150.0
	for p in PK:
		var L := Vector2(p.x - P.x, p.y - P.y).length()
		if L < gd:
			gd = L
			g = p
	if g:
		v += Vector2(g.x - P.x, g.y - P.y).normalized() * 1.2
	_bot_mv = v.normalized() if v.length() > 0.2 else v
	for i in 40:
		var t := 20.0 + i * 52.5
		if gt2 >= t and not _shot_at.has(t):
			_shot_at[t] = true
			if i % 2 == 1:
				_shot("t%04d" % int(t))
			print("t=%d st=%d lv=%d enemies=%d eb=%d pb=%d pt=%d kills=%d hp=%d bosses=%d/%d saves=%d avg_ms=%.2f max_ms=%.2f" % [int(gt2), stage + 1, lv, E.size(), EB.size(), PB.size(), PT.size(), kills2, P.hp, boss_kills, bosses.size(), _god_saves, _perf_us / 1000.0 / maxf(1, _perf_n), _perf_max / 1000.0])
			_perf_max = 0
			_perf_us = 0
			_perf_n = 0
			var dn := maxf(1.0, float(_dr_us.get("n_dw", 1)))
			print("   DRAW ms zones=%.2f world=%.2f hud=%.2f items=%d" % [float(_dr_us.get("dz", 0)) / dn / 1000.0, float(_dr_us.get("dw", 0)) / dn / 1000.0, float(_dr_us.get("dh", 0)) / dn / 1000.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
			_dr_us = {}
			var hist := {}
			for e in E:
				hist[e.t] = int(hist.get(e.t, 0)) + 1
			print("   ", hist)
	if gt2 > 1300:
		end_run(false)
	if _sv_god() and P.hp <= 3:
		P.hp = P.maxhp
		_god_saves += 1

func _sv_god() -> bool:
	return OS.get_cmdline_user_args().has("--god")

func _bot_pick() -> int:
	for i in opts.size():
		if opts[i].k == "evo":
			return i
	for i in opts.size():
		var o: Dictionary = opts[i]
		if o.k == "word" and w(o.c) == 0 and not word_links(o.c).is_empty():
			return i
	for i in opts.size():
		if opts[i].k == "pen":
			return i
	return randi() % opts.size()

func _shot(name: String) -> void:
	if OS.get_cmdline_user_args().has("--noshot"):
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://surv_%s.png" % name)

# ======================================================================
# 誓约：开局三选一
# ======================================================================
func pact_card(i: int) -> Rect2:
	return Rect2(11 + i * 102, 42, 94, 98)

func pact_none() -> Rect2:
	return Rect2(122, 149, 76, 14)

func upd_pact() -> void:
	var pick := -1
	for i in 3:
		if pressed(KEY_1 + i) or pressed(KEY_KP_1 + i):
			pick = i
	if pressed(KEY_A) or pressed(KEY_LEFT):
		pact_sel = (pact_sel + 2) % 3
	if pressed(KEY_D) or pressed(KEY_RIGHT):
		pact_sel = (pact_sel + 1) % 3
	if pressed(KEY_ENTER) or pressed(KEY_KP_ENTER) or pressed(KEY_SPACE):
		pick = pact_sel
	var mp := ppointer()
	for i in 3:
		if pact_card(i).has_point(mp):
			if mouse_moved:
				pact_sel = i
			if click_q:
				pick = i
	if _autoplay:
		_lvl_wait += get_physics_process_delta_time()
		if _lvl_wait < 0.5:
			if not _shot_at.has("pact"):
				_shot_at["pact"] = true
				_shot("pact")
			return
		_lvl_wait = 0.0
		take_pact("")
		return
	if pressed(KEY_N) or pressed(KEY_0) or pressed(KEY_ESCAPE) or (click_q and pact_none().has_point(mp)):
		take_pact("")
	elif pick >= 0:
		take_pact(pact_opts[pick])

func draw_pact() -> void:
	text("立一个誓约", 160, 8, 14, C_GOLD, C_SH, 1.0, true)
	text("一条规矩管一整局，有得有失。也可以不立。", 160, 27, 8, C_DIM, C_SH)
	var pw: Dictionary = meta.get("pw") if meta.get("pw") is Dictionary else {}
	for i in 3:
		var id: String = pact_opts[i]
		var d: Dictionary = PACT[id]
		var r := pact_card(i)
		var sel := i == pact_sel
		var yy := r.position.y - (3.0 if sel else 0.0)
		box(r.position.x, yy, r.size.x, r.size.y, Color(0.06, 0.06, 0.12, 0.95), Pal.rc(GOLD, 6) if sel else Pal.rc(RUIN, 5))
		if sel:
			box(r.position.x + 1, yy + 1, r.size.x - 2, r.size.y - 2, null, Pal.rc(GOLD, 4))
		var cx := r.get_center().x
		text(str(d.n), cx, yy + 5, 18, Pal.rc(int(d.m), 6), C_SH, 1.0, true)
		text("通关过" if pw.has(id) else "还没用它通关", cx, yy + 30, 7, C_GOLD if pw.has(id) else C_DIM, C_SH)
		var ly := yy + 44
		for ln in wrap_text(str(d.d), 8, r.size.x - 8):
			text(ln, cx, ly, 8, C_TEAL, C_SH)
			ly += 10
		ly += 4
		for ln in wrap_text(str(d.x), 8, r.size.x - 8):
			text(ln, cx, ly, 8, C_RED, C_SH)
			ly += 10
		if not touch_mode:
			text(str(i + 1), r.position.x + 5, yy + 2, 8, C_DIM)
	var nr := pact_none()
	box(nr.position.x, nr.position.y, nr.size.x, nr.size.y, Pal.rc(SPACE, 2), Pal.rc(MIRROR, 5))
	text("不立誓" + ("" if touch_mode else " (N)"), nr.get_center().x, nr.position.y + 2, 8, C_TXT, C_SH)
	text("用过誓约通关 %d / %d 种" % [pw.size(), PACT.size()], 160, 167, 7, C_DIM, C_SH)

# ======================================================================
# 地图事件点
# ======================================================================
func add_poi() -> void:
	var ks := ["trial", "trial", "stele", "stele"]
	# 诅咒碑第一阶段不出：那时候还扛不住
	if stage > 0:
		ks += ["curse", "curse"]
	if P.hp < P.maxhp:
		ks += ["spring", "spring"]
	var k: String = ks[randi() % ks.size()]
	var a := randf() * TAU
	if P.moving:
		a = atan2(P.ay, P.ax) + (randf() - 0.5) * 2.4
	var R := 120.0 + randf() * 50.0
	POI.append({"k": k, "x": P.x + cos(a) * R, "y": P.y + sin(a) * R, "p": 0.0, "life": 55.0, "left": 3, "on": false})
	toast("附近出现了%s：%s" % [POIK[k].n, POIK[k].d], C_GOLD, 5)
	Sfx.play("beacon", 1.3)

func poi_wave(n: int) -> void:
	encircle(["moth", "hush"] if stage == 0 else (["moth", "chill"] if stage < 3 else ["moth", "chill", "icicle"]), n)

func upd_poi(dt: float) -> void:
	curse_t = maxf(0.0, curse_t - dt)
	if POI.is_empty():
		return
	var keep := []
	for q in POI:
		var d: Dictionary = POIK[q.k]
		var dx: float = P.x - q.x
		var dy: float = P.y - q.y
		var r: float = d.r
		if dx * dx + dy * dy < r * r and not (q.k == "spring" and P.hp >= P.maxhp):
			if not q.on:
				q.on = true
				if q.k == "trial":
					poi_wave(18 + stage * 4)
					Sfx.play("warn")
					toast("守住圈子！", C_RED, 2)
			q.p += dt / float(d.need)
			q.life = maxf(q.life, 6.0)
		else:
			q.p = maxf(0.0, q.p - dt / float(d.need) * 0.5)
			q.life -= dt
		if q.p >= 1.0:
			q.p = 0.0
			if poi_done(q):
				burst(q.x, q.y, 24, int(d.m), 6, 80, 0.8)
				continue
		if q.life <= 0:
			burst(q.x, q.y, 8, int(d.m), 4, 30, 0.5)
			continue
		keep.append(q)
	POI = keep

## 事件点生效。返回 true = 用完了
func poi_done(q: Dictionary) -> bool:
	match q.k:
		"trial":
			add_pick(q.x, q.y, "page")
			ink += 20
			shk = 6
			Sfx.play("buy")
			set_banner("试炼完成", "一张散页，外加 20 墨滴", C_GOLD)
		"curse":
			temper += 1
			ink += 30
			curse_t = 30.0
			poi_wave(30 + stage * 6)
			shk = 8
			Sfx.play("roar", 1.4)
			set_banner("诅咒", "怪潮 30 秒。伤害 +5%，墨滴 +30", C_RED)
		"spring":
			heal(1)
			Sfx.play("ember")
			q.left = int(q.left) - 1
			return int(q.left) <= 0
		"stele":
			lv_q += 1
			Sfx.play("page")
			set_banner("字碑", "白拿一次升级", C_GOLD)
	return true

## 事件点的名字，和不在屏幕里时指路的小标记
func draw_poi_hud() -> void:
	for q in POI:
		var d: Dictionary = POIK[q.k]
		var col := Pal.rc(int(d.m), 6)
		var sx: float = q.x - ox
		var sy: float = q.y - oy
		var r: float = d.r
		if sx > 8 and sx < W - 8 and sy > 30 and sy < H - 30:
			text(str(d.n), sx, sy - r - 11, 8, col, C_SH)
			if absf(P.x - q.x) < r + 45 and absf(P.y - q.y) < r + 45:
				text(str(d.d), sx, sy + r + 2, 7, C_TXT, C_SH)
		else:
			var vx := sx - W / 2.0
			var vy := sy - H / 2.0
			var k := minf((W / 2.0 - 22.0) / maxf(1.0, absf(vx)), (H / 2.0 - 34.0) / maxf(1.0, absf(vy)))
			var px := W / 2.0 + vx * k
			var py := H / 2.0 + vy * k
			var bl := 5 if int(T * 3) % 2 == 0 else 6
			rect(px - 2, py - 2, 4, 4, C_SH)
			rect(px - 1.5, py - 1.5, 3, 3, Pal.rc(int(d.m), bl))
			text("%s %d步" % [d.n, int(sqrt(vx * vx + vy * vy) / 10.0)], px, py - 11, 7, col, C_SH)

## 伤害最高的几个来源：[[名字, 总伤害], …]
func ds_top(n: int) -> Array:
	var a := []
	for k in DS:
		a.append([k, float(DS[k])])
	a.sort_custom(func(x, y): return x[1] > y[1])
	return a.slice(0, n)
