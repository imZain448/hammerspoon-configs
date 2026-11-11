-- ============================================================================
-- HARPOON CORE
-- ============================================================================
-- Slot management, window resolution and the toast HUD.
-- ============================================================================

local M = {
	slots = {},
	maxSlots = 5,
	hyper = { "cmd", "alt", "ctrl", "shift" },
}

-- ============================================================================
-- 1. TOAST HUD
-- ============================================================================

local toastCanvas = nil
local toastTimer = nil

local function countLines(text)
	local count = 1

	for _ in string.gmatch(text, "\n") do
		count = count + 1
	end

	return count
end

local function closeToast()
	if toastTimer then
		toastTimer:stop()
		toastTimer = nil
	end

	if toastCanvas then
		toastCanvas:delete()
		toastCanvas = nil
	end
end

function M.showToast(msg, duration)
	duration = duration or 1.5

	closeToast()

	local screen = hs.screen.mainScreen():frame()

	local width = 420
	local lineCount = countLines(msg)
	local lineHeight = 23
	local verticalPadding = 32

	local height = math.max(70, lineCount * lineHeight + verticalPadding)

	local x = screen.x + (screen.w - width) / 2
	local y = screen.y + screen.h * 0.14

	toastCanvas = hs.canvas.new({
		x = x,
		y = y,
		w = width,
		h = height,
	})

	toastCanvas:level(hs.canvas.windowLevels.overlay)

	toastCanvas:behavior({
		hs.canvas.windowBehaviors.canJoinAllSpaces,
		hs.canvas.windowBehaviors.stationary,
	})

	toastCanvas:alpha(0.82)

	-- Shadow
	toastCanvas[1] = {
		type = "rectangle",
		action = "fill",

		frame = {
			x = 5,
			y = 7,
			w = width - 10,
			h = height - 10,
		},

		fillColor = {
			white = 0,
			alpha = 0.30,
		},

		roundedRectRadii = {
			xRadius = 16,
			yRadius = 16,
		},
	}

	-- Background
	toastCanvas[2] = {
		type = "rectangle",
		action = "fill",

		frame = {
			x = 5,
			y = 3,
			w = width - 10,
			h = height - 10,
		},

		fillColor = {
			red = 0.08,
			green = 0.08,
			blue = 0.10,
			alpha = 1.0,
		},

		roundedRectRadii = {
			xRadius = 16,
			yRadius = 16,
		},
	}

	-- Border
	toastCanvas[3] = {
		type = "rectangle",
		action = "stroke",

		frame = {
			x = 5,
			y = 3,
			w = width - 10,
			h = height - 10,
		},

		strokeColor = {
			white = 1,
			alpha = 0.20,
		},

		strokeWidth = 1,

		roundedRectRadii = {
			xRadius = 16,
			yRadius = 16,
		},
	}

	-- Text
	toastCanvas[4] = {
		type = "text",
		text = msg,

		frame = {
			x = 24,
			y = 16,
			w = width - 48,
			h = height - 28,
		},

		textColor = {
			white = 0.95,
			alpha = 1,
		},

		textSize = 15,
		textFont = ".AppleSystemUIFont",
		textAlignment = "left",
	}

	toastCanvas:show()

	toastTimer = hs.timer.doAfter(duration, function()
		closeToast()
	end)
end

local showToast = M.showToast

-- ============================================================================
-- 2. WINDOW RESOLUTION
-- ============================================================================

-- Resolve the exact saved window, falling back to app/title lookup.

local function resolveWindow(slot)
	if not slot then
		return nil
	end

	-- First attempt: window ID
	local win = hs.window.get(slot.windowId)

	if win then
		return win
	end

	-- Second attempt: application and title
	if not slot.bundle then
		return nil
	end

	local app = hs.application.get(slot.bundle)

	if not app then
		return nil
	end

	win = app:findWindow(slot.title)

	if win then
		slot.windowId = win:id()
	end

	return win
end

function M.focusSlot(slotKey)
	local slot = M.slots[tostring(slotKey)]

	if not slot then
		showToast("⚠️ Harpoon slot [" .. tostring(slotKey) .. "] is empty")
		return
	end

	local win = resolveWindow(slot)

	if win then
		if win:isMinimized() then
			win:unminimize()
		end

		win:focus()
	else
		showToast("⚠️ Window not found:\n" .. slot.name .. " — " .. slot.title)
	end
end

-- ============================================================================
-- 3. SLOT MANAGEMENT
-- ============================================================================

function M.addFocusedWindow()
	local win = hs.window.frontmostWindow()

	if not win then
		showToast("❌ No focused window found")
		return
	end

	local app = win:application()

	if not app then
		showToast("❌ Could not resolve application")
		return
	end

	local windowId = win:id()

	if not windowId then
		showToast("❌ Could not resolve window ID")
		return
	end

	local appName = app:name()
	local appBundle = app:bundleID()
	local windowTitle = win:title()

	-- Prevent duplicate windows
	for slotKey, item in pairs(M.slots) do
		if item.windowId == windowId then
			showToast("󰛢 Already in Slot [" .. slotKey .. "]: " .. appName .. " — " .. windowTitle)
			return
		end
	end

	-- Find first available slot
	local targetSlot = nil

	for i = 1, M.maxSlots do
		local key = tostring(i)

		if not M.slots[key] then
			targetSlot = key
			break
		end
	end

	-- All slots full: overwrite slot 1
	if not targetSlot then
		targetSlot = "1"
	end

	M.slots[targetSlot] = {
		name = appName,
		title = windowTitle,
		bundle = appBundle,
		windowId = windowId,
	}

	showToast("󰛢 Harpooned [" .. targetSlot .. "]: " .. appName .. "\n" .. windowTitle)
end

function M.removeFocusedWindow()
	local win = hs.window.frontmostWindow()

	if not win then
		return
	end

	local windowId = win:id()

	for slotKey, item in pairs(M.slots) do
		if item.windowId == windowId then
			M.slots[slotKey] = nil

			showToast("🗑️ Removed [" .. item.name .. " — " .. item.title .. "] from Slot [" .. slotKey .. "]")

			return
		end
	end

	showToast("⚠️ This window is not in Harpoon")
end

function M.deleteSlot(slotKey)
	local slot = M.slots[slotKey]

	if slot then
		M.slots[slotKey] = nil

		showToast("🗑️ Removed Slot [" .. slotKey .. "]: " .. slot.name)
	else
		showToast("⚠️ Slot [" .. slotKey .. "] is already empty")
	end
end

function M.clearSlots()
	M.slots = {}

	showToast("🧹 Cleared all Harpoon slots!")
end

-- Filled slots in order, as plain data for the picker.
function M.getChoices()
	local choices = {}

	for i = 1, M.maxSlots do
		local key = tostring(i)
		local slot = M.slots[key]

		if slot then
			table.insert(choices, {
				slot = key,
				name = slot.name,
				title = slot.title,
			})
		end
	end

	return choices
end

return M
