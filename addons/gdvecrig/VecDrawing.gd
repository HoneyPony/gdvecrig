@tool
extends Node2D
class_name VecDrawing

@export var cyclic: bool = false

@export var fill: Color = Color.WHITE
@export_range(1, 256) var steps: int = 10

@export var outline_color: Color = Color.BLACK
@export var outline_base_width: float = 2.5

var waypoints = [VecWaypoint]
var strokes = [VecStroke]

func collect_children():
	waypoints.clear()
	strokes.clear()
	for child in get_children():
		if child is VecWaypoint:
			waypoints.push_back(child)
		if child is VecStroke:
			strokes.push_back(child)
	

func get_waypoint(index):
	return waypoints[index]
	
func waypoint_count():
	return waypoints.size()

func get_plugin() -> GDVecRig:
	return Engine.get_singleton("GDVecRig")

func is_currently_edited():
	var vr: GDVecRig = Engine.get_singleton("GDVecRig")
	return vr.current_vecdrawing == self
	
func edit_point(index: int, offset: Vector2):
	if index < 0 or index >= waypoint_count():
		return
	get_waypoint(index).value += offset
	
func try_starting_editing(plugin: GDVecRig):
	if plugin.point_highlight >= 0:
		plugin.point_edited = true
		if not plugin.point_selection.has(plugin.point_highlight):
			# Clear the selection we we're selecitng a new point
			plugin.point_selection.clear()
			add_to_select(plugin, plugin.point_highlight)
	
func stop_editing(plugin: GDVecRig):
	plugin.point_edited = false
	
func add_to_select(plugin: GDVecRig, point: int):
	if not plugin.point_selection.has(point):
		plugin.point_selection.push_back(point)
	
func add_to_select_from_target(plugin: GDVecRig, target: Vector2):
	var radius = 5 / zoom()
	
	for i in range(0, waypoint_count()):
		var center = get_waypoint(i).value
		if (target - center).length_squared() <= (radius * radius):
			add_to_select(plugin, i)
	
func is_selected(index):
	return get_plugin().point_selection.has(index)
	
func zoom():
	#print(get_viewport().get_screen_transform())
	#return 1.0
	return get_viewport().get_screen_transform().get_scale().x
	#return get_viewport().get_camera_2d().zoom.x

func edit_input(plugin: GDVecRig, event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if plugin.point_edited:
			for point in plugin.point_selection:
			#print(event.relative / zoom())
				edit_point(point, event.relative / zoom())
			#queue_redraw()
			return true
		else:
			var previous_highlight = plugin.point_highlight
			
			var radius = 5 / zoom()
			plugin.point_highlight = -1
			
			for i in range(0, waypoint_count()):
				var center = get_waypoint(i).value
				if (get_local_mouse_position() - center).length_squared() <= (radius * radius):
					plugin.point_highlight = i
					break
				
			if previous_highlight != plugin.point_highlight:
				pass
				#queue_redraw()
				
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.get_modifiers_mask() & KEY_MASK_SHIFT:
					add_to_select_from_target(plugin, get_local_mouse_position())
					return true
				else:
					try_starting_editing(plugin)
					return true
			else:
				stop_editing(plugin)
				
	return false

func _ready():
	collect_children()
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Engine.is_editor_hint():
		# Always collect waypoints while being edited.
		collect_children()
	queue_redraw()	
#	if Engine.is_editor_hint():
#		print("e")
#		queue_redraw()
	
func compute(p0, p1, p2, p3, t):
	var zt = 1 - t
	return \
		(zt * zt * zt * p0) + \
		(3 * zt * zt * t * p1) + \
		(3 * zt * t * t * p2) + \
		(t * t * t * p3);
	
func draw_editor_handle(radius, left, mid, right, ls, ms, rs):
	draw_line(left, mid, Color.WHITE)
	draw_line(mid, right, Color.WHITE)
	
	draw_circle(left, radius * 0.9, Color.BLUE if ls else Color.WHITE)
	draw_circle(mid, radius, Color.BLUE if ms else Color.GRAY)
	draw_circle(right, radius * 0.9, Color.BLUE if rs else Color.WHITE)
	
	
func draw_line_width(points: PackedVector2Array, width: PackedVector2Array):
	pass
	
func _draw():
	var computed_points: PackedVector2Array = PackedVector2Array()

	# < - > < - >
	# 0 1 2 3 4 5
	#   0 1 2 3
	# (i + 3) <= length -> gives us two handles + two control points

	var i = 1
	while (i + 3) <= waypoint_count():
		var p0 = get_waypoint(i).value
		var p1 = get_waypoint(i + 1).value
		var p2 = get_waypoint(i + 2).value
		var p3 = get_waypoint(i + 3).value
		
		for j in range(0, steps):
			var t = j / float(steps - 1)
			computed_points.push_back(compute(p0, p1, p2, p3, t))
		i += 3
		
	if cyclic:
		if waypoint_count() >= 6:
			var end = waypoint_count() - 2
			var p0 = get_waypoint(end + 0).value
			var p1 = get_waypoint(end + 1).value
			var p2 = get_waypoint(0).value
			var p3 = get_waypoint(1).value
			for j in range(0, steps):
				var t = j / float(steps - 1)
				computed_points.push_back(compute(p0, p1, p2, p3, t))
			
	draw_colored_polygon(computed_points, fill)
	for stroke in strokes:
		stroke.points = computed_points
	
	if Engine.is_editor_hint():
		var radius = 5 / zoom()
		var plugin: GDVecRig = get_plugin()
	
		if is_currently_edited():
			i = 0
			while (i + 2) <= waypoint_count():
				var p0 = get_waypoint(i).value
				var p0s = is_selected(i)
				var p1 = get_waypoint(i + 1).value
				var p1s = is_selected(i + 1)
				var p2 = get_waypoint(i + 2).value
				var p2s = is_selected(i + 2)
				draw_editor_handle(radius, p0, p1, p2, p0s, p1s, p2s)
				
				i += 3
						
		
