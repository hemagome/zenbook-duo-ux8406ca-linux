# Detachable Bluetooth keyboard

The tested keyboard appears as `ASUS Zenbook Duo Keyboard` and works through
BlueZ without a kernel or repository workaround.

Interactive pairing procedure:

```text
bluetoothctl
power on
agent KeyboardDisplay
default-agent
scan on
pair XX:XX:XX:XX:XX:XX
trust XX:XX:XX:XX:XX:XX
scan off
```

Confirm with `info XX:XX:XX:XX:XX:XX`. A healthy saved connection reports:

```text
Paired: yes
Bonded: yes
Trusted: yes
Connected: yes
WakeAllowed: yes
```

Never publish the real Bluetooth address. Pairing data is managed by BlueZ and
is intentionally not copied by this repository or its installer.

If reconnection fails, first check `systemctl status bluetooth` and
`bluetoothctl info …`; do not delete the bond until simpler reconnect and power
cycle tests have failed.
