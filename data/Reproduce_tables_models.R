# ==============================================================
# Reproduce all tables and the grouped logistic model from the
# MDPI Data Descriptor manuscript based on Fatal_Road_Traffic.xlsx
#
# Usage:
#   Rscript reproduce_tables_and_model.R [input_xlsx] [output_dir]
#
# Default input file:
#   Fatal_Road_Traffic.xlsx
#
# Output:
#   - CSV files for each table
#   - One Excel workbook with all tables
#   - Logistic model summary (CSV + TXT + RDS)
#
# Author: OpenAI / ChatGPT
# Encoding: UTF-8
# ============================================================== 

# -----------------------------
# 0) Packages
# -----------------------------
required_pkgs <- c(
  "readxl", "dplyr", "tidyr", "stringr", "lubridate", "janitor",
  "purrr", "broom", "tibble", "readr", "openxlsx"
)

missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop(
    "Please install the following packages before running this script: ",
    paste(missing_pkgs, collapse = ", "),
    call. = FALSE
  )
}

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(janitor)
library(purrr)
library(broom)
library(tibble)
library(readr)
library(openxlsx)

# -----------------------------
# 1) User parameters
# -----------------------------
args <- commandArgs(trailingOnly = TRUE)
input_file <- if (length(args) >= 1) args[1] else "Fatal_Road_Traffic.xlsx"
output_dir <- if (length(args) >= 2) args[2] else "r_outputs_tables_model"

if (!file.exists(input_file)) {
  stop("Input file not found: ", input_file, call. = FALSE)
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# -----------------------------
# 2) Helper functions
# -----------------------------
fmt_num <- function(x, digits = 0) {
  formatC(x, format = "f", digits = digits, big.mark = ",")
}

is_missing_admin <- function(x) {
  is.na(x) | trimws(as.character(x)) %in% c("", "N/D", "Sin inf")
}

parse_excel_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))
  if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))
  suppressWarnings(as.Date(x))
}

parse_hour_field <- function(x) {
  # Handles POSIXct/POSIXlt, hms-like text, Excel numeric time fractions, and strings.
  if (inherits(x, "POSIXt")) return(hour(x))

  if (is.numeric(x)) {
    # Excel stores time as a fraction of 1 day.
    out <- floor((x %% 1) * 24)
    out[is.na(x)] <- NA_integer_
    return(as.integer(out))
  }

  x_chr <- trimws(as.character(x))
  x_chr[x_chr %in% c("", "NA", "NaT", "NULL")] <- NA_character_
  parsed <- suppressWarnings(parse_date_time(x_chr, orders = c("HMS", "HM", "H"), quiet = TRUE))
  hour(parsed)
}

save_csv <- function(df, filename) {
  readr::write_csv(df, file.path(output_dir, filename), na = "")
}

# -----------------------------
# 3) Load data
# -----------------------------
raw <- read_excel(input_file, sheet = "BD", guess_max = 100000)
original_names <- names(raw)

# Clean names for easier downstream programming
# AÑO becomes ano; FECHA_INCIDENTE becomes fecha_incidente; etc.
dat <- raw %>% janitor::clean_names()

# -----------------------------
# 4) Standardize fields used in the article
# -----------------------------
class_map <- c(
  "Choque" = "Crash (Choque)",
  "Atropello" = "Pedestrian hit (Atropello)",
  "Otro" = "Other (Otro)",
  "Caida Ocupante" = "Occupant fall (Caida Ocupante)",
  "Volcamiento" = "Rollover (Volcamiento)",
  "Incendio" = "Fire (Incendio)"
)

severity_map <- c(
  "HERIDO" = "Injured",
  "MUERTO" = "Fatal",
  "SOLO DAÑOS" = "Property damage only"
)

#class_order_article <- c(
#  "Pedestrian hit (Atropello)",
#  "Occupant fall (Caida Ocupante)",
#  "Crash (Choque)",
#  "Fire (Incendio)",
#  "Other (Otro)",
#  "Rollover (Volcamiento)"
#)

bbox_medellin <- list(
  lat_min = 6.15,
  lat_max = 6.35,
  lon_min = -75.68,
  lon_max = -75.50
)

###########
dat <- dat %>%
  mutate(
    fecha_incidente = parse_excel_date(fecha_incidente),
    hour_num = parse_hour_field(hora_incidente),
    
    fatal = if_else(gravedad_incidente == "MUERTO", 1L, 0L),
    
    severity_en = case_when(
      gravedad_incidente == "HERIDO" ~ "Injured",
      gravedad_incidente == "MUERTO" ~ "Fatal",
      gravedad_incidente == "SOLO DAÑOS" ~ "Property damage only",
      TRUE ~ NA_character_
    ),
    
    class_label = case_when(
      clase_incidente == "CHOQUE" ~ "Crash (Choque)",
      clase_incidente == "ATROPELLO" ~ "Pedestrian hit (Atropello)",
      clase_incidente == "CAIDA OCUPANTE" ~ "Occupant fall (Caida Ocupante)",
      clase_incidente == "INCENDIO" ~ "Fire (Incendio)",
      clase_incidente == "OTRO" ~ "Other (Otro)",
      clase_incidente == "VOLCAMIENTO" ~ "Rollover (Volcamiento)",
      TRUE ~ NA_character_
    ),
    
    class_label = factor(class_label, levels = c(
      "Crash (Choque)",
      "Pedestrian hit (Atropello)",
      "Occupant fall (Caida Ocupante)",
      "Fire (Incendio)",
      "Other (Otro)",
      "Rollover (Volcamiento)"
    )),
    
    hour_band = case_when(
      !is.na(hour_num) & hour_num >= 0  & hour_num < 6  ~ "00:00–05:59",
      !is.na(hour_num) & hour_num >= 6  & hour_num < 12 ~ "06:00–11:59",
      !is.na(hour_num) & hour_num >= 12 & hour_num < 18 ~ "12:00–17:59",
      !is.na(hour_num) & hour_num >= 18 & hour_num < 24 ~ "18:00–23:59",
      TRUE ~ NA_character_
    ),
    
    hour_band = factor(hour_band, levels = c(
      "06:00–11:59",
      "00:00–05:59",
      "12:00–17:59",
      "18:00–23:59"
    )),
    
    weekend = case_when(
      is.na(fecha_incidente) ~ NA_character_,
      lubridate::wday(fecha_incidente, week_start = 1) >= 6 ~ "Weekend",
      TRUE ~ "Weekday"
    ),
    
    weekend = factor(weekend, levels = c("Weekday", "Weekend"))
  )
############

n_all <- nrow(dat)
n_fatal <- sum(dat$fatal, na.rm = TRUE)

valid_communes_all <- dat %>% filter(!is_missing_admin(comuna_planeacion))
valid_neighborhoods_all <- dat %>% filter(!is_missing_admin(barrio_planeacion))
valid_communes_fatal <- dat %>% filter(fatal == 1, !is_missing_admin(comuna_planeacion))
valid_neighborhoods_fatal <- dat %>% filter(fatal == 1, !is_missing_admin(barrio_planeacion))

n_communes_all <- n_distinct(valid_communes_all$comuna_planeacion)
n_communes_fatal <- n_distinct(valid_communes_fatal$comuna_planeacion)
n_neighborhoods_all <- n_distinct(valid_neighborhoods_all$barrio_planeacion)
n_neighborhoods_fatal <- n_distinct(valid_neighborhoods_fatal$barrio_planeacion)

date_min <- min(dat$fecha_incidente, na.rm = TRUE)
date_max <- max(dat$fecha_incidente, na.rm = TRUE)
coord_completeness_all <- 100 * mean(!is.na(dat$latitud) & !is.na(dat$longitud))
coord_completeness_fatal <- 100 * mean(!is.na(dat$latitud[dat$fatal == 1]) & !is.na(dat$longitud[dat$fatal == 1]))

# -----------------------------
# 5) Table 1 - Database details
# -----------------------------
table_01_database_details <- tibble(
  Field = c(
    "General areas",
    "Type of data",
    "Observation unit",
    "Temporal coverage",
    "Spatial coverage",
    "Record count",
    "Fatal subset",
    "Coordinate system",
    "Primary variables",
    "Repository status"
  ),
  Description = c(
    "Transportation safety; urban mobility; spatial epidemiology; public health",
    "Administrative incident records exported as an Excel workbook",
    "One reported road traffic incident per row",
    paste0(format(date_min, "%d %B %Y"), " to ", format(date_max, "%d %B %Y")),
    paste0(
      "Medellín, Colombia: ", n_communes_all,
      " planning units (16 urban comunas and 5 corregimientos); valid neighborhood names available for ",
      n_neighborhoods_all, " neighborhoods in the full workbook and ",
      n_neighborhoods_fatal, " neighborhoods in the fatal subset"
    ),
    paste0(fmt_num(n_all), " total records"),
    paste0(fmt_num(n_fatal), " records with GRAVEDAD_INCIDENTE = 'MUERTO'"),
    "Latitude/longitude in decimal degrees (WGS84-compatible)",
    paste(original_names, collapse = ", "),
    "Insert repository DOI after public deposition (Mendeley Data, Zenodo, or Figshare)"
  )
)

# -----------------------------
# 6) Table 2 - Variable summary
# -----------------------------
table_02_variables <- tibble(
  Variable = original_names,
  `English label` = c(
    "Incident key / record identifier",
    "Calendar year",
    "Incident date",
    "Incident time",
    "Incident class",
    "Incident severity",
    "Interpolated address",
    "Latitude",
    "Longitude",
    "Planning commune code",
    "Planning commune name",
    "Planning neighborhood code",
    "Planning neighborhood name"
  ),
  `Data type` = c(
    "Integer", "Integer", "Date", "Time", "Text (categorical)",
    "Text (categorical)", "Text", "Decimal", "Decimal", "Text/integer",
    "Text (categorical)", "Text", "Text"
  ),
  `Measurement level` = c(
    "Nominal identifier", "Ordinal/temporal", "Interval/temporal", "Interval/temporal",
    "Nominal", "Ordinal", "Nominal/free text", "Continuous", "Continuous",
    "Nominal", "Nominal", "Nominal", "Nominal"
  ),
  Unit = c(
    "None", "Year", "YYYY-MM-DD", "HH:MM[:SS]", "None", "None", "None",
    "Decimal degrees (WGS84)", "Decimal degrees (WGS84)", "Administrative code",
    "Administrative name", "Administrative code", "Administrative name"
  )
)

# -----------------------------
# 7) Table 3 - Distribution by class and severity
# -----------------------------
table_03_distribution <- dat %>%
  mutate(
    class_article = recode(clase_incidente, !!!class_map),
    severity_article = recode(gravedad_incidente, !!!severity_map)
  ) %>%
  count(class_article, severity_article, name = "n") %>%
  pivot_wider(names_from = severity_article, values_from = n, values_fill = 0) %>%
  mutate(
    `Fatal % within class` = round(100 * Fatal / (Injured + Fatal + `Property damage only`), 3)
  ) %>%
  rename(`Incident class` = class_article) %>%
  mutate(`Incident class` = factor(`Incident class`, levels = class_order_article)) %>%
  arrange(`Incident class`) %>%
  mutate(`Incident class` = as.character(`Incident class`)) %>%
  select(`Incident class`, Injured, Fatal, `Property damage only`, `Fatal % within class`)

#############
table_03_distribution <- dat %>%
  mutate(
    class_article = case_when(
      clase_incidente == "Choque" ~ "Crash (Choque)",
      clase_incidente == "Atropello" ~ "Pedestrian hit (Atropello)",
      clase_incidente == "Otro" ~ "Other (Otro)",
      clase_incidente == "Caida Ocupante" ~ "Occupant fall (Caida Ocupante)",
      clase_incidente == "Volcamiento" ~ "Rollover (Volcamiento)",
      clase_incidente == "Incendio" ~ "Fire (Incendio)",
      TRUE ~ NA_character_
    ),
    
    severity_article = case_when(
      gravedad_incidente == "HERIDO" ~ "Injured",
      gravedad_incidente == "MUERTO" ~ "Fatal",
      gravedad_incidente == "SOLO DAÑOS" ~ "Property damage only",
      TRUE ~ NA_character_
    )
  ) 

# -----------------------------
# 8) Table 4 - Top planning units in the fatal subset
# -----------------------------
table_04_top_planning_units <- dat %>%
  filter(fatal == 1, !is_missing_admin(comuna_planeacion)) %>%
  count(comuna_planeacion, sort = TRUE, name = "Fatal incidents") %>%
  mutate(`Share of fatal subset (%)` = round(100 * `Fatal incidents` / sum(`Fatal incidents`), 2)) %>%
  slice_head(n = 10) %>%
  rename(`Planning unit` = comuna_planeacion)

# -----------------------------
# 9) Table 5 - Annual counts
# -----------------------------
table_05_annual_counts <- dat %>%
  group_by(ano) %>%
  summarise(
    `All incidents` = n(),
    `Fatal incidents` = sum(fatal, na.rm = TRUE),
    `Fatal incidents per 1000 records` = round(1000 * `Fatal incidents` / `All incidents`, 3),
    .groups = "drop"
  ) %>%
  rename(Year = ano) %>%
  arrange(Year)

# -----------------------------
# 10) Table 6 - Missingness in the spatial hierarchy
# -----------------------------
missing_fields <- tibble(
  Field = c("Latitude", "Longitude", "Planning commune", "Neighborhood code", "Neighborhood name"),
  all_missing_n = c(
    sum(is.na(dat$latitud)),
    sum(is.na(dat$longitud)),
    sum(is_missing_admin(dat$comuna_planeacion)),
    sum(is_missing_admin(dat$codigo_barrio_planeacion)),
    sum(is_missing_admin(dat$barrio_planeacion))
  ),
  fatal_missing_n = c(
    sum(is.na(dat$latitud[dat$fatal == 1])),
    sum(is.na(dat$longitud[dat$fatal == 1])),
    sum(is_missing_admin(dat$comuna_planeacion[dat$fatal == 1])),
    sum(is_missing_admin(dat$codigo_barrio_planeacion[dat$fatal == 1])),
    sum(is_missing_admin(dat$barrio_planeacion[dat$fatal == 1]))
  )
)

table_06_missingness <- missing_fields %>%
  mutate(
    `All records (n)` = all_missing_n,
    `All records (%)` = round(100 * all_missing_n / n_all, 2),
    `Fatal subset (n)` = fatal_missing_n,
    `Fatal subset (%)` = round(100 * fatal_missing_n / n_fatal, 2)
  ) %>%
  select(Field, `All records (n)`, `All records (%)`, `Fatal subset (n)`, `Fatal subset (%)`)

# Optional validation diagnostics mentioned in the paper
coordinate_outliers <- dat %>%
  filter(!is.na(latitud), !is.na(longitud)) %>%
  mutate(
    outside_bbox = !(latitud >= bbox_medellin$lat_min & latitud <= bbox_medellin$lat_max &
                     longitud >= bbox_medellin$lon_min & longitud <= bbox_medellin$lon_max)
  )

bbox_summary <- tibble(
  Metric = c(
    "All geocoded records outside the Medellín bounding box",
    "Fatal geocoded records outside the Medellín bounding box",
    "Valid planning units in complete workbook",
    "Valid planning units in fatal subset",
    "Valid neighborhoods in complete workbook",
    "Valid neighborhoods in fatal subset",
    "Coordinate completeness in complete workbook (%)",
    "Coordinate completeness in fatal subset (%)"
  ),
  Value = c(
    sum(coordinate_outliers$outside_bbox, na.rm = TRUE),
    sum(coordinate_outliers$outside_bbox[coordinate_outliers$fatal == 1], na.rm = TRUE),
    n_communes_all,
    n_communes_fatal,
    n_neighborhoods_all,
    n_neighborhoods_fatal,
    round(coord_completeness_all, 2),
    round(coord_completeness_fatal, 2)
  )
)

# -----------------------------
# 11) Table 7 - Grouped binomial logistic regression
# -----------------------------
dat <- dat %>%
  mutate(
    class_label = case_when(
      clase_incidente == "Choque" ~ "Crash (Choque)",
      clase_incidente == "Atropello" ~ "Pedestrian hit (Atropello)",
      clase_incidente == "Caida Ocupante" ~ "Occupant fall (Caida Ocupante)",
      clase_incidente == "Incendio" ~ "Fire (Incendio)",
      clase_incidente == "Otro" ~ "Other (Otro)",
      clase_incidente == "Volcamiento" ~ "Rollover (Volcamiento)",
      TRUE ~ NA_character_
    )
  )

table(dat$class_label)

model_data <- dat %>%
  filter(
    !is.na(class_label),
    !is.na(hour_band),
    !is.na(weekend),
    !is.na(ano),
    !is.na(fatal)
  ) %>%
  group_by(class_label, hour_band, weekend, ano) %>%
  summarise(
    fatal_count = sum(fatal, na.rm = TRUE),
    total_incidents = n(),
    nonfatal_count = total_incidents - fatal_count,
    .groups = "drop"
  )

nrow(model_data)

fatality_glm <- glm(
  cbind(fatal_count, nonfatal_count) ~ class_label + hour_band+weekend + ano,
  family = binomial(link = "logit"),
  data = model_data
)

model_tidy <- broom::tidy(fatality_glm) %>%
  filter(term != "(Intercept)") %>%
  mutate(
    odds_ratio = exp(estimate),
    conf_low = exp(estimate - 1.96 * std.error),
    conf_high = exp(estimate + 1.96 * std.error),
    predictor = case_when(
      term == "class_labelPedestrian hit (Atropello)" ~ "Pedestrian hit vs. crash",
      term == "class_labelOccupant fall (Caida Ocupante)" ~ "Occupant fall vs. crash",
      term == "class_labelFire (Incendio)" ~ "Fire vs. crash",
      term == "class_labelOther (Otro)" ~ "Other vs. crash",
      term == "class_labelRollover (Volcamiento)" ~ "Rollover vs. crash",
      term == "hour_band00:00–05:59" ~ "00:00–05:59 vs. 06:00–11:59",
      term == "hour_band12:00–17:59" ~ "12:00–17:59 vs. 06:00–11:59",
      term == "hour_band18:00–23:59" ~ "18:00–23:59 vs. 06:00–11:59",
      term == "weekendWeekend" ~ "Weekend vs. weekday",
      term == "ano" ~ "Per calendar year",
      TRUE ~ term
    ),
    p_value = case_when(
      p.value < 0.001 ~ "<0.001",
      TRUE ~ sprintf("%.3f", p.value)
    ),
    `95% CI` = paste0(sprintf("%.2f", conf_low), "–", sprintf("%.2f", conf_high))
  ) %>%
  transmute(
    Predictor = predictor,
    `Odds ratio` = round(odds_ratio, 2),
    `95% CI`,
    `p-value` = p_value
  )

table_07_logistic_model <- model_tidy

# -----------------------------
# 12) Export all outputs
# -----------------------------
# CSV tables
save_csv(table_01_database_details, "table_01_database_details.csv")
save_csv(table_02_variables, "table_02_variables.csv")
save_csv(table_03_distribution, "table_03_distribution.csv")
save_csv(table_04_top_planning_units, "table_04_top_planning_units_fatal.csv")
save_csv(table_05_annual_counts, "table_05_annual_counts.csv")
save_csv(table_06_missingness, "table_06_missingness.csv")
save_csv(table_07_logistic_model, "table_07_grouped_logistic_model.csv")
save_csv(bbox_summary, "validation_bbox_summary.csv")

# One Excel workbook with all tables and validation/model outputs
output_workbook <- file.path(output_dir, "tables_and_model_outputs.xlsx")
openxlsx::write.xlsx(
  list(
    table_01_database_details = table_01_database_details,
    table_02_variables = table_02_variables,
    table_03_distribution = table_03_distribution,
    table_04_top_planning_units = table_04_top_planning_units,
    table_05_annual_counts = table_05_annual_counts,
    table_06_missingness = table_06_missingness,
    table_07_grouped_logistic_model = table_07_logistic_model,
    grouped_model_input = model_data,
    validation_bbox_summary = bbox_summary
  ),
  file = output_workbook,
  overwrite = TRUE
)

# -----------------------------
# 13) Console summary
# -----------------------------
message("Done. Outputs written to: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Main workbook: ", normalizePath(output_workbook, winslash = "/", mustWork = FALSE))
message("Model summary: ", normalizePath(file.path(output_dir, "fatality_grouped_logistic_model_summary.txt"), winslash = "/", mustWork = FALSE))

