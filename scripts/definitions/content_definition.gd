class_name ContentDefinition
extends Resource

## Typed internal representation for catalogue entries.
## Catalog's public API remains plain dictionaries for simulation/save compatibility.

@export var id: String = ""
@export var display_name: String = ""
@export var cost: float = 0.0
@export var upkeep: float = 0.0
@export var radius: float = 0.0
@export var grade: int = 1
@export var payload: Dictionary = {}

static func from_dictionary(entry: Dictionary) -> ContentDefinition:
	var definition: ContentDefinition = ContentDefinition.new()
	definition.id = str(entry.get("id", ""))
	definition.display_name = str(entry.get("name", definition.id))
	definition.cost = float(entry.get("cost", entry.get("principal", 0.0)))
	definition.upkeep = float(entry.get("upkeep", 0.0))
	definition.radius = float(entry.get("radius", 0.0))
	definition.grade = int(entry.get("grade", entry.get("min_grade", 1)))
	definition.payload = entry.duplicate(true)
	return definition

func to_dictionary() -> Dictionary:
	return payload.duplicate(true)
