-- BEGIN ux8406ca-linux fn-mode
-- Reapply the selected UX8406CA keyboard Fn mode after USB attachment.
o.launch_on_start((os.getenv("HOME") or "") .. "/.local/bin/ux8406ca-fn-mode --watch")
-- END ux8406ca-linux fn-mode
