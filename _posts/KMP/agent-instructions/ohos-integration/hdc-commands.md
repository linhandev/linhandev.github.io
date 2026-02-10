# HDC commands

Single reference for HDC (OHOS Device Connector). Other docs use HDC and link here. Path: `$DEVECO_DIR/Contents/sdk/default/openharmony/toolchains/hdc` (e.g. `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`).

**Important:** `hdc shell <command>` always exits 0 from HDC's perspective. If the inner command fails, HDC still returns 0. Do not rely on exit code of `hdc shell ...` to detect command failure.

## Service and targets

- `hdc list targets` — list connected devices
- `hdc kill` — kill HDC server
- `hdc start` — start HDC server (e.g. after kill if stuck)
- `hdc -t <device-id> <command>` — run on device (id from list targets)
- `hdc std -t <device-id> <command>` — same, when multiple devices

## Moving files

- `hdc file send <local_path> <device_path>`
- `hdc file recv <device_path> <local_path>`

## Shell

- `hdc shell <command>` — run command on device (exit code not propagated; see top of doc)
- `hdc shell uname -a` — system info including architecture (aarch64 / x86_64)
- `hdc shell chmod <mode> <path>` — e.g. chmod 777 for execute

## HiLog

- `hdc shell hilog -T <TAG> -x` — stream logs for tag only; -x excludes other tags
- `hdc shell hilog -T <TAG> -x -r` — -r: recent/ring buffer (e.g. show recent logs)
- Example: `hdc shell hilog -T CAPI_TEST -x -r`

## Device properties (param)

- `hdc shell param get <key>`
- `hdc shell param get const.ohos.apiversion` — API level
- `hdc shell param get const.product.devicetype` — device type: pc, 2in1, phone, tv, etc.

## App management

- `hdc install <path_to.hap>` — install HAP
- `hdc uninstall -n <bundle_name>` — uninstall app by bundle name
- `hdc shell aa start -a <ability_name> -b <bundle_name>` — start ability
- `hdc shell aa forcestop -b <bundle_name>` — force stop app by bundle name

Example start: `hdc shell aa start -a EntryAbility -b com.example.yourapp`

## Quick reference (command only)

- hdc list targets
- hdc shell uname -a
- hdc shell param get const.ohos.apiversion
- hdc shell param get const.product.devicetype
- hdc shell hilog -T <TAG> -x
- hdc shell hilog -T <TAG> -x -r
- hdc file send <local> <device_path>
- hdc file recv <device_path> <local>
- hdc shell <command>
- hdc install <hap_file>
- hdc uninstall -n <bundle_name>
- hdc shell aa start -a <ability> -b <bundle>
- hdc shell aa forcestop -b <bundle_name>
