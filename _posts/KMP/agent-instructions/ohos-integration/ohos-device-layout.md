# OHOS Device Layout — Where to Find .so

Where system and app native .so live on OHOS. For deploy/run see [running-exe-on-ohos.md](./running-exe-on-ohos.md).

## System .so (ROM)

| Folder | Usage |
|--------|--------|
| `/system/lib64/` | Main system 64-bit native libs. |
| `/system/lib/` | 32-bit / legacy system libs. |
| `/system/lib64/chipset-pub-sdk/` | Chipset/public SDK. |
| `/system/lib64/chipset-sdk/`, `chipset-sdk-sp/` | Chipset SDK. |
| `/system/lib64/module/` | System modules (ability, app, arkui, bundle, security, telephony, window, hms, etc.). |
| `/system/lib64/appspawn/` | App spawn / nweb spawn. |
| `/system/lib64/ndk/` | NDK libs. |
| `/system/lib64/platformsdk/` | Platform SDK. |
| `/system/lib64/media/` | Media plugins. |
| `/system/lib64/init/` | Init/autorun, reboot. |
| `/system/lib64/` (other) | appdetailability, batteryplugin, drag_drop_ext, edm_plugin, expanded_menu, extensionability, graphics3d, imfplugin, migrate/plugins, multimodalinput, oem_certificate_service, powerplugin, seccomp, thermalplugin, updateext. |

Note: `/system/app/` has .hap only; native libs are under `/system/lib64/` or `/data/app/.../libs/arm64/`.

## Installed app .so

| Folder pattern | Usage |
|----------------|--------|
| `/data/app/el1/bundle/public/<bundle>/.../libs/arm64/` | System / preloaded app native libs. |
| `/data/app/el2/.../libs/arm64/` | User-installed app native libs (same pattern). |

App path mapping: [running-exe-on-ohos.md](./running-exe-on-ohos.md).

## Vendor .so

| Folder | Usage |
|--------|--------|
| `/vendor/lib64/` | Main vendor libs. |
| `/vendor/lib64/chipsetsdk/` | Chipset SDK (vendor). |
| `/vendor/lib64/hw/` | Hardware libs. |
| `/vendor/lib64/passthrough/`, `passthrough/indirect/` | Passthrough. |
| `/vendor/lib64/soundfx/` | Sound effects. |
| `/vendor/modem/modem_vendor/lib64/` | Modem vendor libs. |

## Related

- **Deploy/run and app paths:** [running-exe-on-ohos.md](./running-exe-on-ohos.md)
- **Compiler-rt / SDK libs (host):** [llvm-runtime-libraries.md](../kmp-foundations/llvm-runtime-libraries.md)
