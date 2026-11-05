--枚举变量

--属性
PROP_HPVALUE = 1			--体力值
PROP_MPVALUE = 2			--法力值
PROP_HAPPY_VALUE = 3			--快乐度
PROP_FULL_VALUE = 4			--饱食度

PROP_STRENGTH = 11			--力量
PROP_AGILITY = 12			--敏捷
PROP_CORPOREITY = 13			--体质
PROP_INTELLECT = 14			--智力

PHYSICAL_ATTACK = 20			--物理攻击
PHYSICAL_DEFENCE = 21			--物理防御
MAGIC_ATTACK = 22			--魔法攻击
MAGIC_DEFENCE = 23			--魔法防御

HP_MAX = 30				--体力上限
MP_MAX = 31				--法力上限
HP_RESUME = 32				--体力恢复
MP_RESUME = 33				--法力恢复

MOVE_SPEED = 40				--移动速度
PHYSICAL_FATAL = 41			--物理致命	
MAGIC_FATAL = 42			--魔法致命	
SHOOT_RATE = 43				--命中属性
JOOK_RATE = 44				--闪避属性
LUCK_RATE = 45				--幸运几率

SORBDAMAGE = 50			--吸收伤害
EMITDAMAGE = 51			--释放伤害

TERRA_RESIST = 60			--地抗性
FIRE_RESIST = 61			--火抗性
WIND_RESIST = 62			--风抗性
WATER_RESIST = 63			--水抗性
HOLY_RESIST = 64			--圣抗性
DARK_RESIST = 65			--暗抗性
PK_CONDITION = 66			--PK状态

TERRA_DAMAGE=100		--地伤害
FIRE_DAMAGE=101			--火伤害
WIND_DAMAGE=102			--风伤害
WATER_DAMAGE=103		--水伤害
DARK_DAMAGE = 120		--暗伤害

WEAPON_BIAS_RATE=104		--武器偏斜率

--程序中自定义的属性
PROP_LEVEL = 1000			--等级
PROP_SN = 1001			--序号
PROP_SEX = 1002			--性别
PROP_GEN = 1003			--辈分
PROP_CHARACTER = 1004		--性格

PROP_PHY_GIFT = 1005		--物攻
PROP_MAGIC_GIFT = 1006	--魔攻
PROP_CROP_GIFT = 1007		--体力
PROP_MANA_GIFT = 1008		--法力
PROP_DEFENCE_GIFT = 1009	--防御
PROP_RESIST_GIFT = 1010	--抗性
PROP_SHOOT_GIFT = 1011	--命中
PROP_JOOK_GIFT = 1012		--闪避

PROP_PHY_GIFT_MAX = 1020	--物攻
PROP_MAGIC_GIFT_MAX = 1021		--魔攻
PROP_CROP_GIFT_MAX = 1022			--体力
PROP_MANA_GIFT_MAX = 1023			--法力
PROP_DEFENCE_GIFT_MAX = 1024		--防御
PROP_RESIST_GIFT_MAX = 1025		--抗性
PROP_SHOOT_GIFT_MAX = 1026		--命中
PROP_JOOK_GIFT_MAX = 1027			--闪避

PROP_NUMERAL_SN = 1035		--数值模板SN
PROP_LEFT_TIME = 1036		--寿命

PROP_PHY_GIFT_INIT = 1040			--初始物攻
PROP_MAGIC_GIFT_INIT = 1041		--初始魔攻
PROP_CROP_GIFT_INIT = 1042		--初始体力
PROP_MANA_GIFT_INIT = 1043		--初始法力
PROP_DEFENCE_GIFT_INIT = 1044	--初始防御
PROP_RESIST_GIFT_INIT = 1045		--初始抗性
PROP_SHOOT_GIFT_INIT = 1046		--初始命中
PROP_JOOK_GIFT_INIT = 1047		--初始闪避

--装备中新加入的属性
PROP_100SHOOTRATE=105			--必中
PROP_DEFENCE_IGNORE=106			--忽略对方防御(%)
PROP_DEFENCE_ENHANCE=107		--防御强化(%)
PROP_SHOOTRATE_ENHANCE=108		--命中强化(%)
PROP_JOOK_ENHANCE=109			--闪避强化(%)109
PROP_FIRE_RESISIT_DECREASE=110		--降低对方火抗110
PROP_WATER_RESISIT_DECREASE=111		--降低对方冰抗111

PROP_EXP_GETRATE=112			--经验值倍数
PROP_MONEY_GETRATE=113			--金钱倍数
PROP_DROP_GETRATE=114			--掉落倍数

PROP_MD_RESIST_PERSENT=118		--魔法盾抵抗伤害百分比
PROP_MD_RESIST_PER_100_MANA=119		--每100点魔法抵抗伤害值，一般要设置成100
