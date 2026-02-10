# Building OHOS HAP from Command Line

How to build an OpenHarmony/HarmonyOS HAP (Harmony Ability Package) from the command line using DevEco Studio’s bundled tools. This guide gives **exact bash commands**; you do not need any custom Gradle task.

For a reference implementation of the same flow in Gradle, see [kn_samples kotlinApp/build.gradle.kts around line 33](https://github.com/linhandev/kn_samples/blob/gcov/kotlinApp/build.gradle.kts#L33) (branch `gcov`). Your project may not have that task; the steps below are the equivalent you can run manually.

---

## Prerequisites

- **DevEco Studio** installed (e.g. `/Applications/DevEco-Studio.app` on macOS). All commands use the tools bundled inside it: **node**, **ohpm**, **hvigor**, **hdc** (see [hdc-commands.md](./hdc-commands.md)).
- Your **Harmony/OHOS app** project on disk (the directory that contains `AppScope/`, `entry/` or your module(s), `build-profile.json5`, `hvigorfile.ts`, `oh-package.json5`, etc.).
- If the app uses a **Kotlin/Native shared library**: build the `.so` and copy it (and any header) into the Harmony app’s expected paths **before** running the HAP build steps below. The commands here only build the HAP from the Harmony project.

---

## Variables to set

Set these for your environment (bash):

```bash
# DevEco Studio install directory (no trailing slash)
DEVECO_DIR="/Applications/DevEco-Studio.app"

# Absolute path to your Harmony app project root (where hvigorfile.ts and oh-package.json5 live)
HARMONY_APP_DIR="/path/to/your/harmonyApp"

# Build type: debug or release
BUILD_MODE="debug"

# Entry module name as used by hvigor (often "entry" with product "default" → entry@default)
ENTRY_MODULE="entry@default"
```

Optional, for install/launch:

```bash
# For "hdc install" and "aa start" (optional)
# HAP output subpath under entry module (see "HAP output location" below)
ENTRY_MODULE_DIR="entry"
```

---

## Step 1: Install OHPM dependencies

Run from the **Harmony app root** (`HARMONY_APP_DIR`). This installs dependencies declared in `oh-package.json5`.

```bash
cd "$HARMONY_APP_DIR"

export NODE_HOME="$DEVECO_DIR/Contents/tools/node"
export DEVECO_SDK_HOME="$DEVECO_DIR/Contents/sdk"
export PATH="$NODE_HOME/bin:$PATH"

"$DEVECO_DIR/Contents/tools/ohpm/bin/ohpm" install --all \
  --registry "https://ohpm.openharmony.cn/ohpm/" \
  --strict_ssl true
```

If this fails, fix the project’s `oh-package.json5` / registry access and retry.

---

## Step 2: Run hvigor sync

Still in `HARMONY_APP_DIR`. Sync and configure the build for the chosen product and build mode.

```bash
cd "$HARMONY_APP_DIR"

"$NODE_HOME/bin/node" "$DEVECO_DIR/Contents/tools/hvigor/bin/hvigorw.js" --sync \
  -p product=default \
  -p buildMode="$BUILD_MODE" \
  --analyze=false \
  --parallel \
  --incremental \
  --daemon
```

Use the same `buildMode` value as in Step 3. Adjust `product=default` if your project uses another product name.

---

## Step 3: Build the HAP

This is the step that actually produces the `.hap` file. Run in the **Harmony app root**.

```bash
cd "$HARMONY_APP_DIR"

"$NODE_HOME/bin/node" "$DEVECO_DIR/Contents/tools/hvigor/bin/hvigorw.js" --mode module \
  -p module="$ENTRY_MODULE" \
  -p product=default \
  -p buildMode="$BUILD_MODE" \
  -p requiredDeviceType=phone \
  assembleHap \
  --analyze=false \
  --parallel \
  --incremental \
  --daemon
```

- **module**: Usually `entry@default` for the default entry module; match your project’s module name.
- **product**: Usually `default`.
- **buildMode**: Must match Step 2 (`debug` or `release`).
- **requiredDeviceType**: `phone` is typical; change if targeting another device type.

On success, hvigor writes the HAP under the entry module’s build output (see below).

---

## Step 4 (optional): Install HAP to device

Connect the device, then install the HAP (HDC usage: [hdc-commands.md](./hdc-commands.md#app-install-and-launch)):

```bash
# Typical HAP output directory (entry module name "entry" and product "default")
HAP_DIR="$HARMONY_APP_DIR/$ENTRY_MODULE_DIR/build/default/outputs/default"

# Prefer signed HAP if present
if [ -f "$HAP_DIR/entry-default-signed.hap" ]; then
  HAP_FILE="$HAP_DIR/entry-default-signed.hap"
else
  HAP_FILE="$HAP_DIR/entry-default-unsigned.hap"
fi

if [ ! -f "$HAP_FILE" ]; then
  echo "HAP not found. Expected under: $HAP_DIR"
  exit 1
fi

"$DEVECO_DIR/Contents/sdk/default/openharmony/toolchains/hdc" install "$HAP_FILE"
```

Adjust `HAP_DIR` / `entry-default-*.hap` if your module or product name differs (e.g. different `build-profile.json5` or product flavor).

---

## Step 5 (optional): Launch the app on the device

After installing, start the ability (see [hdc-commands.md](./hdc-commands.md#app-install-and-launch)):

```bash
# Replace with your app’s bundle name and main ability name (e.g. from AppScope/app.json5 and module.json5)
BUNDLE_NAME="com.example.yourapp"
ABILITY_NAME="EntryAbility"

"$DEVECO_DIR/Contents/sdk/default/openharmony/toolchains/hdc" shell aa start \
  -a "$ABILITY_NAME" \
  -b "$BUNDLE_NAME"
```

You can copy `bundleName` from `AppScope/app.json5` and the ability name from your entry module’s `module.json5` or from DevEco Studio’s run configuration.

---

## HAP output location

After **Step 3**, the HAP is under the **entry module’s** build directory:

- **Directory**: `$HARMONY_APP_DIR/<entryModuleDir>/build/default/outputs/default/`
- **Filenames**:  
  - `entry-default-signed.hap` (if signing is configured in the project)  
  - `entry-default-unsigned.hap` (if not signing)

For a default setup with module name `entry` and product `default`, the path is:

```text
<HarmonyAppRoot>/entry/build/default/outputs/default/entry-default-unsigned.hap
```

(or `entry-default-signed.hap`). If your module or product name differs, the directory and file names will follow your build profile.

---

## Full script example (build HAP only)

Assumes variables are set as above. Runs Steps 1–3 only (no device install/launch).

```bash
set -e
cd "$HARMONY_APP_DIR"
export NODE_HOME="$DEVECO_DIR/Contents/tools/node"
export DEVECO_SDK_HOME="$DEVECO_DIR/Contents/sdk"
export PATH="$NODE_HOME/bin:$PATH"

echo "=== Step 1: OHPM install ==="
"$DEVECO_DIR/Contents/tools/ohpm/bin/ohpm" install --all \
  --registry "https://ohpm.openharmony.cn/ohpm/" --strict_ssl true

echo "=== Step 2: hvigor sync ==="
"$NODE_HOME/bin/node" "$DEVECO_DIR/Contents/tools/hvigor/bin/hvigorw.js" --sync \
  -p product=default -p buildMode="$BUILD_MODE" \
  --analyze=false --parallel --incremental --daemon

echo "=== Step 3: Build HAP ==="
"$NODE_HOME/bin/node" "$DEVECO_DIR/Contents/tools/hvigor/bin/hvigorw.js" --mode module \
  -p module="$ENTRY_MODULE" -p product=default -p buildMode="$BUILD_MODE" \
  -p requiredDeviceType=phone assembleHap \
  --analyze=false --parallel --incremental --daemon

echo "HAP output: $HARMONY_APP_DIR/$ENTRY_MODULE_DIR/build/default/outputs/default/"
```

---

## Summary

- You do **not** need the Gradle task from [kn_samples](https://github.com/linhandev/kn_samples/blob/gcov/kotlinApp/build.gradle.kts#L33); that script is only a reference for the same sequence.
- **Build HAP**: set `DEVECO_DIR`, `HARMONY_APP_DIR`, `BUILD_MODE`, `ENTRY_MODULE`, then run **Step 1** (ohpm install), **Step 2** (hvigor sync), **Step 3** (hvigor assembleHap). The HAP appears under the entry module’s `build/default/outputs/default/`.
- **Install/run**: use **Step 4** and **Step 5** with your bundle and ability names (commands in [hdc-commands.md](./hdc-commands.md)).
- If your app uses Kotlin/Native, build the shared library and copy the `.so` (and headers) into the Harmony project **before** running these steps.
