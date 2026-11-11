-- ============================================================================
-- HARPOON FOR MACOS
-- ============================================================================
-- Hyper + ]          Add focused window
-- Hyper + [          Open/close WebView picker
-- Hyper + A -> 1-5   Jump to window slot
-- Hyper + D -> 1-5   Delete specific slot
-- Hyper + -          Remove focused window
-- Hyper + Delete     Clear all slots
-- Ctrl + Alt + W     Open native Window menu
--
-- Modules:
-- harpoon/core.lua     Slot management and window jumping
-- harpoon/picker.lua   WebView lifecycle and Lua callbacks
-- harpoon/picker.html  HTML, CSS and keyboard interaction
-- ============================================================================

local core = require("harpoon.core")
local picker = require("harpoon.picker")

local hyper = core.hyper

-- ============================================================================
-- 1. LEADER MODES
-- ============================================================================

-- Modal that waits for a slot number, then calls onSlot(slotKey).
-- Exits on escape/space or after `timeout` seconds.
local function slotLeader(onSlot, timeout)
	local modal = hs.hotkey.modal.new()
	local timer = nil

	local function exit()
		if timer then
			timer:stop()
			timer = nil
		end

		modal:exit()
	end

	for i = 1, core.maxSlots do
		local slotKey = tostring(i)

		modal:bind({}, slotKey, function()
			exit()
			onSlot(slotKey)
		end)
	end

	modal:bind({}, "escape", exit)
	modal:bind({}, "space", exit)

	function modal:entered()
		if timer then
			timer:stop()
		end

		timer = hs.timer.doAfter(timeout, function()
			timer = nil
			modal:exit()
		end)
	end

	return modal
end

local jumpModal = slotLeader(core.focusSlot, 1.5)
local deleteModal = slotLeader(core.deleteSlot, 2)

-- ============================================================================
-- 2. HARPOON HOTKEYS
-- ============================================================================

hs.hotkey.bind(hyper, "]", core.addFocusedWindow)

hs.hotkey.bind(hyper, "[", picker.toggle)

hs.hotkey.bind(hyper, "a", function()
	core.showToast("󰛢 Harpoon Jump: Press [1-5]", 1)

	jumpModal:enter()
end)

hs.hotkey.bind(hyper, "d", function()
	core.showToast("🗑️ Delete Slot: Press [1-5]", 1)

	deleteModal:enter()
end)

hs.hotkey.bind(hyper, "-", core.removeFocusedWindow)

hs.hotkey.bind(hyper, "delete", function()
	core.clearSlots()
	picker.close()
end)

-- ============================================================================
-- 3. NATIVE MACOS WINDOW MENU (Ctrl + Alt + W)
-- ============================================================================

hs.hotkey.bind({ "ctrl", "alt" }, "w", function()
	local app = hs.application.frontmostApplication()

	if not app then
		return
	end

	app:selectMenuItem({ "Window" })

	hs.timer.doAfter(0.1, function()
		hs.eventtap.keyStroke({}, "end")
	end)
end)
