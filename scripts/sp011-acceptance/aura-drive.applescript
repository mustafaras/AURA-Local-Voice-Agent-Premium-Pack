-- AURA acceptance driver.
--
-- Addresses controls by AXIdentifier rather than by position. Every earlier
-- SP-011 attempt drove the window as "button 3 of group 2 of group 1", which
-- selects the wrong control instead of failing whenever a row appears.
--
-- Usage:
--   osascript aura-drive.applescript window
--   osascript aura-drive.applescript find    <identifier>
--   osascript aura-drive.applescript click   <identifier>
--   osascript aura-drive.applescript settext <identifier> <text>
--   osascript aura-drive.applescript submit  <text>
--   osascript aura-drive.applescript transcript
--   osascript aura-drive.applescript status
--
-- Every command prints one line beginning with OK or ERR, so a caller can
-- branch without parsing prose.

-- Everything is bounded. System Events answers accessibility queries on the
-- target app's main thread, and a *miss* — an identifier that is not present —
-- costs a full subtree scan, measured at over a minute on the integrations
-- list. Unbounded, that hangs the run; bounded, it is a reported failure the
-- caller can act on.
property scanTimeout : 40
property scanLimit : 150

on run argv
	if (count of argv) < 1 then return "ERR usage"
	set cmd to item 1 of argv

	if cmd is "window" then return ensureWindow()

	set w to mainWindow()
	if w is missing value then return "ERR no-window"

	if cmd is "transcript" then return readTranscript(w)
	if cmd is "status" then return readStatus()

	if cmd is "submit" then
		if (count of argv) < 2 then return "ERR usage submit <text>"
		return submitRequest(w, item 2 of argv)
	end if

	if (count of argv) < 2 then return "ERR usage " & cmd & " <identifier>"
	set targetID to item 2 of argv
	set el to findByID(w, targetID, 0)
	if el is missing value then return "ERR not-found " & targetID

	if cmd is "find" then return "OK found " & targetID & " role=" & (my roleOf(el)) & " value=" & (my valueOf(el))
	if cmd is "click" then
		tell application "System Events" to perform action "AXPress" of el
		return "OK clicked " & targetID
	end if
	if cmd is "settext" then
		if (count of argv) < 3 then return "ERR usage settext <identifier> <text>"
		return setText(el, item 3 of argv)
	end if
	return "ERR unknown-command " & cmd
end run

-- The window is a `Window` scene, so the Window menu raises the existing one
-- rather than spawning a duplicate. This is deliberately not the menu bar
-- popover: the popover dismisses on focus loss, which is what repeatedly lost
-- the run when the operator touched the machine.
on ensureWindow()
	tell application "System Events"
		if not (exists process "AURA") then return "ERR aura-not-running"
		tell process "AURA"
			if (count of windows) > 0 then return "OK window-already-open"
			try
				set frontmost to true
				click menu item "AURA" of menu 1 of menu bar item "Window" of menu bar 1
			on error errText
				return "ERR cannot-open-window " & errText
			end try
		end tell
	end tell
	delay 0.6
	if mainWindow() is missing value then return "ERR window-did-not-appear"
	return "OK window-opened"
end ensureWindow

-- The menu bar item's title is the runtime status, and it is the cheapest
-- reliable signal that a turn has finished: it leaves Idle when the turn
-- starts and returns to Idle when the answer has been delivered. Watching the
-- transcript instead is wrong — it changes the moment the *user's* line is
-- appended, which is before the assistant has said anything.
on readStatus()
	tell application "System Events"
		if not (exists process "AURA") then return "ERR aura-not-running"
		tell process "AURA"
			try
				return "OK " & (name of menu bar item 1 of menu bar 2)
			on error
				return "ERR no-status-item"
			end try
		end tell
	end tell
end readStatus

on mainWindow()
	tell application "System Events"
		if not (exists process "AURA") then return missing value
		tell process "AURA"
			if (count of windows) is 0 then return missing value
			return window 1
		end tell
	end tell
end mainWindow

-- One `entire contents` call flattens the whole window in about 120 ms; the
-- scan then reads only AXIdentifier, and stops at the first match. The obvious
-- alternative — recursive descent reading role and value at every node — was
-- measured at 27 seconds on the integrations list, which is what made earlier
-- attempts report the automation bridge as "closed". It had not closed; it had
-- timed out.
on findByID(root, targetID, unusedDepth)
	with timeout of scanTimeout seconds
		tell application "System Events"
			set scanned to {}
			try
				set scanned to entire contents of root
			on error
				set scanned to {}
			end try
			-- `entire contents` intermittently returns an empty list for a
			-- window whose content is a SwiftUI lazy stack, even while the
			-- same window answers direct child queries. One retry after the
			-- tree settles turns that flake into a result rather than a false
			-- "not found", which would otherwise be indistinguishable from a
			-- control that genuinely is not on screen.
			if (count of scanned) is 0 then
				delay 0.8
				try
					set scanned to entire contents of root
				on error
					return missing value
				end try
			end if
			set n to 0
			repeat with e in scanned
				set n to n + 1
				-- A capped scan reports a miss instead of appearing to hang.
				-- The controls this harness addresses are all near the top of
				-- the tree; anything past the cap is a sign the identifier is
				-- wrong, not that the window is unusually deep.
				if n > scanLimit then return missing value
				try
					if (value of attribute "AXIdentifier" of e) is targetID then return e
				end try
			end repeat
		end tell
	end timeout
	-- `entire contents` is not dependable on this window: it has returned an
	-- empty list, and a truncated one, for a scroll area that answered direct
	-- child queries correctly at the same moment. The integrations list was
	-- visibly on screen while the flat scan reported its rows missing. Walking
	-- the children explicitly is slower but does not lie.
	return descendByID(root, targetID, 0)
end findByID

on descendByID(node, targetID, depth)
	if depth > 6 then return missing value
	tell application "System Events"
		try
			if (value of attribute "AXIdentifier" of node) is targetID then return node
		end try
		set kids to {}
		try
			set kids to UI elements of node
		on error
			return missing value
		end try
		repeat with child in kids
			set hit to my descendByID(child, targetID, depth + 1)
			if hit is not missing value then return hit
		end repeat
	end tell
	return missing value
end descendByID

on roleOf(el)
	tell application "System Events"
		try
			return (role of el) as string
		end try
	end tell
	return "?"
end roleOf

on valueOf(el)
	tell application "System Events"
		try
			set v to value of el
			if v is missing value then return ""
			return v as string
		end try
	end tell
	return ""
end valueOf

-- Sets the value directly and verifies it landed. SwiftUI's TextField is
-- AppKit-backed, so the AX write reaches the binding; the read-back is what
-- turns a silent no-op into a reported failure.
on setText(el, newText)
	tell application "System Events"
		try
			set focused of el to true
		end try
		try
			set value of el to newText
		end try
	end tell
	if valueOf(el) is newText then return "OK settext"
	-- Fall back to typing, for a field that refuses a direct AX write.
	tell application "System Events"
		try
			set focused of el to true
			keystroke newText
		end try
	end tell
	delay 0.3
	if valueOf(el) is newText then return "OK settext-typed"
	return "ERR settext-did-not-stick"
end setText

-- One request, end to end: fill the composer, press submit, and report. The
-- caller polls `transcript` for the answer rather than sleeping, because turn
-- latency here is dominated by a local model and is not predictable.
on submitRequest(w, requestText)
	set field to findByID(w, "aura.composer.input", 0)
	if field is missing value then return "ERR composer-not-found"
	set setResult to setText(field, requestText)
	if setResult starts with "ERR" then return setResult
	set submitButton to findByID(w, "aura.composer.submit", 0)
	if submitButton is missing value then return "ERR submit-not-found"
	tell application "System Events" to perform action "AXPress" of submitButton
	return "OK submitted"
end submitRequest

-- The transcript is a SwiftUI list inside a scroll area.
--
-- Read by explicit descent rather than `entire contents`. That call returns an
-- empty list for this subtree often enough to be useless — the scroll area was
-- observed reporting six message children while `entire contents` of the same
-- element returned nothing — and an empty transcript is indistinguishable from
-- "the assistant has not answered yet", which is exactly the confusion a run
-- must not make.
on readTranscript(w)
	set out to "OK transcript"
	tell application "System Events"
		tell process "AURA"
			try
				set sa to scroll area 1 of group 1 of w
				repeat with container in (UI elements of sa)
					repeat with node in (UI elements of container)
						set v to my valueOf(node)
						if v is not "" then set out to out & linefeed & v
						try
							repeat with leaf in (UI elements of node)
								set lv to my valueOf(leaf)
								if lv is not "" then set out to out & linefeed & lv
							end repeat
						end try
					end repeat
				end repeat
			on error errText
				return "ERR transcript " & errText
			end try
		end tell
	end tell
	return out
end readTranscript
