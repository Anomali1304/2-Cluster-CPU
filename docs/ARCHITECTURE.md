# Architecture

Rock Project separates kernel-source acquisition, kernel configuration, addon compilation, and release packaging into numbered stages.

## Source model

The AOSP GKI manifest provides the build framework and common configuration files. `stages/10-download.sh` removes the manifest's `common/` checkout and clones `KERNEL_REPO` into that path. The resulting Xiaomi tree is the tree compiled by `stages/60-build-kernel.sh`.

Vendor MTK modules are cloned separately when `USE_EXT_MODULES=y`.

## Stage flow

```text
build.sh
  │
  ├── 00-deps
  ├── 10-download
  ├── 15-clang-vendor
  ├── 20-branding
  ├── 30-core
  ├── 40-root-variant
  ├── 50-addons-stage
  ├── 60-build-kernel
  ├── 70-addons-compile
  └── 80-release
```

### 00-deps

Installs the host packages required by the pipeline and the `repo` launcher when missing. `ccache` is enabled for the build environment.

### 10-download

Initializes or reuses the GKI manifest metadata, syncs the build tooling, saves `build.config.common` and `build.config.aarch64`, then replaces the manifest `common/` tree with `KERNEL_REPO`.

When external modules are enabled, the configured vendor-module repository is cloned into `$WORKSPACE/vendor/mediatek/kernel_modules`.

### 15-clang-vendor

Selects the compiler source:

- `GKI`: use the compiler selected by the GKI build configuration
- `ZyC`: download the configured ZyC release
- `Custom`: use `CLANG_CUSTOM_PATH` or download `CLANG_CUSTOM_URL`

### 20-branding

Applies `KERNEL_NAME`, `BUILD_USER_NAME`, and `BUILD_HOST_NAME` to the kernel configuration.

### 30-core

Applies the requested LTO mode and size/debug configuration.

### 40-root-variant

Removes previous root integration and installs the selected root implementation. SUSFS is attempted for the supported root variants.

### 50-addons-stage

Parses `ADDONS`, validates each addon directory, and copies the addon source into `$WORKSPACE/addons/<name>/`.

### 60-build-kernel

Invokes the GKI build system with the Xiaomi tree and selected configuration. The resulting kernel image and `Module.symvers` become the input for later stages.

### 70-addons-compile

Locates the completed kernel build directory and its `Module.symvers`, resolves the same Clang used by the kernel build, and invokes Kbuild for every staged addon.

Each resulting module is placed under `$OUT_DIR/<addon>/`.

### 80-release

Creates three independent package types:

1. AnyKernel3 kernel image package
2. Enabled-addon module package
3. All-module package containing every matching `.ko` from the current output tree

## Workspace

```text
$WORKSPACE/
├── common/                         Xiaomi kernel source
├── build.config.common             saved GKI build config
├── build.config.aarch64            saved GKI build config
├── vendor/mediatek/kernel_modules/ external MTK modules
├── addons/<name>/                  staged addon source
├── out/                            kernel and module build output
└── AnyKernel3/                     release packaging tree
```

`release-out/` is outside the workspace and contains final archives.

## Addon build contract

The kernel must be built before an addon is compiled. The addon build uses the completed kernel tree, generated configuration, generated headers, and `Module.symvers`. The compiler must match the kernel build, especially when `CONFIG_CFI_CLANG=y` is enabled.

## Dry run

`RUN_MODE="Dry Run"` performs dependency setup, source acquisition, toolchain selection, branding, core configuration, root integration, addon staging, and the kernel-build stage. It exits before addon compilation and release packaging.
