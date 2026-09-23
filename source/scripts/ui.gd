extends CanvasLayer
## Washi paper + sumi ink UI: HUD, strike call, fight ring, catch card
## (gyotaku print), journal and pool map.

var game
var head_font: Font
var body_font: Font
var washi: Texture2D
var root := Control.new()
var hud_pool: Label
var hud_sub: Label
var hud_count: Label
var hint: Label
var msg_jp: Label
var msg_en: Label
var strike: Label
var ring
var card: Control
var journal_panel: Control
var map_panel: Control
var title_panel: Control
var fader := ColorRect.new()
var btn_next: Button
const INK := Color(0.08, 0.07, 0.06)
const VERMILION := Color(0.78, 0.16, 0.1)
const PAPER := Color(0.95, 0.92, 0.85)

func setup(g) -> void:
	game = g
	head_font = load("res://fonts/head.ttf")
	body_font = load("res://fonts/body.ttf")
	washi = load("res://tex/washi.png")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	ring = FightRing.new()
	ring.ui = self
	ring.visible = false
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ring)
	_place(ring, 0.5, 1.0, -80, -230, 80, -70)
	fader.color = Color(0.93, 0.9, 0.83, 0.0)
	fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fader)

func _place(c: Control, ax: float, ay: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b

func paper_box(alpha := 0.94, border := true) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = washi
	sb.modulate_color = Color(1, 1, 1, alpha)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func lbl(text: String, font: Font, size: int, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func ink_button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", body_font)
	b.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = VERMILION if primary else Color(0.1, 0.09, 0.08, 0.88)
	sb.corner_radius_top_left = 2
	sb.corner_radius_bottom_right = 2
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	var sbh := sb.duplicate()
	sbh.bg_color = sb.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	return b

func _build_hud() -> void:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", paper_box(0.92))
	strip.position = Vector2(18, 16)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	hud_pool = lbl("", head_font, 30)
	hud_sub = lbl("", body_font, 14, Color(0.3, 0.27, 0.22))
	hud_count = lbl("", body_font, 16, VERMILION)
	v.add_child(hud_pool)
	v.add_child(hud_sub)
	v.add_child(hud_count)
	strip.add_child(v)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)
	var tr := HBoxContainer.new()
	_place(tr, 1.0, 0.0, -520, 18, -18, 60)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.alignment = BoxContainer.ALIGNMENT_END
	tr.add_theme_constant_override("separation", 10)
	var bj := ink_button("釣果帳  Journal")
	bj.pressed.connect(show_journal)
	btn_next = ink_button("淵を移る  Pools")
	btn_next.pressed.connect(show_map)
	tr.add_child(bj)
	tr.add_child(btn_next)
	root.add_child(tr)
	hint = lbl("", body_font, 20, PAPER)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(hint, 0.5, 1.0, -400, -50, 400, -16)
	root.add_child(hint)
	msg_jp = lbl("", head_font, 64, PAPER)
	msg_en = lbl("", body_font, 20, PAPER)
	for m in [msg_jp, msg_en]:
		m.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		m.add_theme_constant_override("shadow_offset_x", 2)
		m.add_theme_constant_override("shadow_offset_y", 2)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(m)
	_place(msg_jp, 0.5, 0.0, -400, 110, 400, 190)
	_place(msg_en, 0.5, 0.0, -400, 190, 400, 230)
	strike = lbl("掛かった！", head_font, 84, PAPER)
	strike.add_theme_color_override("font_outline_color", VERMILION)
	strike.add_theme_constant_override("outline_size", 10)
	strike.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(strike, 0.5, 0.5, -400, -170, 400, -50)
	strike.visible = false
	root.add_child(strike)

func on_pool(p: Dictionary, n: int, announce := true) -> void:
	hud_pool.text = p.kanji
	hud_sub.text = p.name
	hud_count.text = "釣果 %d / %d" % [n, int(p.goal)]
	if announce:
		set_hint("Tap the water to cast")
		flash_message(p.kanji, p.name)

func set_hint(t: String) -> void:
	hint.text = t

func flash_message(jp: String, en: String) -> void:
	msg_jp.text = jp
	msg_en.text = en
	for m in [msg_jp, msg_en]:
		m.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(1.6)
		tw.tween_property(m, "modulate:a", 0.0, 0.8)

func show_strike() -> void:
	strike.visible = true
	strike.scale = Vector2(1.3, 1.3)
	strike.pivot_offset = strike.size * 0.5
	var tw := create_tween()
	tw.tween_property(strike, "scale", Vector2.ONE, 0.15)
	set_hint("TAP NOW to set the hook")

func hide_strike() -> void:
	strike.visible = false

func show_fight(f: Dictionary) -> void:
	ring.visible = true
	ring.fight = f
	set_hint("Hold to reel  ·  let go when the line strains")

func update_fight(f: Dictionary) -> void:
	ring.fight = f
	ring.queue_redraw()

func hide_fight() -> void:
	ring.visible = false

func fade(out: bool) -> Signal:
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0 if out else 0.0, 0.7)
	return tw.finished

func _modal(w: float, h: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", paper_box(0.98))
	p.custom_minimum_size = Vector2(w, h)
	root.add_child(p)
	_place(p, 0.5, 0.5, -w * 0.5, -h * 0.5, w * 0.5, h * 0.5)
	return p

# ---------------------------------------------------------------- title
func show_title() -> void:
	title_panel = Control.new()
	title_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_panel.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", paper_box(0.97))
	_place(p, 0.5, 0.5, -330, -210, 330, 210)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	var big := lbl("翠\n渓", head_font, 96)
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(big)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(lbl("SUIKEI", head_font, 40))
	v.add_child(lbl("clear stream angler", body_font, 18, Color(0.35, 0.3, 0.25)))
	var steps := lbl("一  Tap the water to cast your float.\n二  When the float dives, tap to set the hook.\n三  Hold to reel. Let go when the line strains.\n四  Land it, log it, release it. Then move upstream.", body_font, 17)
	v.add_child(steps)
	var b := ink_button("釣りに出る   Start fishing", true)
	b.pressed.connect(func():
		title_panel.queue_free()
		game.start_audio()
		game.state = game.G.IDLE)
	v.add_child(b)
	h.add_child(v)
	p.add_child(h)
	title_panel.add_child(p)
	root.add_child(title_panel)
	game.state = game.G.TITLE

# ---------------------------------------------------------------- catch card
func show_card(c: Dictionary) -> void:
	card = Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", paper_box(0.99))
	_place(p, 0.5, 0.5, -330, -150, 330, 190)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g := Gyotaku.new()
	g.sp = c.sp
	g.custom_minimum_size = Vector2(430, 150)
	left.add_child(g)
	var sz := HBoxContainer.new()
	sz.add_child(lbl("%.1f" % c.cm, head_font, 58))
	var unit := lbl(" cm", body_font, 22)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	sz.add_child(unit)
	left.add_child(sz)
	var sub: String = c.sp.name + "  ·  " + c.sp.en
	left.add_child(lbl(sub, body_font, 15, Color(0.35, 0.3, 0.25)))
	var note := lbl(c.sp.note, body_font, 15)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.custom_minimum_size = Vector2(430, 0)
	left.add_child(note)
	var tag := ""
	if c.first:
		tag = "初釣果  First of its kind"
	elif c.record:
		tag = "記録更新  New record (was %.1f cm)" % c.prev
	if tag != "":
		left.add_child(lbl(tag, body_font, 16, VERMILION))
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	var rb := ink_button("放流する  Release", true)
	rb.pressed.connect(func():
		card.queue_free()
		game.release_and_continue())
	brow.add_child(rb)
	if c.unlocked:
		var nb := ink_button("次の淵へ  Next pool")
		nb.pressed.connect(func():
			card.queue_free()
			game.release_and_continue()
			game.travel(game.pool_idx + 1))
		brow.add_child(nb)
	left.add_child(brow)
	h.add_child(left)
	var right := VBoxContainer.new()
	var name_v := lbl(_vertical(c.sp.kanji), head_font, 46)
	right.add_child(name_v)
	right.add_child(lbl(_vertical(c.sp.kana), body_font, 16, Color(0.35, 0.3, 0.25)))
	h.add_child(right)
	p.add_child(h)
	card.add_child(p)
	if c.first or c.record:
		var st := Hanko.new()
		st.text = "記録" if c.record else "初"
		st.font = head_font
		_place(st, 0.5, 0.5, -372, -196, -282, -106)
		st.rotation = -0.12
		card.add_child(st)
	card.modulate.a = 0.0
	root.add_child(card)
	create_tween().tween_property(card, "modulate:a", 1.0, 0.35)
	set_hint("")

func _vertical(s: String) -> String:
	var out := ""
	for i in s.length():
		out += s[i] + ("\n" if i < s.length() - 1 else "")
	return out

# ---------------------------------------------------------------- journal
func show_journal() -> void:
	if journal_panel and is_instance_valid(journal_panel):
		journal_panel.queue_free()
		return
	var p := _modal(640, 440)
	journal_panel = p
	var v := VBoxContainer.new()
	v.add_child(lbl("釣果帳  Catch Journal", head_font, 30))
	v.add_child(lbl("Total landed: %d" % int(game.journal.total), body_font, 15, Color(0.35, 0.3, 0.25)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	for id in game.species:
		var sd: Dictionary = game.species[id]
		var n := int(game.journal.count.get(id, 0))
		if n > 0:
			grid.add_child(lbl(sd.kanji + "  " + sd.name, body_font, 18))
			grid.add_child(lbl("× %d" % n, body_font, 18))
			grid.add_child(lbl("best %.1f cm" % float(game.journal.best.get(id, 0.0)), body_font, 18, VERMILION))
		else:
			grid.add_child(lbl("？？？", body_font, 18, Color(0.5, 0.46, 0.4)))
			grid.add_child(lbl("", body_font, 18))
			grid.add_child(lbl("not yet seen", body_font, 15, Color(0.5, 0.46, 0.4)))
	v.add_child(grid)
	var close := ink_button("閉じる  Close")
	close.pressed.connect(func(): p.queue_free())
	v.add_child(close)
	p.add_child(v)

func show_map() -> void:
	if map_panel and is_instance_valid(map_panel):
		map_panel.queue_free()
		return
	var p := _modal(560, 380)
	map_panel = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(lbl("淵を移る  Move pools", head_font, 30))
	for i in game.pools.size():
		var pl: Dictionary = game.pools[i]
		var open: bool = i < int(game.journal.unlocked)
		var t: String = "%s  %s   (%d/%d)" % [pl.kanji, pl.name, game._pool_count(pl.id), int(pl.goal)] if open else "？？？  land %d fish upstream to reach" % int(game.pools[i - 1].goal)
		var b := ink_button(t, i == game.pool_idx)
		b.disabled = not open
		b.pressed.connect(func():
			p.queue_free()
			if i != game.pool_idx:
				game.travel(i))
		v.add_child(b)
	var close := ink_button("閉じる  Close")
	close.pressed.connect(func(): p.queue_free())
	v.add_child(close)
	p.add_child(v)

# ================================================================ drawn widgets
class FightRing extends Control:
	var ui
	var fight := {}
	func _draw() -> void:
		if fight.is_empty():
			return
		var c := size * 0.5
		var R := 70.0
		draw_circle(c, R + 8, Color(0.95, 0.92, 0.85, 0.9))
		# brush ring (time left): overlapping jittered arcs
		var frac: float = clamp(fight.time / fight.max_time, 0.0, 1.0)
		var a0 := -PI * 0.5
		for k in 4:
			var j := k * 0.9
			draw_arc(c + Vector2(sin(k * 1.7), cos(k * 2.3)) * 0.8, R - 4 + j, a0, a0 + TAU * frac, 72, Color(0.08, 0.07, 0.06, 0.55), 5.0 - k, true)
		# tension (inner, vermilion)
		var t: float = clamp(fight.tension, 0.0, 1.0)
		var tc := Color(0.78, 0.16, 0.1).lerp(Color(1.0, 0.1, 0.05), t)
		draw_arc(c, R - 18, PI * 0.75, PI * 0.75 + PI * 1.5 * t, 48, tc, 8.0, true)
		draw_arc(c, R - 18, PI * 0.75, PI * 2.25, 48, Color(0.08, 0.07, 0.06, 0.15), 8.0, true)
		# progress (reel in): dots
		var n := 10
		for i in n:
			var on: bool = fight.progress > float(i) / n
			var ang := PI * 0.75 + PI * 1.5 * float(i) / (n - 1)
			draw_circle(c + Vector2(cos(ang), sin(ang)) * (R - 34), 3.2, Color(0.08, 0.07, 0.06, 0.9 if on else 0.18))
		var s := "%.1f" % max(fight.time, 0.0)
		var f: Font = ui.head_font
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(f, c + Vector2(-w * 0.5, 10), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.08, 0.07, 0.06))
		var lab := "張力" if t > 0.75 else "巻く"
		var w2: float = ui.body_font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(ui.body_font, c + Vector2(-w2 * 0.5, 32), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tc if t > 0.75 else Color(0.3, 0.27, 0.22))

class Gyotaku extends Control:
	## Fish-print (gyotaku) drawn from the species body plan and markings.
	var sp: Dictionary
	func _draw() -> void:
		var L := size.x * 0.86
		var ox := size.x * 0.05
		var cy := size.y * 0.5
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		var N := 40
		var fat := 0.19 if sp.name != "Ayu" else 0.16
		for i in N + 1:
			var t := float(i) / N
			var h := L * fat * pow(sin(PI * pow(t, 0.62)), 0.9) * (1.0 - 0.5 * t)
			if t > 0.86:
				h = lerp(h, L * 0.02, (t - 0.86) / 0.14)
			top.append(Vector2(ox + t * L * 0.86, cy - h * 0.55))
			bot.append(Vector2(ox + t * L * 0.86, cy + h * 0.45))
		var body := PackedVector2Array()
		body.append_array(top)
		var rb := bot.duplicate()
		rb.reverse()
		body.append_array(rb)
		var ink := Color(0.07, 0.065, 0.06, 0.92)
		# tail
		var tx := ox + L * 0.86
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 6, cy - 3), Vector2(tx + L * 0.13, cy - L * 0.1), Vector2(tx + L * 0.08, cy), Vector2(tx + L * 0.13, cy + L * 0.09), Vector2(tx - 6, cy + 3)]), ink)
		# dorsal, adipose, anal, pectoral
		draw_colored_polygon(PackedVector2Array([Vector2(ox + L * 0.36, cy - L * 0.1), Vector2(ox + L * 0.43, cy - L * 0.17), Vector2(ox + L * 0.5, cy - L * 0.09)]), ink)
		draw_colored_polygon(PackedVector2Array([Vector2(ox + L * 0.6, cy + L * 0.07), Vector2(ox + L * 0.64, cy + L * 0.12), Vector2(ox + L * 0.7, cy + L * 0.06)]), ink)
		draw_colored_polygon(body, ink)
		# print texture: scale rows lifted out as paper-colored arcs
		var paper := Color(0.95, 0.92, 0.85, 0.35)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(sp.name)
		for row in range(-3, 4):
			for i in 26:
				var x := ox + L * (0.18 + i * 0.025)
				var y := cy + row * L * 0.018
				if Geometry2D.is_point_in_polygon(Vector2(x, y), body):
					draw_arc(Vector2(x, y), L * 0.012, -PI * 0.5, PI * 0.5, 6, paper, 1.0)
		# lateral line
		draw_line(Vector2(ox + L * 0.16, cy - L * 0.01), Vector2(ox + L * 0.84, cy), Color(0.95, 0.92, 0.85, 0.5), 1.2)
		var lk: Dictionary = sp.look
		if float(lk.parr) > 0.5:
			for i in 8:
				var x := ox + L * (0.24 + i * 0.075)
				draw_set_transform(Vector2(x, cy), 0, Vector2(0.55, 1.0))
				draw_circle(Vector2.ZERO, L * 0.022, Color(0.0, 0.0, 0.0, 0.55))
				draw_set_transform(Vector2.ZERO)
		if float(lk.spots) > 0.3:
			var light: bool = lk.spot[0] > 0.5
			for i in 34:
				var p := Vector2(ox + L * rng.randf_range(0.14, 0.82), cy + L * rng.randf_range(-0.09, 0.05))
				if Geometry2D.is_point_in_polygon(p, body):
					draw_circle(p, L * rng.randf_range(0.004, 0.008), Color(0.95, 0.92, 0.85, 0.7) if light else Color(0, 0, 0, 0.6))
		if float(lk.red_spots) > 0.5:
			for i in 14:
				var p := Vector2(ox + L * rng.randf_range(0.2, 0.8), cy + L * rng.randf_range(-0.02, 0.03))
				draw_circle(p, L * 0.006, Color(0.8, 0.18, 0.1, 0.95))
		if float(lk.band) > 0.5:
			draw_line(Vector2(ox + L * 0.12, cy), Vector2(ox + L * 0.84, cy + 1), Color(0.78, 0.16, 0.1, 0.55) if lk.accent[0] > 0.5 else Color(0, 0, 0, 0.7), L * 0.016)
		if float(lk.yellow) > 0.5:
			draw_circle(Vector2(ox + L * 0.26, cy - L * 0.01), L * 0.018, Color(0.9, 0.72, 0.15, 0.9))
		# eye: paper ring + ink pupil
		var eye := Vector2(ox + L * 0.06, cy - L * 0.02)
		draw_circle(eye, L * 0.017, Color(0.95, 0.92, 0.85))
		draw_circle(eye, L * 0.009, Color(0.05, 0.05, 0.05))
		# gill line
		draw_arc(Vector2(ox + L * 0.1, cy), L * 0.06, -PI * 0.45, PI * 0.45, 10, Color(0.95, 0.92, 0.85, 0.45), 1.5)

class Hanko extends Control:
	var text := "記録"
	var font: Font
	func _draw() -> void:
		var r := Rect2(Vector2(6, 6), size - Vector2(12, 12))
		var red := Color(0.78, 0.13, 0.08, 0.88)
		draw_rect(r, red, false, 5.0)
		draw_rect(r.grow(-7), red, false, 1.5)
		var fs := 34 if text.length() > 1 else 50
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(size.x * 0.5 - w * 0.5, size.y * 0.5 + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, red)
