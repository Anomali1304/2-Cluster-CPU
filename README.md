<div align="center">

# Rock Project

**Kernel build pipeline and out-of-tree addon framework for Xiaomi POCO M5 (rock), MediaTek MT6789.**

[![Build](https://img.shields.io/github/actions/workflow/status/Anomali1304/Rock_Project/build.yml?style=for-the-badge&logo=githubactions&logoColor=white&labelColor=222)](https://github.com/Anomali1304/Rock_Project/actions/workflows/build.yml)
[![Latest release](https://img.shields.io/badge/version-1.0.0-informational?style=for-the-badge&logo=github&logoColor=white&labelColor=222)](CHANGELOG.md)
[![Kernel](https://img.shields.io/badge/kernel-5.10-informational?style=for-the-badge&logoColor=white&labelColor=222)](docs/ARCHITECTURE.md)
[![License](https://img.shields.io/badge/license-GPL--2.0-informational?style=for-the-badge&logo=gnu&logoColor=white&labelColor=222)](LICENSE)

</div>

Rock Project builds Xiaomi's `android_kernel_xiaomi_rock` tree for the POCO M5 (`rock`, MT6789/Helio G99) and can build optional out-of-tree kernel modules from `addons/` against the exact kernel build.

## Why not just clone and build manually?

The GKI manifest, the Xiaomi tree, root patches, and vendor modules don't line up cleanly out of the box. `build/build.sh` overrides `CLANG_PREBUILT_BIN` and the build user/host regardless of what you export, XClang needs a `libxml2.so.16` symlink to even run, and SUSFS has to be patched in separately from KernelSU-Next's `dev-susfs` fork. This pipeline used to be an interactive script run by hand on a build server; it's now a set of numbered stages so the same steps run the same way every time, locally or in CI.

## Features

- Builds the Xiaomi `android_kernel_xiaomi_rock` tree without manual GKI manifest surgery
- Root integration: Vanilla, KernelSU-Next, or ReSukiSU, with optional SUSFS
- Out-of-tree addon framework, drop a directory in `addons/` and it's part of the build
- Vendor MTK, in-tree GKI, and addon `.ko` files all packaged together per run
- Every option is an env var, defaults live in `config/defaults.env`
- Runs the same locally or through a GitHub Actions `workflow_dispatch`

## Supported Root Solutions

- [Vanilla](kernel/root/vanilla)
- [KernelSU-Next](kernel/root/ksun)
- [ReSukiSU](kernel/root/resukisu)

## Quick Start

```bash
./build.sh

ADDONS=overclock_mt6789 ROOT_TYPE=KSUN ./build.sh

MODULES_FILTER=gpufreq ./build.sh

RUN_MODE="Dry Run" ./build.sh
```

All build options are environment variables. Defaults are defined in [`config/defaults.env`](config/defaults.env).

## Repository Layout

```text
Rock-Project/
├── build.sh
├── config/
│   └── defaults.env
├── lib/
│   ├── functions.sh
│   └── paths.sh
├── stages/
│   ├── 00-deps.sh
│   ├── 10-download.sh
│   ├── 15-clang-vendor.sh
│   ├── 20-branding.sh
│   ├── 30-core.sh
│   ├── 40-root-variant.sh
│   ├── 50-addons-stage.sh
│   ├── 60-build-kernel.sh
│   ├── 70-addons-compile.sh
│   └── 80-release.sh
├── kernel/
│   ├── core/
│   └── root/
├── addons/
│   └── overclock_mt6789/
├── release/
├── docs/
├── .github/workflows/build.yml
├── CHANGELOG.md
├── LICENSE
└── VERSION
```

## Pipeline

| Stage | Responsibility |
|---|---|
| `00-deps` | Host dependencies and `repo` launcher |
| `10-download` | GKI tooling, Xiaomi kernel source, optional vendor modules |
| `15-clang-vendor` | GKI, ZyC, or custom Clang selection |
| `20-branding` | Kernel version and build identity |
| `30-core` | LTO and size/debug configuration |
| `40-root-variant` | Root integration |
| `50-addons-stage` | Validate and stage enabled addons |
| `60-build-kernel` | Kernel compilation |
| `70-addons-compile` | Compile staged addons against the completed kernel |
| `80-release` | Build release archives |

`RUN_MODE="Dry Run"` stops after the kernel build stage. The normal run continues through addon compilation and packaging.

## Outputs

Artifacts are written to `release-out/`.

| Output | Condition | Contents |
|---|---|---|
| `<prefix><root>.zip` | Always | AnyKernel3 package containing the kernel image |
| `<prefix><root>-addons.zip` | `ADDONS` set and modules built | Enabled addon `.ko` files |
| `<prefix><root>-modules.zip` | At least one `.ko` built | Vendor, GKI, and addon `.ko` files; optionally filtered by `MODULES_FILTER` |

The kernel image package does not contain `.ko` files.

## Configuration

| Variable | Default | Values / purpose |
|---|---|---|
| `KERNEL_NAME` | `RockKernel` | `CONFIG_LOCALVERSION` suffix |
| `ZIP_PREFIX` | `Rock-Kernel` | Release filename prefix |
| `BUILD_USER_NAME` | `MaL` | Kernel build user |
| `BUILD_HOST_NAME` | `1304` | Kernel build host |
| `KERNEL_REPO` | Xiaomi kernel repo | Kernel source |
| `KERNEL_BRANCH` | `android12-5.10` | Kernel source branch |
| `GKI_MANIFEST_BRANCH` | `common-android12-5.10-lts` | GKI tooling manifest |
| `VENDOR_MODULES_REPO` | MTK modules repo | External vendor modules |
| `VENDOR_MODULES_BRANCH` | `rock-u-oss` | Vendor module branch |
| `USE_EXT_MODULES` | `y` | Build external vendor modules |
| `LTO_MODE` | `THIN` | `NONE`, `THIN`, `FULL` |
| `ROOT_TYPE` | `VANILLA` | `VANILLA`, `KSUN`, `RESUKISU` |
| `STRIP_DEBUG` | `y` | Debug/tracing reduction |
| `CLANG_VENDOR` | `GKI` | `GKI`, `ZyC`, `Custom` |
| `CLANG_CUSTOM_URL` | empty | Custom Clang archive URL |
| `CLANG_CUSTOM_PATH` | empty | Local custom Clang archive |
| `ADDONS` | empty | Comma-separated addon names |
| `MODULES_FILTER` | empty | Case-insensitive filename substring filter |
| `RUN_MODE` | `Full Run` | `Full Run` or `Dry Run` |

The authoritative defaults are the values in [`config/defaults.env`](config/defaults.env).

## Addons

Addons are self-contained under `addons/<n>/` and do not modify the kernel tree.

Required files:

```text
addons/<n>/
├── <n>.c
├── Makefile
└── README.md
```

The directory name, module source name, and `obj-m` target must match. The generic addon stages require no addon-specific changes.

See [`docs/ADDONS.md`](docs/ADDONS.md).

### `overclock_mt6789`

`overclock_mt6789` is the reference addon for MT6789. It patches the stock GPU OPP table and CPU cpufreq-hw top entry at runtime. It is disabled until an explicit apply parameter is written.

Detailed parameters, limits, patch points, restore behavior, and known limitations are documented in [`addons/overclock_mt6789/README.md`](addons/overclock_mt6789/README.md).

## CI

`.github/workflows/build.yml` exposes the build configuration through `workflow_dispatch` inputs. Workspace caching is used only for reusable repository metadata and toolchains; the checked-out kernel worktree is recreated before source sync.

## Warning ⚠️

The addon code writes live kernel data structures and hardware registers directly. Overclocking stays off until an explicit apply parameter is written. Test changes incrementally and keep a known-good kernel available — a wrong target, incompatible kernel tree, toolchain mismatch, or vendor-driver change can cause a crash or boot failure.

### CPU frequency ceiling

CPU targets are capped at `stock_idx0 + 60%` or `2600000` KHz, whichever is lower. That's not an arbitrary safety margin: `2610000` KHz and above is confirmed to hang on this hardware.

### CFI on out-of-tree modules

Every `.ko` built against this kernel needs `__nocfi` on any function using a `kallsyms_lookup_name()`-resolved pointer, plus `-fsanitize=kcfi` in `EXTRA_CFLAGS`. A CFI violation reboots the device instantly with no panic log — there's nothing to read afterward, so get the annotation right before you flash.

## Resources

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), build architecture and data flow
- [`docs/ADDONS.md`](docs/ADDONS.md), addon contract and build integration
- [`addons/overclock_mt6789/README.md`](addons/overclock_mt6789/README.md), module API and implementation details
- [Actions](https://github.com/Anomali1304/Rock_Project/actions/workflows/build.yml)
- [`CHANGELOG.md`](CHANGELOG.md)

## License

GPL-2.0. See [`LICENSE`](LICENSE).
## MT6789 peak 2-cluster common A76 scale logical policy split

The stock MT6789 DTB exposes two physical CPUFreq performance domains: CPU0-5 (A55) and CPU6-7 (A76). This build does not invent a third hardware domain. The driver exposes three Linux policies by logically splitting the A55 domain into CPU0-2 and CPU3-5 while keeping the real stock A55 LUT (500–2000 MHz) for both policies; CPU6-7 retain their native 725–2200 MHz A76 table.

The critical performance fix is shared-domain arbitration: the LUT index is ordered high-frequency first, so the shared A55 controller now selects the lower requested index (the higher requested frequency). This prevents one logical A55 policy from accidentally overriding a higher request from the other policy. No frequency above the hardware LUT is advertised.

This is a topology/control correction, not an overclock. Actual peak frequency remains bounded by the hardware LUT: A55 2000 MHz and A76 2200 MHz. Any later OC is a separate experiment and must be validated against actual hardware frequency and thermal behavior.

## Virtual A55 Policy Split

When `VIRTUAL_A55_POLICY_SPLIT=y`, the build stage patches the Rock `mediatek-cpufreq-hw.c` driver to expose separate Linux cpufreq policies for CPU0-2 and CPU3-5 while sharing the stock A55 hardware performance domain. CPU0-2 and CPU3-5 both use the stock 500–2000 MHz A55 LUT; CPU3-5 is a virtual logical policy over the same physical A55 controller and translates requests through the shared arbitration path; CPU6-7 keeps its native 725–2200 MHz A76 table. The CPU0-2 and CPU3-5 policies are arbitrated against the shared A55 hardware using the safer lower-frequency request (larger descending-LUT index). The DTB must remain the stock two-domain MT6789 mapping: CPU0-5 -> domain 0 and CPU6-7 -> domain 1. Do not create a third hardware performance-domain node; the third cluster is a Linux cpufreq policy only.
