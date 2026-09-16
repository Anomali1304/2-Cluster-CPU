// SPDX-License-Identifier: GPL-2.0
/*
 * MT6789 two-domain cpufreq driver with a unified 725-2200 MHz logical scale.
 *
 * Physical domains remain unchanged:
 *   Domain 0: CPU0-5 (A55)
 *   Domain 1: CPU6-7 (A76)
 *
 * The A76 domain keeps its hardware LUT unchanged. The A55 domain is programmed
 * at probe time with the exact same 16 frequency points (725-2200 MHz), including
 * the 1000 MHz state, by replacing the frequency field of its hardware LUT rows.
 * Both cpufreq policies expose the same ordered frequency table, so one logical
 * index always means the same frequency on both physical domains. DVFS remains dynamic.
 *
 * This does NOT turn A55 cores into A76 cores; it gives the A55 clock controller
 * the same frequency points used by the A76 domain.
 */
#include <linux/bitfield.h>
#include <linux/cpufreq.h>
#include <linux/energy_model.h>
#include <linux/init.h>
#include <linux/iopoll.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/of_address.h>
#include <linux/of_platform.h>
#include <linux/pm_qos.h>
#include <linux/slab.h>

#define LUT_MAX_ENTRIES 32U
#define LUT_FREQ GENMASK(11, 0)
#define LUT_ROW_SIZE 0x4
#define CPUFREQ_HW_STATUS BIT(0)
#define SVS_HW_STATUS BIT(1)
#define POLL_USEC 1000
#define TIMEOUT_USEC 300000

enum {
	REG_FREQ_LUT_TABLE,
	REG_FREQ_ENABLE,
	REG_FREQ_PERF_STATE,
	REG_FREQ_HW_STATE,
	REG_EM_POWER_TBL,
	REG_FREQ_LATENCY,
	REG_ARRAY_SIZE,
};

struct cpufreq_mtk {
	struct cpufreq_frequency_table *table;
	struct cpufreq_frequency_table *hw_table;
	void __iomem *reg_bases[REG_ARRAY_SIZE];
	int nr_opp;
	int hw_nr_opp;
	cpumask_t related_cpus;
};

static const u16 cpufreq_mtk_offsets[REG_ARRAY_SIZE] = {
	[REG_FREQ_LUT_TABLE] = 0x0,
	[REG_FREQ_ENABLE] = 0x84,
	[REG_FREQ_PERF_STATE] = 0x88,
	[REG_FREQ_HW_STATE] = 0x8c,
	[REG_EM_POWER_TBL] = 0x90,
	[REG_FREQ_LATENCY] = 0x114,
};

static struct cpufreq_mtk *mtk_freq_domain_map[NR_CPUS];

static int look_up_cpu(struct device *cpu_dev)
{
	int cpu;
	for (cpu = 0; cpu < NR_CPUS; cpu++)
		if (cpu_dev == get_cpu_device(cpu))
			return cpu;
	return 0;
}

static bool mtk_is_a55_domain(const struct cpufreq_mtk *c)
{
	return cpumask_test_cpu(0, &c->related_cpus);
}

/*
 * The A55 controller is programmed with the same 16 frequency points as the
 * native A76 controller.  These are real hardware LUT values, not merely
 * labels exposed through cpufreq.
 */
static const unsigned int mtk_a76_scale_khz[] = {
	2200000U, 2100000U, 2000000U, 1900000U, 1800000U,
	1700000U, 1600000U, 1500000U, 1400000U, 1300000U,
	1200000U, 1100000U, 1000000U,  900000U,  800000U,
	 725000U,
};

#define MTK_A76_SCALE_ENTRIES ARRAY_SIZE(mtk_a76_scale_khz)

/*
 * Replace the top A55 hardware LUT states before cpufreq enables the HW.
 * Only the frequency field is changed; all other controller bits remain
 * untouched.  Row 16 duplicates row 15 so the normal LUT reader terminates
 * after exactly the 16 A76-compatible states.
 */
static int mtk_program_a55_a76_lut(struct cpufreq_mtk *c)
{
	unsigned int i;
	u32 raw;

	if (!mtk_is_a55_domain(c))
		return 0;

	for (i = 0; i < MTK_A76_SCALE_ENTRIES; i++) {
		raw = readl_relaxed(c->reg_bases[REG_FREQ_LUT_TABLE] +
				i * LUT_ROW_SIZE);
		raw = (raw & ~LUT_FREQ) |
			FIELD_PREP(LUT_FREQ, mtk_a76_scale_khz[i] / 1000U);
		writel_relaxed(raw, c->reg_bases[REG_FREQ_LUT_TABLE] +
				i * LUT_ROW_SIZE);
	}

	raw = readl_relaxed(c->reg_bases[REG_FREQ_LUT_TABLE] +
			MTK_A76_SCALE_ENTRIES * LUT_ROW_SIZE);
	raw = (raw & ~LUT_FREQ) |
		FIELD_PREP(LUT_FREQ, mtk_a76_scale_khz[MTK_A76_SCALE_ENTRIES - 1] / 1000U);
	writel_relaxed(raw, c->reg_bases[REG_FREQ_LUT_TABLE] +
			MTK_A76_SCALE_ENTRIES * LUT_ROW_SIZE);

	return 0;
}

static int __maybe_unused
mtk_cpufreq_get_cpu_power(unsigned long *power, unsigned long *KHz,
		struct device *cpu_dev)
{
	int cpu = look_up_cpu(cpu_dev);
	struct cpufreq_mtk *c = mtk_freq_domain_map[cpu];
	unsigned int idx;

	if (!c || !c->nr_opp)
		return -ENODEV;

	idx = cpufreq_table_find_index_dl(&(struct cpufreq_policy) {
		.freq_table = c->table,
	}, *KHz);
	if (idx >= c->nr_opp)
		idx = c->nr_opp - 1;

	*KHz = c->table[idx].frequency;
	if (mtk_is_a55_domain(c)) {
		/* EM power remains tied to the native A55 LUT entry. */
		*power = readl_relaxed(c->reg_bases[REG_EM_POWER_TBL] +
					idx * LUT_ROW_SIZE) / 1000;
	} else {
		*power = readl_relaxed(c->reg_bases[REG_EM_POWER_TBL] +
					idx * LUT_ROW_SIZE) / 1000;
	}
	return 0;
}

static int mtk_cpufreq_hw_target_index(struct cpufreq_policy *policy,
					unsigned int index)
{
	struct cpufreq_mtk *c = policy->driver_data;
	if (index >= c->nr_opp)
		return -EINVAL;

	/* Logical index == hardware LUT index on both domains. */
	writel_relaxed(index, c->reg_bases[REG_FREQ_PERF_STATE]);
	return 0;
}

static unsigned int mtk_cpufreq_hw_get(unsigned int cpu)
{
	struct cpufreq_mtk *c = mtk_freq_domain_map[cpu];
	unsigned int index;

	if (!c || !c->nr_opp)
		return 0;

	index = readl_relaxed(c->reg_bases[REG_FREQ_PERF_STATE]);
	if (index >= c->nr_opp)
		index = c->nr_opp - 1;
	return c->table[index].frequency;
}

static unsigned int mtk_cpufreq_hw_fast_switch(struct cpufreq_policy *policy,
					unsigned int target_freq)
{
	struct cpufreq_mtk *c = policy->driver_data;
	unsigned int index;

	index = cpufreq_table_find_index_dl(policy, target_freq);
	if (index >= c->nr_opp)
		index = c->nr_opp - 1;

	writel_relaxed(index, c->reg_bases[REG_FREQ_PERF_STATE]);
	return c->table[index].frequency;
}

static int mtk_cpufreq_hw_cpu_init(struct cpufreq_policy *policy)
{
	struct cpufreq_mtk *c;
	struct device *cpu_dev;
	struct em_data_callback em_cb = EM_DATA_CB(mtk_cpufreq_get_cpu_power);
	struct pm_qos_request *qos_request;
	int sig, pwr_hw = CPUFREQ_HW_STATUS | SVS_HW_STATUS;
	unsigned int latency;

	cpu_dev = get_cpu_device(policy->cpu);
	if (!cpu_dev)
		return -ENODEV;

	c = mtk_freq_domain_map[policy->cpu];
	if (!c)
		return -ENODEV;

	cpumask_copy(policy->cpus, &c->related_cpus);
	cpumask_copy(policy->related_cpus, &c->related_cpus);
	policy->freq_table = c->table;
	policy->driver_data = c;
	policy->cpuinfo.min_freq = c->table[c->nr_opp - 1].frequency;
	policy->cpuinfo.max_freq = c->table[0].frequency;
	policy->min = policy->cpuinfo.min_freq;
	policy->max = policy->cpuinfo.max_freq;

	latency = readl_relaxed(c->reg_bases[REG_FREQ_LATENCY]);
	policy->cpuinfo.transition_latency = latency ? latency * 1000 : CPUFREQ_ETERNAL;
	policy->fast_switch_possible = true;

	qos_request = kzalloc(sizeof(*qos_request), GFP_KERNEL);
	if (!qos_request)
		return -ENOMEM;

	cpu_latency_qos_add_request(qos_request, PM_QOS_DEFAULT_VALUE);
	writel_relaxed(0x1, c->reg_bases[REG_FREQ_ENABLE]);

	if (readl_poll_timeout(c->reg_bases[REG_FREQ_HW_STATE], sig,
				       (sig & pwr_hw) == pwr_hw,
				       POLL_USEC, TIMEOUT_USEC)) {
		if (!(sig & CPUFREQ_HW_STATUS)) {
			cpu_latency_qos_remove_request(qos_request);
			kfree(qos_request);
			return -ENODEV;
		}
	}

	em_dev_register_perf_domain(cpu_dev, c->nr_opp, &em_cb,
					policy->cpus, true);
	cpu_latency_qos_remove_request(qos_request);
	kfree(qos_request);
	return 0;
}

static int mtk_cpufreq_hw_cpu_exit(struct cpufreq_policy *policy)
{
	struct cpufreq_mtk *c = policy->driver_data;
	if (!c)
		return -ENODEV;
	writel_relaxed(0x0, c->reg_bases[REG_FREQ_ENABLE]);
	return 0;
}

static struct cpufreq_driver cpufreq_mtk_hw_driver = {
	.flags = CPUFREQ_STICKY | CPUFREQ_NEED_INITIAL_FREQ_CHECK |
		 CPUFREQ_HAVE_GOVERNOR_PER_POLICY | CPUFREQ_IS_COOLING_DEV,
	.verify = cpufreq_generic_frequency_table_verify,
	.target_index = mtk_cpufreq_hw_target_index,
	.get = mtk_cpufreq_hw_get,
	.init = mtk_cpufreq_hw_cpu_init,
	.exit = mtk_cpufreq_hw_cpu_exit,
	.fast_switch = mtk_cpufreq_hw_fast_switch,
	.name = "mtk-cpufreq-hw",
	.attr = cpufreq_generic_attr,
};

static int mtk_cpu_create_freq_table(struct platform_device *pdev,
				     struct cpufreq_mtk *c)
{
	struct device *dev = &pdev->dev;
	void __iomem *base_table = c->reg_bases[REG_FREQ_LUT_TABLE];
	u32 data, i, freq, prev_freq = 0;

	c->hw_table = devm_kcalloc(dev, LUT_MAX_ENTRIES + 1,
				   sizeof(*c->hw_table), GFP_KERNEL);
	if (!c->hw_table)
		return -ENOMEM;

	if (mtk_is_a55_domain(c)) {
		int ret = mtk_program_a55_a76_lut(c);
		if (ret)
			return ret;
	}

	for (i = 0; i < LUT_MAX_ENTRIES; i++) {
		data = readl_relaxed(base_table + i * LUT_ROW_SIZE);
		freq = FIELD_GET(LUT_FREQ, data) * 1000;
		if (freq == prev_freq)
			break;
		c->hw_table[i].frequency = freq;
		prev_freq = freq;
	}

	c->hw_table[i].frequency = CPUFREQ_TABLE_END;
	c->hw_nr_opp = i;
	if (!c->hw_nr_opp)
		return -ENODEV;

	c->table = devm_kcalloc(dev, c->hw_nr_opp + 1,
				sizeof(*c->table), GFP_KERNEL);
	if (!c->table)
		return -ENOMEM;

	/*
	 * The two physical domains must expose one identical logical table.
	 * A76 is expected to already contain this native 16-state sequence;
	 * A55 was programmed above to contain the same sequence.
	 */
	if (c->hw_nr_opp != MTK_A76_SCALE_ENTRIES)
		return -EINVAL;

	for (i = 0; i < MTK_A76_SCALE_ENTRIES; i++) {
		if (c->hw_table[i].frequency != mtk_a76_scale_khz[i])
			return -EINVAL;
		c->table[i].frequency = mtk_a76_scale_khz[i];
	}
	c->nr_opp = MTK_A76_SCALE_ENTRIES;

	c->table[c->nr_opp].frequency = CPUFREQ_TABLE_END;
	return 0;
}

static int mtk_get_related_cpus(int index, struct cpufreq_mtk *c)
{
	struct device_node *cpu_np;
	struct of_phandle_args args;
	int cpu, ret;

	for_each_possible_cpu(cpu) {
		cpu_np = of_cpu_device_node_get(cpu);
		if (!cpu_np)
			continue;
		ret = of_parse_phandle_with_args(cpu_np, "performance-domains",
						 "#performance-domain-cells", 0, &args);
		of_node_put(cpu_np);
		if (ret < 0)
			continue;
		if (index == args.args[0]) {
			cpumask_set_cpu(cpu, &c->related_cpus);
			mtk_freq_domain_map[cpu] = c;
		}
	}
	return 0;
}

static int mtk_cpu_resources_init(struct platform_device *pdev,
				  unsigned int cpu, int index, const u16 *offsets)
{
	struct cpufreq_mtk *c;
	struct device *dev = &pdev->dev;
	void __iomem *base;
	int ret, i;

	if (mtk_freq_domain_map[cpu])
		return 0;
	c = devm_kzalloc(dev, sizeof(*c), GFP_KERNEL);
	if (!c)
		return -ENOMEM;

	base = devm_platform_ioremap_resource(pdev, index);
	if (IS_ERR(base))
		return PTR_ERR(base);
	for (i = REG_FREQ_LUT_TABLE; i < REG_ARRAY_SIZE; i++)
		c->reg_bases[i] = base + offsets[i];

	ret = mtk_get_related_cpus(index, c);
	if (ret)
		return ret;
	ret = mtk_cpu_create_freq_table(pdev, c);
	if (ret)
		return ret;
	return 0;
}

static int mtk_cpufreq_hw_driver_probe(struct platform_device *pdev)
{
	struct device_node *cpu_np;
	struct of_phandle_args args;
	const u16 *offsets;
	unsigned int cpu;
	int ret;

	offsets = of_device_get_match_data(&pdev->dev);
	if (!offsets)
		return -EINVAL;

	for_each_possible_cpu(cpu) {
		cpu_np = of_cpu_device_node_get(cpu);
		if (!cpu_np)
			return -ENODEV;
		ret = of_parse_phandle_with_args(cpu_np, "performance-domains",
						 "#performance-domain-cells", 0, &args);
		of_node_put(cpu_np);
		if (ret < 0)
			return ret;
		ret = mtk_cpu_resources_init(pdev, cpu, args.args[0], offsets);
		if (ret)
			return ret;
	}
	return cpufreq_register_driver(&cpufreq_mtk_hw_driver);
}

static int mtk_cpufreq_hw_driver_remove(struct platform_device *pdev)
{
	return cpufreq_unregister_driver(&cpufreq_mtk_hw_driver);
}

static const struct of_device_id mtk_cpufreq_hw_match[] = {
	{ .compatible = "mediatek,cpufreq-hw", .data = &cpufreq_mtk_offsets },
	{}
};

static struct platform_driver mtk_cpufreq_hw_driver = {
	.probe = mtk_cpufreq_hw_driver_probe,
	.remove = mtk_cpufreq_hw_driver_remove,
	.driver = {
		.name = "mtk-cpufreq-hw",
		.of_match_table = mtk_cpufreq_hw_match,
	},
};
module_platform_driver(mtk_cpufreq_hw_driver);
MODULE_DESCRIPTION("Mediatek cpufreq-hw driver - MT6789 dual domain common A76 scale");
MODULE_LICENSE("GPL v2");
