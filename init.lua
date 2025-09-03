local waywall = require("waywall")
local helpers = require("waywall.helpers")
local create_floating = require("floating.floating")
local Scene = require("waywork.scene")
local Modes = require("waywork.modes")
local Keys = require("waywork.keys")
local Processes = require("waywork.processes")

-- === theme and constants ===
local bg_col, primary_col, secondary_col = "#000000", "#ec6e4e", "#E446C4"
local ninbot_anchor, ninbot_opacity = "topright", 1
local java_path = "/usr/lib/jvm/java-24-openjdk/bin/java" -- for jars like ninbot
local paceman_path = "/home/seangle/apps/paceman-tracker/paceman-tracker.jar"
local ninbot_path = "/home/seangle/apps/ninjabrain-bot/ninjabrain-bot.jar"
local wayboard_path = "/home/seangle/.local/bin/wayboard-esensats"
local wayboard_cfg = "/home/seangle/.config/wayboard/example.cfg"
local enable_wayboard = false
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
		confine_pointer = false,
	},
	theme = { background = bg_col, ninb_anchor = ninbot_anchor, ninb_opacity = ninbot_opacity },
	experimental = { debug = false, jit = false, tearing = false, scene_add_text = true },
}

-- === floating controller ===
local floating = create_floating({
	show_floating = waywall.show_floating,
	sleep = waywall.sleep,
})

-- === scene registry ===
local scene = Scene.SceneManager.new(waywall)

-- == thin layout mirrors ==

scene:register("e_counter", {
	kind = "mirror",
	options = { src = { x = 1, y = 37, w = 49, h = 9 }, dst = { x = 1150, y = 300, w = 196, h = 36 } },
	groups = { "thin" },
})
scene:register("thin_pie_all", {
	kind = "mirror",
	options = { src = { x = 10, y = 680, w = 320, h = 170 }, dst = { x = 1150, y = 500, w = 320, h = 325 } },
	groups = { "thin" },
})

--- Thin group, left side percentages dimensions
local tpld = { w = 32, h = 24 }
scene:register("thin_percent_left", {
	kind = "mirror",
	options = {
		src = { x = 248, y = 860, w = tpld.w, h = tpld.h },
		dst = { x = 1150, y = 850, w = tpld.w * 6, h = tpld.h * 6 },
	},
	groups = { "thin" },
})

--- Thin group, right side percentages dimensions
local tprd = { w = 26, h = 24 }
scene:register("thin_percent_right", {
	kind = "mirror",
	options = {
		src = { x = 304, y = 860, w = tprd.w, h = tprd.h },
		dst = { x = 1150 + tpld.w * 6 + 20, y = 850, w = tprd.w * 6, h = tprd.h * 6 },
	},
	groups = { "thin" },
})

-- == tall layout mirrors ==

scene:register("tall_e_counter", {
	kind = "mirror",
	options = { src = { x = 1, y = 37, w = 49, h = 9 }, dst = { x = 1170, y = 300, w = 196, h = 36 } },
	groups = { "tall" },
})
scene:register("tall_pie_all", {
	kind = "mirror",
	options = { src = { x = 54, y = 15984, w = 320, h = 170 }, dst = { x = 1170, y = 500, w = 320, h = 325 } },
	groups = { "tall" },
})

--- Tall percent left side dimensions
local tapld = { w = 32, h = 24 }
scene:register("tall_percent_left", {
	kind = "mirror",
	options = {
		src = { x = 292, y = 16164, w = tapld.w, h = tapld.h },
		dst = { x = 1170, y = 850, w = tapld.w * 6, h = tapld.h * 6 },
	},
	groups = { "tall" },
})

--- Tall percent right side dimensions
local taprd = { w = 26, h = 24 }
scene:register("tall_percent_right", {
	kind = "mirror",
	options = {
		src = { x = 348, y = 16164, w = taprd.w, h = taprd.h },
		dst = { x = 1170 + tapld.w * 6 + 20, y = 850, w = taprd.w * 6, h = taprd.h * 6 },
	},
	groups = { "tall" },
})

-- Boat-eye zoom
scene:register("eye_measure", {
	kind = "mirror",
	options = { src = { x = 162, y = 7902, w = 60, h = 580 }, dst = { x = 30, y = 340, w = 700, h = 400 } },
	groups = { "tall" },
})

-- Overlay image above eye mirror
scene:register("eye_overlay", {
	kind = "image",
	path = overlay_path,
	options = { dst = { x = 30, y = 340, w = 700, h = 400 }, depth = 999 },
	groups = { "tall" },
})

-- === modes (resolutions + hooks) ===
local mode_manager = Modes.ModeManager.new(waywall)

mode_manager:define("thin", {
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
mode_manager:define("tall", {
	width = 384,
	height = 16384,
	toggle_guard = function()
		return not waywall.get_key("F3")
	end,
	on_enter = function()
		scene:enable_group("tall", true)
		waywall.set_sensitivity(tall_sens)
	end,
	on_exit = function()
		scene:enable_group("tall", false)
		waywall.set_sensitivity(0)
	end,
})

mode_manager:define("wide", {
	width = 1920,
	height = 300,
})

local ensure_wayboard = Processes.ensure_application(waywall, wayboard_path, { wayboard_cfg })(wayboard_path)
local ensure_ninjabrain =
	Processes.ensure_java_jar(waywall, java_path, ninbot_path, { "-Dawt.useSystemAAFontSettings=on" })(ninbot_path)
local ensure_paceman = Processes.ensure_java_jar(waywall, java_path, paceman_path, { "--nogui" })(paceman_path)

-- temp
local function kill_wayboard()
	waywall.exec("pkill -f wayboard-esensats")
end

-- === keybinds ===
local actions = Keys.actions({
	["*-Alt_L"] = function()
		return mode_manager:toggle("thin")
	end,
	["*-F4"] = function()
		return mode_manager:toggle("tall")
	end,
	["*-Shift-V"] = function()
		return mode_manager:toggle("wide")
	end,

	["Ctrl-E"] = function()
		waywall.press_key("ESC")
	end,
	["Ctrl-W"] = function()
		waywall.press_key("BACKSPACE")
	end,

	["Ctrl-Shift-O"] = waywall.toggle_fullscreen,

	["Ctrl-Shift-K"] = function()
		if enable_wayboard then
			kill_wayboard()
		end
	end, -- temp

	["Ctrl-Shift-P"] = function()
		ensure_ninjabrain()
		ensure_paceman()
		if enable_wayboard then
			ensure_wayboard()
		end
	end,

	["*-C"] = function()
		if waywall.get_key("F3") then
			waywall.press_key("C")
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
