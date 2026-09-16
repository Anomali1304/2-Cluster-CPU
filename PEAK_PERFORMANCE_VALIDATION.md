# 2-cluster common A76 scale Peak Performance Validation

This build is the peak-performance source candidate for the proven logical
2-cluster common A76 scale design.

Topology:
- CPU0-2: A55 logical policy
- CPU3-5: A55 logical policy sharing the same physical A55 controller
- CPU6-7: native A76 policy

Performance-critical invariants:
1. target_index and fast_switch must use identical A55 arbitration.
2. Lower LUT index means higher requested performance.
3. A55 hardware state is the arbitration result, not an independent state per
   logical policy.
4. get() must report the actual hardware state.
5. Policy exit/offline must not leave a stale high-performance request.
6. CPU6-7 remain on the native A76 controller.

Required device validation before calling this build boot-proven:
- boot successfully
- inspect policy related/affected CPU masks
- verify all three policies exist
- verify available frequency tables
- verify A55 arbitration under independent load on CPU0-2 and CPU3-5
- verify fast-switch transitions
- benchmark single-thread and multi-thread workloads
