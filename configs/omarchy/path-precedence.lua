-- BEGIN ux8406ca-linux PATH override
-- Prefer user-local command overrides over Omarchy package commands.
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
