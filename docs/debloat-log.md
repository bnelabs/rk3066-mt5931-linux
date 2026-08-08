# Debloat Log

Preference: keep the Logitech keyboard app (`com.logitech.keyboard.look_ten`), YouTube, fonts, and Rockchip's file manager. Remove everything else removable.

Backup location: `~/workspace/tvstick_backup/` (APKs + package list).

## Removed

| Package | Type | Notes |
|---|---|---|
| `com.adobe.flashplayer` | data | Flash Player |
| `com.tudou.vod` | data | Puhu TV (Chinese video) |
| `com.tcl.ott` (etc.) | data | Turkcell OTT |
| `com.rockchip.rkGameControlSetting` | system | RK game controller settings |
| `com.rockchip.eHomeMediaCenter_box` | system | DLNA/media center |
| `com.rockchip.wifidisplay` | system | Wi-Fi Display (Miracast sender) |
| `com.rockchip.rkwiMoRcTx` | system | RK WiMo remote |
| `com.rockchip.rkvideo` / RkVideoPlayer | system | RK video player |
| `com.rockchip.rkupdate` / RKUpdateService | system | OTA updater |
| `com.media.floatwindow` / MediaFloat | system | floating media window |

Also deleted from sdcard: `LuckyPatcher` and `Aptoide` directories (pre-installed junk / tool of concern).

## Kept

- `com.logitech.keyboard.look_ten` — Logitech Keyboard (user's explicit requirement)
- `com.google.android.youtube` — YouTube
- `com.mobisystems.fonts` — fonts
- `com.android.rockchip` — RkExplorer file manager

## Verification

- `pm list packages -3` after removal shows only YouTube, Logitech keyboard, fonts.
- Memory: MemFree ~205 MB → ~488 MB after debloat.
- /data free: ~450 MB → ~576 MB.
- Clean boot verified after each removal step.
- `/system` remount was flaky → resolved by rebooting then retrying; MediaFloat removed successfully after a fresh boot.

## Restore

All removed APKs are preserved in `~/workspace/tvstick_backup/apks/`. To restore:

```sh
adb push <apk> /data/local/tmp/
adb shell pm install -r /data/local/tmp/<apk>
```
