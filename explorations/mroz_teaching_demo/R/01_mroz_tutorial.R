# ------------------------------------------------------------------------------
# File:     explorations/mroz_teaching_demo/R/01_mroz_tutorial.R
# Project:  Mroz 数据计量经济学课堂演示
# Author:   [任课教师]
# Purpose:  使用 Mroz 已婚女性劳动供给数据，演示本科计量经济学课中常见
#           的几个基础环节：
#             (1) 读取和检查 CSV 数据
#             (2) 描述性统计和分组均值
#             (3) 单因素和双因素 ANOVA
#             (4) Pearson 相关系数矩阵
#             (5) OLS 工资方程
#             (6) 使用父母教育作为工具变量的 IV / 2SLS 回归
#             (7) 使用 ggplot2 导出 PNG 和 PDF 图形
# Inputs:   data/raw/MROZ.csv
#           data/raw/MROZ_description.txt
# Outputs:  explorations/mroz_teaching_demo/output/tables/*
#           explorations/mroz_teaching_demo/output/figures/*
# Log:      explorations/mroz_teaching_demo/logs/01_mroz_tutorial.log
#
# 运行方式（在仓库根目录执行）：
#     bash scripts/run_r.sh explorations/mroz_teaching_demo/R/01_mroz_tutorial.R
#     scripts\run_r.bat explorations\mroz_teaching_demo\R\01_mroz_tutorial.R
# ------------------------------------------------------------------------------

if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0; you have ", R.version.string)

# warn = 1：让 warning 及时显示，方便学生马上定位问题。
# scipen = 999：尽量不用科学计数法打印数字，使 log 更容易阅读。
# stringsAsFactors = FALSE：避免老版本 R 自动把字符串转为 factor。
options(warn = 1, scipen = 999, stringsAsFactors = FALSE)
set.seed(20260512)

# 项目工具：
# proj_path() 用于生成相对项目根目录的路径，避免 setwd() 和绝对路径。
# start_log()/stop_log() 用于把运行过程写入日志，便于课后核对结果。
source("R/_utils/paths.R")
source("R/_utils/logging.R")

suppressPackageStartupMessages({
  library(readr)         # 读取 CSV
  library(dplyr)         # 数据整理
  library(tidyr)         # 宽表和长表转换
  library(ggplot2)       # 画图
  library(scales)        # 坐标轴百分比、刻度等
  library(broom)         # 把模型结果整理成 data frame
  library(fixest)        # OLS 和 IV 回归
  library(modelsummary)  # 导出回归表
})

# 统一图形风格。课堂示例和正式分析都尽量使用同一套颜色与主题。
source("R/_utils/theme_journal.R")


# --- 0. 路径设置 --------------------------------------------------------------

demo_dir <- proj_path("explorations", "mroz_teaching_demo")
table_dir <- file.path(demo_dir, "output", "tables")
figure_dir <- file.path(demo_dir, "output", "figures")
log_dir <- file.path(demo_dir, "logs")

dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

# exploration 示例必须把主日志写入自己的 logs/ 目录。
# 根目录 logs/ 下的 console log 只是 wrapper 辅助日志，不能替代这里的主日志。
start_log("01_mroz_tutorial", dir = log_dir)
on.exit(stop_log(), add = TRUE)

table_path <- function(file) file.path(table_dir, file)
figure_path <- function(file) file.path(figure_dir, file)

# 同一张图同时保存为 PNG 和 PDF：
# PNG 适合放进幻灯片，PDF 适合论文、讲义和 LaTeX。
save_figure <- function(plot, name, width = 7, height = 5) {
  ggsave(figure_path(paste0(name, ".png")), plot,
         width = width, height = height, dpi = 320, bg = "white")
  ggsave(figure_path(paste0(name, ".pdf")), plot,
         width = width, height = height, device = cairo_pdf, bg = "white")
}


# --- 1. 读取并准备数据 --------------------------------------------------------

# Mroz 数据是劳动经济学和计量经济学课中常用的数据。
# 本示例关注的问题是：女性受教育年限与工资之间是什么关系？
# 进一步地：如果教育可能内生，能否用父母教育作为工具变量？
mroz <- read_csv(proj_path("data", "raw", "MROZ.csv"), show_col_types = FALSE)

cat("\n*** 数据读取完成 ***\n")
cat("观测数：", nrow(mroz), "\n")
cat("变量数：", ncol(mroz), "\n")
cat("变量名：", paste(names(mroz), collapse = ", "), "\n")

# 为了课堂展示方便，把常用变量的含义整理成一张表。
variable_labels <- tibble::tribble(
  ~variable,   ~label,
  "inlf",      "1975 年是否进入劳动力市场，=1 表示是",
  "hours",     "1975 年工作小时数",
  "kidslt6",   "6 岁以下儿童数量",
  "kidsge6",   "6 至 18 岁儿童数量",
  "age",       "女性年龄",
  "educ",      "女性受教育年限",
  "wage",      "根据收入和工时估算的小时工资",
  "huseduc",   "丈夫受教育年限",
  "huswage",   "丈夫小时工资",
  "faminc",    "1975 年家庭收入",
  "motheduc",  "母亲受教育年限",
  "fatheduc",  "父亲受教育年限",
  "unem",      "居住县失业率",
  "city",      "是否居住在城市/SMSA，=1 表示是",
  "exper",     "实际劳动市场经验",
  "nwifeinc",  "非妻子收入，单位为千美元",
  "lwage",     "小时工资的对数",
  "expersq",   "劳动市场经验的平方"
)
write_csv(variable_labels, table_path("variable_labels.csv"))

# 构造几个课堂上更容易理解的分类变量。
# 注意：工资方程只能使用有正工资、且 log wage 非缺失的工作女性样本。
mroz <- mroz %>%
  mutate(
    in_labor_force = factor(
      if_else(inlf == 1, "进入劳动力市场", "未进入劳动力市场"),
      levels = c("未进入劳动力市场", "进入劳动力市场")
    ),
    city_label = factor(
      if_else(city == 1, "城市/SMSA", "非城市"),
      levels = c("非城市", "城市/SMSA")
    ),
    young_children = factor(
      if_else(kidslt6 > 0, "有 6 岁以下儿童", "无 6 岁以下儿童"),
      levels = c("无 6 岁以下儿童", "有 6 岁以下儿童")
    ),
    educ_group = case_when(
      educ < 12 ~ "低于高中",
      educ == 12 ~ "高中",
      educ > 12 & educ < 16 ~ "部分大学",
      educ >= 16 ~ "大学及以上",
      TRUE ~ NA_character_
    ),
    educ_group = factor(
      educ_group,
      levels = c("低于高中", "高中", "部分大学", "大学及以上")
    )
  )

wage_sample <- mroz %>%
  filter(inlf == 1, !is.na(wage), wage > 0, !is.na(lwage))

cat("\n*** 教学样本 ***\n")
cat("完整 Mroz 样本：", nrow(mroz), "名已婚女性\n")
cat("工资方程样本：", nrow(wage_sample), "名有正工资的工作女性\n")


# --- 2. 描述性统计 ------------------------------------------------------------

# 描述性统计回答的问题是：在做回归之前，数据长什么样？
# 每个实证项目都应该先看样本量、均值、标准差、分位数和异常范围。
vars_for_summary <- c(
  "inlf", "hours", "age", "educ", "wage", "lwage", "exper", "kidslt6",
  "kidsge6", "motheduc", "fatheduc", "huseduc", "huswage", "nwifeinc"
)

summary_tbl <- mroz %>%
  select(all_of(vars_for_summary)) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "value") %>%
  group_by(variable) %>%
  summarise(
    N = sum(!is.na(value)),
    mean = mean(value, na.rm = TRUE),
    sd = sd(value, na.rm = TRUE),
    min = min(value, na.rm = TRUE),
    p25 = quantile(value, 0.25, na.rm = TRUE),
    median = median(value, na.rm = TRUE),
    p75 = quantile(value, 0.75, na.rm = TRUE),
    max = max(value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(variable_labels, by = "variable") %>%
  select(variable, label, everything()) %>%
  mutate(across(c(mean, sd, min, p25, median, p75, max), ~ round(.x, 3)))

cat("\n>>> 描述性统计 <<<\n")
print(summary_tbl, n = Inf)
write_csv(summary_tbl, table_path("summary_statistics.csv"))

# 分组均值是从描述统计过渡到 ANOVA 和回归的好桥梁。
# 下面看不同教育组、是否有小孩的女性，劳动参与率和工时是否不同。
group_means_tbl <- mroz %>%
  group_by(educ_group, young_children) %>%
  summarise(
    N = n(),
    labor_force_rate = mean(inlf == 1, na.rm = TRUE),
    mean_hours = mean(hours, na.rm = TRUE),
    mean_educ = mean(educ, na.rm = TRUE),
    mean_age = mean(age, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(across(c(labor_force_rate, mean_hours, mean_educ, mean_age), ~ round(.x, 3)))

cat("\n>>> 按教育组和是否有小孩分组的劳动参与情况 <<<\n")
print(group_means_tbl, n = Inf)
write_csv(group_means_tbl, table_path("group_means_by_education_children.csv"))

wage_group_tbl <- wage_sample %>%
  group_by(educ_group) %>%
  summarise(
    N = n(),
    mean_wage = mean(wage, na.rm = TRUE),
    mean_lwage = mean(lwage, na.rm = TRUE),
    mean_exper = mean(exper, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(across(c(mean_wage, mean_lwage, mean_exper), ~ round(.x, 3)))

cat("\n>>> 工资样本中按教育组的工资均值 <<<\n")
print(wage_group_tbl, n = Inf)
write_csv(wage_group_tbl, table_path("wage_group_means_by_education.csv"))


# --- 3. ANOVA：方差分析 -------------------------------------------------------

# ANOVA 的核心问题是：不同组的均值是否存在统计意义上的差异？
# 这里的因变量是 log wage，分组变量是教育组。
anova_oneway <- aov(lwage ~ educ_group, data = wage_sample)
anova_oneway_raw <- broom::tidy(anova_oneway)
anova_oneway_tbl <- anova_oneway_raw %>%
  mutate(across(where(is.numeric), ~ round(.x, 4)))

cat("\n>>> 单因素 ANOVA：log wage 是否随教育组不同而不同 <<<\n")
print(summary(anova_oneway))
write_csv(anova_oneway_tbl, table_path("anova_lwage_by_education.csv"))

# 双因素 ANOVA 再加入“是否有 6 岁以下儿童”。
# 这可以帮助学生理解：加入另一个分类变量后，组间均值差异如何变化。
anova_twoway <- aov(lwage ~ educ_group + young_children, data = wage_sample)
anova_twoway_tbl <- broom::tidy(anova_twoway) %>%
  mutate(across(where(is.numeric), ~ round(.x, 4)))

cat("\n>>> 双因素 ANOVA：教育组和是否有小孩共同解释 log wage <<<\n")
print(summary(anova_twoway))
write_csv(anova_twoway_tbl, table_path("anova_lwage_by_education_children.csv"))


# --- 4. Pearson 相关系数矩阵 --------------------------------------------------

# Pearson 相关系数衡量两个变量之间的线性相关程度，取值范围为 [-1, 1]。
# 相关系数只描述线性关联，不等于因果效应。
cor_vars <- c(
  "lwage", "wage", "educ", "exper", "expersq", "motheduc", "fatheduc",
  "huseduc", "huswage", "nwifeinc", "kidslt6", "kidsge6"
)

cor_mat <- cor(wage_sample[, cor_vars], use = "pairwise.complete.obs")
cor_tbl <- as_tibble(as.data.frame(round(cor_mat, 3))) %>%
  tibble::rownames_to_column("variable")

cat("\n>>> Pearson 相关系数矩阵 <<<\n")
print(cor_tbl, n = Inf)
write_csv(cor_tbl, table_path("correlation_matrix.csv"))

cor_long <- as.data.frame(cor_mat) %>%
  tibble::rownames_to_column("var1") %>%
  pivot_longer(-var1, names_to = "var2", values_to = "r") %>%
  mutate(
    var1 = factor(var1, levels = cor_vars),
    var2 = factor(var2, levels = cor_vars),
    show = as.integer(var1) < as.integer(var2),
    label = if_else(show, sprintf("%.2f", r), "")
  ) %>%
  filter(show)

p_corr <- ggplot(cor_long, aes(x = var2, y = var1, fill = r)) +
  geom_tile(colour = "white", linewidth = 0.4) +
  geom_text(aes(label = label), family = "serif", size = 3) +
  scale_fill_gradient2(
    low = pal_journal[["lilac"]],
    mid = "white",
    high = pal_journal[["blue"]],
    midpoint = 0,
    limits = c(-1, 1),
    name = "Pearson r"
  ) +
  coord_equal() +
  labs(
    title = "Mroz 工资样本的相关系数矩阵",
    subtitle = "只显示上三角；相关系数用于描述线性关联，不代表因果关系",
    x = NULL,
    y = NULL,
    caption = "样本：有正工资的工作女性。"
  ) +
  theme_journal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

save_figure(p_corr, "correlation_heatmap", width = 8.5, height = 6.5)


# --- 5. 描述性图形 ------------------------------------------------------------

p_lwage_hist <- ggplot(wage_sample, aes(x = lwage)) +
  geom_histogram(binwidth = 0.25, fill = pal_journal[["blue"]],
                 colour = "white", linewidth = 0.3) +
  labs(
    title = "log wage 的分布",
    subtitle = "劳动经济学中常用 log(wage) 作为工资方程的因变量",
    x = "log hourly wage",
    y = "人数",
    caption = "样本：有正工资的工作女性。"
  ) +
  theme_journal()

save_figure(p_lwage_hist, "lwage_histogram")

p_wage_by_educ <- ggplot(wage_sample, aes(x = educ_group, y = lwage, fill = educ_group)) +
  geom_boxplot(width = 0.65, alpha = 0.85, outlier.alpha = 0.35) +
  scale_fill_manual(values = c(
    "低于高中" = pal_journal[["lilac"]],
    "高中" = pal_journal[["blue"]],
    "部分大学" = pal_journal[["teal"]],
    "大学及以上" = pal_journal[["navy"]]
  ), guide = "none") +
  labs(
    title = "不同教育组的 log wage",
    subtitle = "ANOVA 可以正式检验这些组均值是否相同",
    x = "教育组",
    y = "log hourly wage",
    caption = "箱线图中间线为中位数，箱体为四分位距。"
  ) +
  theme_journal()

save_figure(p_wage_by_educ, "lwage_by_education_boxplot")

p_scatter <- ggplot(wage_sample, aes(x = educ, y = lwage)) +
  geom_point(alpha = 0.55, size = 1.8, colour = pal_journal[["slate"]]) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE,
              colour = pal_journal[["navy"]], fill = pal_journal[["blue"]]) +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(
    title = "受教育年限与 log wage",
    subtitle = "拟合线展示的是简单双变量 OLS 关系",
    x = "受教育年限",
    y = "log hourly wage",
    caption = "这是相关关系；遗漏变量可能影响因果解释。"
  ) +
  theme_journal()

save_figure(p_scatter, "lwage_education_scatter")

p_inlf <- ggplot(mroz, aes(x = educ_group, fill = in_labor_force)) +
  geom_bar(position = "fill", colour = "white", linewidth = 0.3) +
  scale_y_continuous(labels = percent_format()) +
  scale_fill_manual(values = c(
    "未进入劳动力市场" = pal_journal[["lilac"]],
    "进入劳动力市场" = pal_journal[["teal"]]
  )) +
  labs(
    title = "不同教育组的劳动参与率",
    subtitle = "完整样本同时包含工作女性和非工作女性",
    x = "教育组",
    y = "比例",
    fill = "1975 年状态",
    caption = "Mroz 已婚女性样本。"
  ) +
  theme_journal()

save_figure(p_inlf, "labor_force_by_education")


# --- 6. OLS 工资方程 ----------------------------------------------------------

# OLS 的基本解释：在控制其他变量后，教育每增加一年，平均 log wage 如何变化。
# 因变量是 log wage，因此教育系数约等于工资百分比变化。
ols_simple <- feols(lwage ~ educ, data = wage_sample, vcov = "hetero")
ols_controls <- feols(
  lwage ~ educ + exper + expersq + city + kidslt6 + kidsge6,
  data = wage_sample,
  vcov = "hetero"
)
ols_family <- feols(
  lwage ~ educ + exper + expersq + city + kidslt6 + kidsge6 + nwifeinc + huseduc,
  data = wage_sample,
  vcov = "hetero"
)

ols_models <- list(
  "OLS：只放教育" = ols_simple,
  "OLS：加入经验/家庭变量" = ols_controls,
  "OLS：再加入收入/丈夫教育" = ols_family
)

cat("\n>>> OLS 工资方程 <<<\n")
etable(ols_models)

modelsummary(
  ols_models,
  output = table_path("ols_wage_models.tex"),
  stars = TRUE,
  statistic = "({std.error})",
  gof_omit = "IC|Log|Adj|Within|RMSE",
  title = "OLS 工资方程：因变量为 log hourly wage",
  notes = "括号内为异方差稳健标准误。"
)
modelsummary(
  ols_models,
  output = table_path("ols_wage_models.csv"),
  stars = TRUE,
  statistic = "({std.error})",
  gof_omit = "IC|Log|Adj|Within|RMSE"
)
modelsummary(
  ols_models,
  output = table_path("ols_wage_models.html"),
  stars = TRUE,
  statistic = "({std.error})",
  gof_omit = "IC|Log|Adj|Within|RMSE"
)


# --- 7. IV / 2SLS 工具变量回归 ------------------------------------------------

# 为什么需要 IV？
# 教育可能是内生变量：能力、家庭背景、动机等不可观测因素，可能同时影响
# 教育和工资。若这些因素没有被控制，OLS 的教育系数可能有偏。
#
# 本示例使用父亲教育、母亲教育作为女性教育的工具变量。
# 课堂上一定要强调：这只是教学示例，排除限制是否成立需要认真讨论。
first_stage_father <- feols(
  educ ~ fatheduc + exper + expersq + city + kidslt6 + kidsge6,
  data = wage_sample,
  vcov = "hetero"
)
first_stage_parents <- feols(
  educ ~ fatheduc + motheduc + exper + expersq + city + kidslt6 + kidsge6,
  data = wage_sample,
  vcov = "hetero"
)

iv_father <- feols(
  lwage ~ exper + expersq + city + kidslt6 + kidsge6 | educ ~ fatheduc,
  data = wage_sample,
  vcov = "hetero"
)
iv_parents <- feols(
  lwage ~ exper + expersq + city + kidslt6 + kidsge6 | educ ~ fatheduc + motheduc,
  data = wage_sample,
  vcov = "hetero"
)

iv_models <- list(
  "OLS 控制变量" = ols_controls,
  "IV：父亲教育" = iv_father,
  "IV：父母教育" = iv_parents
)

cat("\n>>> 第一阶段：父母教育是否能解释女性教育 <<<\n")
etable(list("只用父亲教育" = first_stage_father, "使用父母教育" = first_stage_parents))

cat("\n>>> fixest 输出的 IV 诊断 <<<\n")
print(fitstat(iv_father, type = c("ivf", "ivwald")))
print(fitstat(iv_parents, type = c("ivf", "ivwald")))

cat("\n>>> OLS 与 IV 工资方程对比 <<<\n")
etable(iv_models)

modelsummary(
  list("只用父亲教育" = first_stage_father, "使用父母教育" = first_stage_parents),
  output = table_path("first_stage_education_models.csv"),
  stars = TRUE,
  statistic = "({std.error})",
  gof_omit = "IC|Log|Adj|Within|RMSE"
)
modelsummary(
  iv_models,
  output = table_path("ols_vs_iv_wage_models.tex"),
  stars = TRUE,
  statistic = "({std.error})",
  gof_omit = "IC|Log|Adj|Within|RMSE",
  title = "OLS 与 IV 工资方程：因变量为 log hourly wage",
  notes = paste(
    "所有模型控制经验、经验平方、城市、6 岁以下儿童和 6-18 岁儿童。",
    "括号内为稳健标准误。IV 列使用父母教育作为女性教育的工具变量。"
  )
)
modelsummary(
  iv_models,
  output = table_path("ols_vs_iv_wage_models.csv"),
  stars = TRUE,
  statistic = "({std.error})",
  gof_omit = "IC|Log|Adj|Within|RMSE"
)
modelsummary(
  iv_models,
  output = table_path("ols_vs_iv_wage_models.html"),
  stars = TRUE,
  statistic = "({std.error})",
  gof_omit = "IC|Log|Adj|Within|RMSE"
)


# --- 8. 生成中文教学说明 ------------------------------------------------------

educ_ols <- coef(ols_controls)[["educ"]]
educ_iv_father <- coef(iv_father)[["fit_educ"]]
educ_iv_parents <- coef(iv_parents)[["fit_educ"]]
anova_p <- anova_oneway_raw %>%
  filter(term == "educ_group") %>%
  pull(p.value)

notes <- c(
  "# Mroz 计量经济学课堂演示：结果说明",
  "",
  "## 数据和样本",
  paste0("- 完整样本量：", nrow(mroz), " 名已婚女性。"),
  paste0("- 工资方程样本量：", nrow(wage_sample), " 名有正工资的工作女性。"),
  paste(
    "- `lwage` 是小时工资的对数。在线性 log wage 模型中，系数 0.01",
    "大约表示 1% 的工资差异。"
  ),
  "",
  "## 描述性统计",
  paste(
    "- 先看 `summary_statistics.csv`，再做任何回归。学生应检查变量单位、",
    "缺失值和极端值。"
  ),
  paste(
    "- `group_means_by_education_children.csv` 显示劳动参与并不是随机发生的；",
    "家庭结构和教育水平都与劳动参与有关。"
  ),
  "",
  "## ANOVA",
  paste0("- 教育组之间 log wage 均值差异的单因素 ANOVA p 值为 ",
         signif(anova_p, 4), "。"),
  paste(
    "- ANOVA 检验不同组的均值是否相同，但它不是因果识别设计，",
    "不能自动解释为教育导致工资变化。"
  ),
  "",
  "## 相关系数矩阵",
  "- `correlation_matrix.csv` 和 `correlation_heatmap` 展示变量间线性相关。",
  "- 相关系数适合探索数据和检查共线性，但相关不等于因果。",
  "",
  "## OLS",
  paste0("- 控制变量 OLS 中教育系数为 ", round(educ_ols, 4),
         "，约等于每多一年教育，小时工资高 ",
         round(100 * educ_ols, 1), "%。"),
  paste(
    "- OLS 的因果解释依赖条件外生性假设：在控制变量后，教育与未观测工资",
    "决定因素不相关。"
  ),
  "",
  "## IV 回归",
  paste0("- 使用父亲教育作为工具变量时，教育的 IV 系数为 ",
         round(educ_iv_father, 4), "。"),
  paste0("- 使用父母教育共同作为工具变量时，教育的 IV 系数为 ",
         round(educ_iv_parents, 4), "。"),
  paste(
    "- IV 需要相关性和排除限制。相关性可看第一阶段表格和 log 中的",
    "first-stage F 统计量。"
  ),
  paste(
    "- 排除限制是实质性假设：父母教育必须只通过女性自身教育影响工资。",
    "这个假设在真实研究中需要认真辩护。"
  ),
  "",
  "## 建议课堂顺序",
  "1. 先读数据说明和描述性统计。",
  "2. 用箱线图和 ANOVA 讲解组均值比较。",
  "3. 用散点图引入简单 OLS。",
  "4. 加入控制变量，讨论遗漏变量偏误。",
  "5. 引入 IV，讲第一阶段、相关性和排除限制。"
)

writeLines(notes, table_path("teaching_notes.md"))

cat("\n>>> 中文教学说明已写入 output/tables/teaching_notes.md <<<\n")
cat("\n*** 输出文件位置 ***\n")
cat("表格：", table_dir, "\n")
cat("图形：", figure_dir, "\n")
cat("日志：", file.path(log_dir, "01_mroz_tutorial.log"), "\n")
