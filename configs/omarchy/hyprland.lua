-- Sanitized reference copy of the tested ~/.config/hypr/hyprland.lua.
-- The installer does not replace a user's whole file; it adds only the marked
-- PATH block below when the brightness workaround is selected.

dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

require("default.hypr.omarchy")
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
require("default.hypr.toggles")

-- BEGIN ux8406ca-linux PATH override
local user_bin = os.getenv("HOME") .. "/.local/bin"
local omarchy_bin = "/usr/share/omarchy/bin"
local kept = {}

for entry in (os.getenv("PATH") or "/usr/local/bin:/usr/bin"):gmatch("[^:]+") do
    if entry ~= user_bin and entry ~= omarchy_bin then
        table.insert(kept, entry)
    end
end

table.insert(kept, 1, omarchy_bin)
table.insert(kept, 1, user_bin)

hl.env("PATH", table.concat(kept, ":"))
-- END ux8406ca-linux PATH override
