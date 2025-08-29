local ww = require("waywall")
local helpers = require("waywall.helpers")
local create_floating = require("floating.floating")
local Scene = require("waywork.scene")
local Modes = require("waywork.modes")
local Keys = require("waywork.keys")

-- === theme and constants ===
local bg_col, primary_col, secondary_col = "#000000", "#ec6e4e", "#E446C4"
local ninbot_anchor, ninbot_opacity = "topright", 1
local java_path = "/usr/lib/jvm/java-24-openjdk/bin/java"
local pacem_path = "/home/seangle/apps/paceman-tracker/paceman-tracker.jar"
local nb_path = "/home/seangle/apps/ninjabrain-bot/ninjabrain-bot.jar"
local overlay_path = "/home/seangle/games/mcsr/resources/measuring_overlay.png"

local base_sens = 6.6666668
local tall_sens = 0.44973

-- === waywall config ===
local config = {
	input = {
		layout = "us",
		repeat_rate = 40,
		repeat_delay = 300,
		remaps = {},
		sensitivity = base_sens,
		confine_pointer = true,
	},
	theme = { background = bg_col, ninb_anchor = ninbot_anchor, ninb_opacity = ninbot_opacity },
	experimental = { debug = false, jit = false, tearing = false, scene_add_text = true },
}

-- === floating controller ===
local floating = create_floating({
	show_floating = ww.show_floating,
	sleep = ww.sleep,
})

-- === scene registry ===
local scene = Scene.SceneManager.new(ww)

-- Thin layout mirrors
scene:register("e_counter", {
	kind = "mirror",
	options = { src = { x = 1, y = 37, w = 49, h = 9 }, dst = { x = 1150, y = 300, w = 196, h = 36 } },
	groups = { "thin", "e_counter" },
})
scene:register("thin_pie_all", {
	kind = "mirror",
	options = { src = { x = 11, y = 680, w = 318, h = 170 }, dst = { x = 1150, y = 500, w = 318, h = 325 } },
	groups = { "thin" },
})
scene:register("thin_percent_all", {
	kind = "mirror",
	options = { src = { x = 248, y = 860, w = 82, h = 24 }, dst = { x = 1150, y = 850, w = 492, h = 144 } },
	groups = { "thin" },
})

-- Tall layout mirrors
scene:register("tall_pie_all", {
	kind = "mirror",
	options = { src = { x = 54, y = 15984, w = 320, h = 170 }, dst = { x = 1250, y = 500, w = 315, h = 317 } },
	groups = { "tall" },
})
scene:register("tall_percent_all", {
	kind = "mirror",
	options = { src = { x = 292, y = 16164, w = 32, h = 24 }, dst = { x = 1300, y = 850, w = 198, h = 150 } },
	groups = { "tall" },
})

-- Boat-eye zoom
scene:register("eye_measure", {
	kind = "mirror",
	options = { src = { x = 162, y = 7902, w = 60, h = 580 }, dst = { x = 30, y = 340, w = 700, h = 400 } },
	groups = { "tall", "tall_eye" },
})

-- Overlay image above eye mirror
scene:register("eye_overlay", {
	kind = "image",
	path = overlay_path,
	options = { dst = { x = 30, y = 340, w = 700, h = 400 }, depth = 999 },
	groups = { "tall", "tall_eye" },
})

-- === modes (resolutions + hooks) ===
local ModeManager = Modes.ModeManager.new(ww)

ModeManager:define("thin", {
	width = 340,
	height = 1080,
	on_enter = function()
		-- i.e. enable all scene objects that have the "thin" group assigned
		scene:enable_group("thin", true)
	end,
	on_exit = function()
		scene:enable_group("thin", false)
	end,
})

-- Tall mode has a guard to prevent accidental toggles during gamemode switches
ModeManager:define("tall", {
	width = 384,
	height = 16384,
	toggle_guard = function()
		return not ww.get_key("F3")
	end,
	on_enter = function()
		scene:enable_group("tall", true)
		ww.set_sensitivity(tall_sens)
	end,
	on_exit = function()
		scene:enable_group("tall", false)
		ww.set_sensitivity(0)
	end,
})

ModeManager:define("wide", {
	width = 1920,
	height = 300,
})

-- === external tools ===
local function ensure_paceman()
	local h = io.popen("pgrep -f " .. pacem_path)
	local live = h and h:read("*l")
	if h then
		h:close()
	end
	if not live then
		ww.exec(java_path .. " -jar " .. pacem_path .. " --nogui")
	end
end
local function ensure_ninjabrain()
	local h = io.popen("pgrep -f " .. nb_path)
	local live = h and h:read("*l")
	if h then
		h:close()
	end
	if not live then
		ww.exec(java_path .. " -Dawt.useSystemAAFontSettings=on -jar " .. nb_path)
	end
end

-- === keybinds ===
local actions = Keys.actions({
	["*-Alt_L"] = function()
		return ModeManager:toggle("thin")
	end,
	["*-F4"] = function()
		return ModeManager:toggle("tall")
	end,
	["*-Shift-V"] = function()
		return ModeManager:toggle("wide")
	end,

	["Ctrl-E"] = function()
		ww.press_key("ESC")
	end,
	["Ctrl-W"] = function()
		ww.press_key("BACKSPACE")
	end,

	["Ctrl-Shift-O"] = ww.toggle_fullscreen,

	["Ctrl-Shift-P"] = function()
		ensure_ninjabrain()
		ensure_paceman()
	end,

	["*-C"] = function()
		if ww.get_key("F3") then
			ww.press_key("C")
			floating.show()
			floating.hide_after_timeout(10000)
		else
			return false
		end
	end,

	["*-Ctrl-B"] = function()
		floating.override_toggle()
	end,
})

config.actions = actions

return config
