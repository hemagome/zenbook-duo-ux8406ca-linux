-- BEGIN ux8406ca-linux keyboard-dock
-- Follow the UX8406CA pogo-pin keyboard state for the lower display.
o.launch_on_start((os.getenv("HOME") or "") .. "/.local/bin/ux8406ca-keyboard-dock")
-- END ux8406ca-linux keyboard-dock
