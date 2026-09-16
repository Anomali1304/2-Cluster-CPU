# Addons

An addon is an out-of-tree kernel module stored in this repository and compiled against the kernel produced by the same pipeline run.

## Contract

```text
addons/<name>/
├── <name>.c
├── Makefile
└── README.md
```

The following names must match:

- directory: `<name>`
- source: `<name>.c`
- Kbuild target: `obj-m := <name>.o`

No addon manifest or addon-specific pipeline script is required.

## Build flow

`stages/50-addons-stage.sh` validates the addon and stages it under `$WORKSPACE/addons/<name>/`.

`stages/70-addons-compile.sh` then:

1. finds the completed kernel build tree;
2. finds `Module.symvers`;
3. resolves the kernel's Clang;
4. invokes Kbuild with `LLVM=1` and `LLVM_IAS=1`;
5. copies `<name>.ko` to `$OUT_DIR/<name>/`.

## Makefile

A minimal addon can use:

```makefile
obj-m := my_addon.o
```

The pipeline supplies `KDIR`, architecture, compiler, cross-compile prefix, and LLVM options.

The reference Makefile at [`addons/overclock_mt6789/Makefile`](../addons/overclock_mt6789/Makefile) also supports standalone builds.

## Enabling

```bash
ADDONS=my_addon ./build.sh
```

Multiple addons can be enabled with a comma-separated value:

```bash
ADDONS=my_addon,overclock_mt6789 ./build.sh
```

The CI workflow accepts the same value through its `addons` input.

## Current addon

| Addon | Target | Purpose |
|---|---|---|
| `overclock_mt6789` | MT6789 | Runtime GPU and CPU frequency/voltage-table modification |

Module-specific behavior belongs in the addon's own README.
