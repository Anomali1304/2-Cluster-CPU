## 1.3.1-3CLUSTER-POLICY-FINAL

- Fix virtual CPU3-5 table initialization ordering.
- Finalize the virtual Perf table only after native CPU6-7 resources are initialized.
- Keep the DTB at the stock two hardware performance domains.
- Fix shared A55 request-slot cleanup so policy exit cannot write `UINT_MAX` as a hardware LUT index.
- Keep CPU6-7 on the native A76 controller and table.

## 1.1.1-3CLUSTER-FINAL

- Fix missing `policy->freq_table` assignment in the virtual CPU3-5 init path.
- Keep CPU3-5 logical Perf table at 725–2200 MHz.
- Keep CPU0-3 and CPU3-5 sharing the physical A55 controller with safe max-index arbitration.
- Keep CPU6-7 as native A76 policy.

## 1.3.0-3CLUSTER-PERF725-FIX
- Fix policy4 logical frequency table to 725–2200 MHz.
- Build the virtual Perf table only after all native domains are initialized.
- Keep CPU3-5 requests translated to the shared A55 hardware domain.
- Correct virtual Energy Model power lookup to use the shared A55 power table.

# Changelog

## 1.2.0-3CLUSTER-PERF725
- Restored CPU3-5 virtual Perf policy frequency table to 725–2200 MHz.
- CPU3-5 requests are translated to the shared A55 hardware LUT.
- CPU6-7 remains native 725–2200 MHz A76.


## 1.0.0

Initial release. Single-repo kernel build pipeline for Xiaomi's MT6789
(Helio G99) GKI source — kernel, root solutions (Vanilla / KSUN /
ReSukiSU), and addons all in one place.

- Root, your way: Vanilla, KernelSU-Next, or ReSukiSU, each with optional SUSFS.
- Addons: real module source lives in `addons/<name>/`, no external repo, no clone step. Add a dir, it's buildable.
- Every module, every run: vendor MTK + in-tree GKI + addon `.ko` files all zipped together.
- One config file: every knob in `config/defaults.env`.
- CI-native: single GitHub Actions `workflow_dispatch`, every knob exposed as an input.
