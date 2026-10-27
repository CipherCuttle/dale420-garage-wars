extends Resource
class_name GarageConfig

# One shared tuning resource; tests can shorten clocks without replacing logic.
@export var max_hp: float = 100.0
@export var fury_threshold: float = 36.0
@export var fury_per_attacker: float = 36.0
@export var transformation_intro: float = 1.0
@export var transformation_seconds: float = 22.0
@export var recovery_seconds: float = 12.0
@export var erik_speed: float = 5.5
@export var dale_speed: float = 9.0
@export var erik_punch: float = 5.0
@export var dale_punch: float = 18.0
@export var dale_kick: float = 36.0
@export var counter_damage: float = 24.0
@export var joint_heal: float = 28.0
@export var dodge_seconds: float = 0.36
@export var dodge_cooldown: float = 1.15
@export var boss_hp: float = 240.0
@export var sandwich_interval: float = 8.0
@export var intimidation_interval: float = 13.0
