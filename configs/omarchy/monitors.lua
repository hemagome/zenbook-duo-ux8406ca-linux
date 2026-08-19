-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = omarchy_monitor_scale
})

-- ASUS Zenbook Duo UX8406CA: upper display
hl.monitor({
    output = "eDP-1",
    mode = "2880x1800@120",
    position = "0x0",
    scale = 2
})

-- ASUS Zenbook Duo UX8406CA: lower display
hl.monitor({
    output = "eDP-2",
    mode = "2880x1800@120",
    position = "0x900",
    scale = 2
})
