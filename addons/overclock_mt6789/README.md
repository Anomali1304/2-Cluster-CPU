# overclock_mt6789

Out-of-tree kernel module for the POCO M5 (rock) / MediaTek MT6789
(Helio G99).

This version is designed for the final **3+3+2 cpufreq layout**:

```text
Policy0 → CPU0-2 → 3× Cortex-A55 → 500–2000 MHz
Policy3 → CPU3-5 → 3× Cortex-A55 → 500–2000 MHz
Policy6 → CPU6-7 → 2× Cortex-A76 → 725–2200 MHz
Big    → none
```

Linux exposes three cpufreq policies while preserving the intended semantic
grouping: the first policy is the Little group; the CPU3-5 and CPU6-7
policies are the two members of the Performance group; there is no Big
group on this MT6789 layout. The CPU3-5 policy is a virtual view over the
shared stock A55 hardware domain and is not an independent physical PLL or
voltage rail.
Policy0 and policy3 share the exact same A55 LUT and hardware register bank; the addon must therefore treat them as two logical request surfaces over one physical controller.

The DTB is not modified by this project. The build stage patches
`mediatek-cpufreq-hw.c` so stock domain0 is split into CPU0-2 and CPU3-5
virtual policies, while CPU6-7 remains the native A76 policy.

## Scope

### CPU

The CPU OC path handles all three cpufreq policies independently:

  Group/Policy   CPUs   Representative CPU   Stock range
  ------------- ------ -------------------- ------------
  Policy0          0-2                    0     500–2000 MHz
  Policy3          3-5                    3     500–2000 MHz (virtual A55 view)
  Policy6          6-7                    6     725–2200 MHz (native A76)

For each cluster, the module targets the top cpufreq entry (`idx0`) and
updates the live MediaTek cpufreq-hw state used by the policy.

The CPU path updates:

-   vendor frequency LUT entry 0;
-   `policy->freq_table[0].frequency`;
-   `policy->cpuinfo.max_freq`;
-   `policy->max`;
-   the corresponding Energy Model top performance-state frequency.

Before modifying a live LUT row, the module temporarily constrains the
affected policy to the next available frequency entry and waits for the
hardware performance state to leave `idx0`. The timeout is 50 ms.

### CPU OC limits

Each cluster uses the lower of:

``` text
stock_idx0 + 60%
2600000 KHz absolute ceiling
```

For the validated stock frequencies this results in:

``` text
Little: 2000 MHz → maximum requested target 2600 MHz
Perf/A55: 2200 MHz virtual view → maximum requested target 2600 MHz
Perf/A76: 2200 MHz → maximum requested target 2600 MHz
```

These are **software request limits only**. They do not guarantee
hardware stability, thermal safety, or sufficient voltage.

The module does not invent or force CPU voltage values.

A target of `0` restores the saved stock `idx0` frequency for that
cluster.

## CPU parameters

All parameters are exposed under:

``` text
/sys/module/overclock_mt6789/parameters/
```

  -----------------------------------------------------------------------
  Parameter               Mode                    Meaning
  ----------------------- ----------------------- -----------------------
  `cpu_c0_target_khz`     RW                      Little target for
                                                  CPU0-2. `0` restores
                                                  stock.

  `cpu_c1_target_khz`     RW                      Perf/A55 target for
                                                  CPU3-5. `0` restores
                                                  stock.

  `cpu_c2_target_khz`     RW                      Perf/A76 target for
                                                  CPU6-7. `0` restores
                                                  stock.

  `cpu_oc_apply`          RW                      Write `1` to apply all
                                                  three CPU targets.

  `cpu_oc_result`         RO                      Result of the last CPU
                                                  apply operation.

  `cpu_c0_min_khz`        RW                      Requested policy
                                                  minimum for Little / policy0.

  `cpu_c1_min_khz`        RW                      Requested policy
                                                  minimum for Policy3.

  `cpu_c2_min_khz`        RW                      Requested policy
                                                  minimum for Perf / policy6.

  `cpu_lut_dump`          RO                      Dumps/comparisons of
                                                  the live CPU frequency
                                                  tables.

  `cpu_stats_refresh`     RW                      Rebuilds
                                                  `time_in_state`; use
                                                  `1`, `2`, or `3` for
                                                  C0, C1, or C2.
  -----------------------------------------------------------------------

### CPU OC example

Start conservatively and test one cluster at a time.

``` bash
P=/sys/module/overclock_mt6789/parameters

echo 1800000 > $P/cpu_c0_target_khz
echo 2400000 > $P/cpu_c1_target_khz
echo 2500000 > $P/cpu_c2_target_khz
echo 1       > $P/cpu_oc_apply

cat $P/cpu_oc_result
cat $P/cpu_lut_dump
```

### Restore CPU stock frequencies

``` bash
P=/sys/module/overclock_mt6789/parameters

echo 0 > $P/cpu_c0_target_khz
echo 0 > $P/cpu_c1_target_khz
echo 0 > $P/cpu_c2_target_khz
echo 1 > $P/cpu_oc_apply
```

## CPU minimum frequency

The three minimum-frequency parameters are independent:

``` text
cpu_c0_min_khz
cpu_c1_min_khz
cpu_c2_min_khz
```

They operate on the corresponding `struct cpufreq_policy::min` value and
are separate from the userspace `scaling_min_freq` interface.

The requested minimum is clamped to the policy limits:

``` text
cpuinfo.min_freq <= policy->min <= policy->max
```

Example:

``` bash
P=/sys/module/overclock_mt6789/parameters

echo 2000000 > $P/cpu_c0_min_khz
echo 2000000 > $P/cpu_c1_min_khz
echo 2200000 > $P/cpu_c2_min_khz

cat $P/cpu_c0_min_khz
cat $P/cpu_c1_min_khz
cat $P/cpu_c2_min_khz
```

When a CPU OC target is applied, the module also keeps the policy
minimum consistent when the previous minimum was above the new
`policy->max` or was tracking the previous maximum.

## `time_in_state`

Because the CPU OC path changes the frequency table after
`cpufreq_stats` may already have created its bucket table,
`cpu_stats_refresh` can rebuild the statistics table.

``` bash
P=/sys/module/overclock_mt6789/parameters

# Cluster 0
echo 1 > $P/cpu_stats_refresh

# Cluster 1
echo 2 > $P/cpu_stats_refresh

# Cluster 2
echo 3 > $P/cpu_stats_refresh
```

Run the refresh for one cluster at a time after confirming that its
normal OC path is stable.

## GPU

The existing MT6789 GPU working-table and PLL path is retained.

The GPU path:

-   patches GPU OPP index 0 in the `gpufreq` working table;
-   patches the signed table when its symbol is available;
-   resynchronizes GED's cached working table when `g_working_table` can
    be resolved;
-   updates the MFG PLL through `mtk_fh_set_rate()` with the required
    POSDIV ordering;
-   defers the PLL transition through the existing workqueue/commit
    path.

GPU frequency is limited to:

``` text
1750000 KHz
```

GPU voltage and VSRAM inputs are limited to:

``` text
50000..100000 mV×100
```

which corresponds to:

``` text
500..1000 mV
```

A `gpu_target_vsram` value of `0` uses the target GPU voltage.

### GPU parameters

  -----------------------------------------------------------------------
  Parameter               Mode                    Meaning
  ----------------------- ----------------------- -----------------------
  `gpu_target_freq`       RW                      Target GPU frequency in
                                                  KHz. `0` disables the
                                                  requested OC target.

  `gpu_target_volt`       RW                      Target GPU voltage in
                                                  mV×100.

  `gpu_target_vsram`      RW                      Target VSRAM in mV×100.
                                                  `0` uses the target GPU
                                                  voltage.

  `gpu_oc_apply`          RW                      Write `1` to apply the
                                                  GPU target values.

  `gpu_oc_result`         RO                      Result of the last GPU
                                                  apply operation.

  `gpu_opp_dump`          RO                      Live GPU OPP table
                                                  dump.
  -----------------------------------------------------------------------

Example:

``` bash
P=/sys/module/overclock_mt6789/parameters

echo 1000000 > $P/gpu_target_freq
echo 90000   > $P/gpu_target_volt
echo 0       > $P/gpu_target_vsram
echo 1       > $P/gpu_oc_apply

cat $P/gpu_oc_result
cat $P/gpu_opp_dump
```

Restore the original GPU OPP entry:

``` bash
P=/sys/module/overclock_mt6789/parameters

echo 0 > $P/gpu_target_freq
echo 1 > $P/gpu_oc_apply
```

## Safety

The module refuses CPU/GPU apply operations while the device is entering
suspend or hibernation.

The CPU path validates every requested target against its
policy-specific software limit and the absolute 2600 MHz ceiling.

The CPU LUT update waits for the affected policy to leave `idx0` before
modifying the live top entry. If the transition does not occur within 50
ms, the operation fails instead of modifying the live row.

The GPU PLL path uses the MediaTek frequency-hopping interface for the
PCW transition and does not perform the PLL transition synchronously
from the parameter handler.

## Runtime dependencies

The target kernel must provide the vendor symbols, structures, and
layouts expected by this module.

The following are required for the kallsyms-resolved paths used by the
module:

``` text
CONFIG_KALLSYMS_ALL=y
```

The module must be compiled with the same Clang/toolchain family and
compatible kernel configuration as the running kernel.

This is especially important when:

``` text
CONFIG_CFI_CLANG=y
```

is enabled.

## Known limitations

-   CPU voltage is not controlled by the CPU OC path.
-   Frequencies above stock are therefore not guaranteed to be stable.
-   GED synchronization is best-effort. If `g_working_table` cannot be
    resolved, the hardware OPP change may still succeed while GED's
    cached frequency remains unchanged.
-   Signed GPU table patching is optional and depends on
    `gpufreq_get_signed_table` being available.
-   Vendor cpufreq mirror layouts are platform-specific. A vendor kernel
    change can invalidate the offsets used by this module.
-   `cpu_stats_refresh` is manual and should only be used after the
    corresponding cluster OC path has been confirmed stable.
-   The module assumes the validated 3-policy DTB layout. It should not
    be used with the original 2-policy MT6789 DTB without adapting the
    CPU mapping.

## Build

Standalone build:

``` bash
make KDIR=~/OSS/common WORKSPACE=~/OSS
make check-clang
```

Install/remove for development:

``` bash
make install
make uninstall
```

Pipeline build:

``` bash
ADDONS=overclock_mt6789 ./build.sh
```

The module must be built against the completed Rock Project kernel tree
matching the kernel that will load it.

## 3+3+2 cpufreq topology

The matching DTB layout is:

``` text
CPU0-2 → stock performance-domain 0 → 500–2000 MHz table
CPU3-5 → shared stock performance-domain 0 → virtual 500–2000 MHz view
CPU6-7 → native A76 performance-domain 1 → 725–2200 MHz table
```

The DTB is responsible for exposing the three cpufreq policies. The
module only performs OC on those already-created policies.

## License

GPL-2.0.