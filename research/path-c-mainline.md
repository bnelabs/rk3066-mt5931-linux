# Path C Research — Porting the MediaTek MT5931 SDIO WiFi driver to mainline Linux

**Target device:** RK3066 Android TV stick, dual-core Cortex-A9, 857MB RAM, WiFi = MediaTek MT5931 (SDIO `037a:5931`), BT = MT6622.
**Driver source under study:** `/tmp/MTK5931/wifi/mtk_5931/` and `/tmp/Linux3188/drivers/net/wireless/mt5931/` (2013-era MediaTek vendor driver, written against a 3.0.x kernel — the MT6620/MT5931 combo driver lineage).
**Date:** 2026-08-08

---

## 1. Is MT5931 supported in mainline Linux?

**No.** Verified directly against the current `torvalds/linux` master tree (GitHub API tree dump, saved at `/tmp/torvalds_tree.json`):

- `drivers/net/wireless/mediatek/` contains only: `Kconfig`, `Makefile`, `mt76/`, `mt7601u/`. That's it.
- A full-tree scan found zero paths matching `mt5931`, `mt6620`, `mt6628`, or `mtk_wcn` in the entire mainline tree.

There is **no mainline driver for MT5931** (SDIO) or for any of its siblings (MT6620 combo, MT6628). The chip exists only in vendor trees and the old Android/Picuntu kernels that shipped the box.

---

## 2. Relationship to mt76 (and mt7601u)

`mt76` is a **completely different driver project** — MediaTek's modern full-MAC/soft-MAC family for USB/PCIe chips. From the official supported-chip list (wireless.docs.kernel.org):

> MT7610U, MT7612, MT7602, MT7662, MT7630E, MT7610E, MT7603E, MT7628, MT7615, MT7622, MT7663, MT7915/16, MT7986, MT7921/22, MT7996, MT7925, MT7992

- **MT5931 is not in the list.** MT5931 (and MT6620/MT6628) are old **802.11n full-MAC SDIO** chips from ~2011-2013 that share the "MT66xx" WCN combo hardware lineage, not the mt76 architecture.
- `mt7601u` covers only the USB MT7601U — irrelevant.
- There is also **no rt2x00/rt73 relationship** (those are Ralink chips; MT5931 is MediaTek).
- The 2013-era driver in the current codebase is a monolithic "glue + FW-owned MAC" design (full-MAC), structurally unrelated to mt76. It cannot be "folded into" mt76 without writing a brand-new driver.

**Conclusion:** no reusable mainline driver exists; porting means resurrecting the vendor driver (or writing from scratch).

---

## 3. What breaks on modern kernels — API comparison (3.0.x → 6.x)

The driver was written against the 3.0-era cfg80211 API. Concrete, verified breakages:

### cfg80211_ops signature changes (driver table at `os/linux/gl_init.c:841`)

| Op | Driver's old signature (3.0-era) | Modern mainline signature | Break |
|---|---|---|---|
| `change_virtual_intf` | `(wiphy, ndev, type, u32 *flags, vif_params*)` | `(wiphy, ndev, type, vif_params*)` | `flags` param removed (3.6) |
| `add_key` / `del_key` | `(wiphy, ndev, key_index, pairwise, mac_addr, key_params*)` | `(wiphy, wdev, link_id, key_index, pairwise, mac_addr, key_params*)` | `ndev`→`wdev`, `link_id` added (6.1 MLO) |
| `get_key` | driver provides `get_key`? uses ndev | `(wiphy, wdev, link_id, key_index, pairwise, mac_addr, cookie, callback)` | async cookie API + link_id |
| `get_station` | `(wiphy, ndev, mac, station_info*)` | `(wiphy, wdev, mac, station_info*)` | `ndev`→`wdev` (6.0/6.1) |
| `scan` | `(wiphy, ndev, cfg80211_scan_request*)` | `(wiphy, cfg80211_scan_request*)` | `ndev` param removed (3.9) |
| `connect` | `(wiphy, ndev, cfg80211_connect_params*)` | same-ish, but struct fields changed | `cfg80211_connect_params` shape changed |
| `disconnect` | `(wiphy, ndev, reason_code)` | `(wiphy, ndev, reason_code)` | ok, minor |
| `join_ibss`/`leave_ibss` | `(wiphy, ndev, cfg80211_ibss_params*)` | `(wiphy, ndev, ...)` same | struct fields changed |
| `set_pmksa`/`del_pmksa`/`flush_pmksa` | `(wiphy, ndev, cfg80211_pmksa*)` | `(wiphy, netdev, cfg80211_pmksa*)` | mostly ok |
| `remain_on_channel` | `(wiphy, wdev, chan, duration, cookie*)` | `(wiphy, wdev, chan, duration, cookie*, rx_addr)` | `rx_addr` param added (6.x) |
| `mgmt_tx` | `(wiphy, ndev, channel, offscan, channel_type, channel_type_valid, wait, buf, len, no_cck, dont_wait_for_ack, cookie*)` — **13 positional args, 3.0-era** | `(wiphy, wdev, cfg80211_mgmt_tx_params*, cookie*)` | **completely rewritten** in 3.5; driver stub at `gl_cfg80211.c:1336` returns `-EINVAL` anyway |
| `set_power_mgmt` | `(wiphy, ndev, enabled, timeout)` | `(wiphy, ndev, enabled, timeout)` | ok |
| `testmode_cmd` | `(wiphy, data, len)` | `(wiphy, wdev, data, len)` | `wdev` added |
| `set_monitor_channel` | absent (uses `channel_type` legacy) | `(wiphy, dev, cfg80211_chan_def*)` | driver never had it; needed for monitor |
| `reg_notifier` | driver has none registered | modern cfg80211 expects wiphy with `regulatory` mgmt | missing |
| `wiphy_new` | old `(size, n_regulatory)` | `(size, n_regulatory)` still fine, but wiphy features (`WIPHY_FLAG_*`) renamed | minor |

`enum nl80211_channel_type` (driver uses at `gl_cfg80211.c:1272,1341`) is **legacy/deprecated** in modern cfg80211; monitor paths now use `cfg80211_chan_def`.

### net_device / netdev_ops changes
- Driver registers `ndo_do_ioctl` (`gl_init.c:2056`) — **removed in 5.14/5.15**, split into `ndo_siocdevprivate` + `ndo_eth_ioctl`. Must be split.
- `alloc_netdev_mq()` (`gl_init.c:2148`): modern signature adds `name_assign_type` as 5th arg (since 3.17). Driver calls the 4-arg form. Compile error.
- `register_netdev` / `alloc_netdev_mq` return path: fine otherwise.
- `wireless_handlers` and `wiphy->wext` assignments (`gl_init.c:2161,2213`) still exist in mainline (WEXT compat retained), so the wireless-extensions fallback still compiles — but `CONFIG_CFG80211_WEXT` must be enabled and wext is deprecated.

### Firmware loading — **hard breakage**
- `kalFirmwareOpen()` (`gl_kal.c:778-853`) uses `filp_open("/etc/firmware/WIFI_RAM_CODE", ...)` + `set_fs(get_ds())`.
- **`set_fs()`/`get_fs()` were removed in kernel 5.10** (LWN 832121). Must be rewritten to use `request_firmware()` + firmware API or `kernel_read()` from a mounted fs.
- Firmware file: `WIFI_RAM_CODE` (139,776 bytes) is present at `/tmp/Linux3188/drivers/net/wireless/mt5931/firmware_5931/WIFI_RAM_CODE`.

### SDIO subsystem — largely OK
- `MTK_WCN_HIF_SDIO` is `0` in `config.h:888-896` for **all** Linux builds, so the compiled path is plain `struct sdio_driver` (`sdio.c:219-236`) using `sdio_register_driver`, `sdio_set_block_size`, `sdio_claim_irq`, `sdio_claim_host`, `sdio_enable_func` — **all still present in modern kernels**. Good news: the WCN-client path (`mtk_wcn_hif_sdio_client_reg`) is *not* needed.
- Device ID `SDIO_DEVICE(0x037a, 0x5931)`, function 1, block 512 (`sdio.c:197-236`) — matches the stick's lspci/lsusb-visible ID.

### Misc 3.x-era APIs used
- `CONFIG_HAS_EARLYSUSPEND` / `struct early_suspend` (`gl_p2p_init.c`) — Android-only, gone from mainline; must be `#if`-off.
- `CONFIG_ANDROID` guards (`gl_os.h:506-525`).
- 802.11d / spec mgmt / RRM `CFG_SUPPORT_*` compile flags are mostly off.

---

## 4. Full-MAC issue: monitor mode / packet injection

MT5931 is a **full-MAC chip** — the firmware owns the MAC, management frames, and most of the datapath. Consequences verified in the driver:

- `mgmt_tx` is a **stub returning `-EINVAL`** ("not implemented", `gl_cfg80211.c:1360`).
- `change_virtual_intf` only handles `NL80211_IFTYPE_STATION` and `ADHOC` (`gl_cfg80211.c:149-156`) — **no MONITOR, no AP support in the cfg80211 glue** (AP/P2P exist in a separate P2P module `gl_p2p.c`).
- No `set_monitor_channel`, no monitor RX path.

The chip firmware cannot be reprogrammed without MediaTek firmware engineering; the vendor driver was never able to do monitor/injection. **Realistic verdict: monitor mode and packet injection are effectively infeasible on this hardware through this driver.** This is a hard limitation of the full-MAC design, not just a porting problem.

---

## 5. Community efforts / existing porting work

- **No active upstream effort exists.** linux-wireless, linux-mediatek patchwork, and the mainline tree have no MT5931/MT6620 work.
- Historical references found:
  - `https://github.com/Galland/MTK5931` — 2013-era vendor driver mirror.
  - `https://github.com/aloksinha2001/picuntu-3.0.8-alok/issues/2` — Picuntu (RK3066) users on 3.0.8 discussing MT5931 WiFi, 2013-2015.
  - `https://github.com/MediaTek-Connectivity/mt6620` — upstream-ish staging repo of the MT6620 combo driver (`drivers/mtk_wcn_combo`), never merged.
  - `drivers/mtk_wcn_combo` exists in the 3.0.36 tree at `/tmp/Linux3188/` (companion BT/FM driver providing `mtk_wcn_hif_sdio_*`).
  - RevSpace `KernelDriverProjects` lists "Mediatek mt6620 wifi/bluetooth driver" as a known sunxi WIP item.
- **No one has ported this driver to a 5.x/6.x mainline kernel** and published it.

---

## 6. Verdict + person-month estimate

**Feasible but labor-intensive, and only for a minimal STA/AP subset; monitor/injection is out.**

Estimated effort for a competent Linux kernel developer familiar with cfg80211:

| Task | Effort |
|---|---|
| Fix cfg80211_ops signatures (20+ callbacks) | 2-4 weeks |
| Split `ndo_do_ioctl`, fix `alloc_netdev_mq`, compile-clean on 6.x | 1-2 weeks |
| Rewrite firmware loading (set_fs → request_firmware/kernel_read) | 1 week |
| SDIO init/clock/regulator bring-up on RK3066 (likely power sequencing pain) | 1-4 weeks |
| Live debugging (firmware boot, scan/connect on 2.4GHz) | 2-6 weeks |
| **Total** | **~2-4 person-months** for working STA mode |

Risks that could blow the estimate:
1. Firmware/host interaction assumptions baked into a 12-year-old 3.0.8-era stack.
2. SDIO power/clock sequencing on the RK3066 board (vendor kernels often needed regulator tweaks).
3. cfg80211 scan-request/station-info struct field drift (`cfg80211_scan_request`, `station_info` changed repeatedly through 4.x-6.x).
4. WEXT path is a crutch but deprecated; nL80211 must be the real path.

**Alternative recommendation:** if the only goal is working WiFi on this box, an SDIO/USB adapter backed by an in-tree driver (e.g. brcmfmac/rtw88/mt7601u USB) is dramatically cheaper. If the hardware's SDIO controller and the 037a:5931 chip must be used, the 2-4 person-month port is the honest estimate — and skip any monitor-mode expectations.

---

## Sources

- Local driver sources: `/tmp/MTK5931/wifi/mtk_5931/`, `/tmp/Linux3188/drivers/net/wireless/mt5931/`
- Modern header diff (fetched from torvalds/linux master): `/tmp/cfg80211_master.h`, `/tmp/netdevice_master.h`
- Mainline tree dump: `/tmp/torvalds_tree.json`
- mt76 chip list: https://wireless.docs.kernel.org/en/latest/en/users/drivers/mediatek.html
- set_fs removal: https://lwn.net/Articles/832121/
- Monitor-mode reference: https://gengstah.github.io/wiki/concepts/monitor-mode-injection
- References: https://github.com/Galland/MTK5931 , https://github.com/aloksinha2001/picuntu-3.0.8-alok/issues/2 , https://github.com/MediaTek-Connectivity/mt6620 , https://revspace.nl/KernelDriverProjects , https://patchwork.kernel.org/project/linux-mediatek/
