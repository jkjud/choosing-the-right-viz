# generate_caseflow_data.R
# Synthetic California civil caseflow data (star schema) for the data summit demo.
# Framed on Cal. Stds. Jud. Admin. 2.2. Fiscal year = Jul-Jun. Snapshot as of 2026-06-30.
# Filings start FY 2020-21 as burn-in so FY 2023-24+ clearance rates reflect a steady-state caseload.
# Planted story: Cedar Ridge unlimited civil (Other PI/PD/WD + Civil complaints) slows from FY 2023-24 on.

library(tidyverse) # >= 2.0 (attaches lubridate)
set.seed(2026)

as_of <- ymd("2026-06-30")
start <- ymd("2020-07-01")
out_dir <- "data"
dir.create(out_dir, showWarnings = FALSE)

pick_one <- function(x, n, prob = NULL) {
  x[sample.int(length(x), n, replace = TRUE, prob = prob)]
}
fy_end <- function(d) if_else(month(d) >= 7, year(d) + 1, year(d))
fy_label <- function(d) {
  str_c("FY ", fy_end(d) - 1, "-", str_sub(fy_end(d), 3, 4))
}

# ---- Courts (one per county) and locations ----------------------------------
dim_court <- tibble(
  court_name = c(
    "Cedar Ridge",
    "Alder",
    "Bayview",
    "Coyote Hills",
    "Del Oro",
    "Elk Valley",
    "Foxglove",
    "Granite",
    "Harbor",
    "Iron Mountain",
    "Juniper",
    "Kestrel",
    "Laurel",
    "Mesa Verde",
    "Nopal"
  )
) |>
  mutate(
    court_id = row_number(),
    .before = 1,
    court_code = str_to_upper(str_sub(str_remove_all(court_name, " "), 1, 3)),
    size = c(1, runif(n() - 1, 0.15, 2)),
    n_locations = pmin(5L, pmax(1L, as.integer(round(size^1.5 * 2)))),
    peer_cluster = as.integer(cut(
      size,
      c(0, 0.4, 0.9, 1.5, Inf),
      labels = FALSE
    ))
  )

dim_location <- dim_court |>
  select(court_id, court_name, n_locations) |>
  uncount(n_locations, .id = "loc_n") |>
  mutate(
    location_id = row_number(),
    location_name = if_else(
      loc_n == 1,
      str_c(court_name, " Main Courthouse"),
      str_c(court_name, " Branch ", loc_n - 1)
    )
  ) |>
  select(location_id, court_id, location_name)

# ---- Case types, Std 2.2 goals, CM-010 categories ----------------------------
dim_goal <- tribble(
  ~case_group         , ~tier , ~window_days , ~window_label , ~target_pct ,
  "Unlimited civil"   ,     1 ,          365 , "12 mo"       , 0.75        ,
  "Unlimited civil"   ,     2 ,          548 , "18 mo"       , 0.85        ,
  "Unlimited civil"   ,     3 ,          730 , "24 mo"       , 1.00        ,
  "Limited civil"     ,     1 ,          365 , "12 mo"       , 0.90        ,
  "Limited civil"     ,     2 ,          548 , "18 mo"       , 0.98        ,
  "Limited civil"     ,     3 ,          730 , "24 mo"       , 1.00        ,
  "Unlawful detainer" ,     1 ,           30 , "30 d"        , 0.90        ,
  "Unlawful detainer" ,     2 ,           45 , "45 d"        , 1.00        ,
  "Small claims"      ,     1 ,           75 , "75 d"        , 0.90        ,
  "Small claims"      ,     2 ,           95 , "95 d"        , 1.00
)

goal_wide <- dim_goal |>
  pivot_wider(
    id_cols = case_group,
    names_from = tier,
    values_from = c(window_days, window_label, target_pct),
    names_glue = "t{tier}_{.value}"
  )

dim_case_type <- tribble(
  ~case_type_id , ~case_type               , ~case_group         , ~monthly_base , ~median_days ,
              1 , "Motor vehicle PI/PD/WD" , "Unlimited civil"   ,            12 ,          250 ,
              2 , "Other PI/PD/WD"         , "Unlimited civil"   ,            10 ,          300 ,
              3 , "Civil complaints"       , "Unlimited civil"   ,            25 ,          260 ,
              4 , "Limited civil"          , "Limited civil"     ,            80 ,          140 ,
              5 , "Unlawful detainer"      , "Unlawful detainer" ,            30 ,           38 ,
              6 , "Small claims"           , "Small claims"      ,            18 ,           72
) |>
  left_join(goal_wide, by = "case_group")

dim_cm010 <- tribble(
  ~cm010_category       , ~case_type_id , ~speed ,
  "Auto tort"           ,             1 , 1.0    , "Uninsured motorist" , 1 , 1.1 ,
  "Medical malpractice" ,             2 , 1.5    , "Product liability"  , 2 , 1.4 , "Other PI/PD/WD"      , 2 , 1.0 ,
  "Breach of contract"  ,             3 , 1.2    , "Employment"         , 3 , 1.3 , "Construction defect" , 3 , 1.6 ,
  "Insurance coverage"  ,             3 , 0.9    , "Real property"      , 3 , 0.9 , "Wrongful eviction"   , 3 , 1.0 ,
  "Business tort"       ,             3 , 1.1    , "Collections"        , 4 , 0.7 , "Other limited civil" , 4 , 1.0 ,
  "Residential UD"      ,             5 , 1.0    , "Commercial UD"      , 5 , 1.3 , "Small claims"        , 6 , 1.0
) |>
  mutate(cm010_id = row_number(), .before = 1)

# ---- Filings ------------------------------------------------------------------
fact <- expand_grid(
  court_id = dim_court$court_id,
  case_type_id = dim_case_type$case_type_id,
  month = seq(start, floor_date(as_of, "month"), by = "month")
) |>
  left_join(select(dim_court, court_id, size, court_code), by = "court_id") |>
  left_join(
    select(
      dim_case_type,
      case_type_id,
      case_group,
      monthly_base,
      median_days,
      t1 = t1_window_days,
      t2 = t2_window_days,
      t3 = t3_window_days
    ),
    by = "case_type_id"
  ) |>
  mutate(n = rpois(n(), monthly_base * size)) |>
  uncount(n) |>
  mutate(filing_date = month + sample(0:27, n(), replace = TRUE)) |>
  group_by(case_type_id) |>
  mutate(
    cm010_id = pick_one(
      dim_cm010$cm010_id[dim_cm010$case_type_id == cur_group()$case_type_id],
      n()
    )
  ) |>
  group_by(court_id) |>
  mutate(
    location_id = pick_one(
      dim_location$location_id[dim_location$court_id == cur_group()$court_id],
      n()
    )
  ) |>
  ungroup() |>
  left_join(select(dim_cm010, cm010_id, cm010_category, speed), by = "cm010_id")

# ---- Durations, Std 2.2(m) excluded time, outcomes ---------------------------
stay_reasons <- c(
  "Bankruptcy stay",
  "Removed to federal court",
  "Contractual arbitration",
  "Notice of conditional settlement",
  "Military/incarceration stay"
)

fact <- fact |>
  mutate(
    story_mult = case_when(
      court_id != 1 | !case_type_id %in% 2:3 ~ 1,
      filing_date >= ymd("2024-07-01") ~ 1.6,
      filing_date >= ymd("2023-07-01") ~ 1.3,
      TRUE ~ 1
    ),
    exceptional = case_group == "Unlimited civil" &
      speed >= 1.4 &
      runif(n()) < 0.08,
    net_days = round(rlnorm(
      n(),
      log(median_days * speed * story_mult * if_else(exceptional, 2, 1)),
      0.6
    )),
    has_stay = case_group %in%
      c("Unlimited civil", "Limited civil") &
      runif(n()) < 0.05,
    excluded_days = if_else(has_stay, round(runif(n(), 30, 240)), 0),
    stay_reason = if_else(has_stay, pick_one(stay_reasons, n()), NA_character_),
    disposition_date = if_else(
      filing_date + net_days + excluded_days <= as_of,
      filing_date + net_days + excluded_days,
      NA
    ),
    is_pending = is.na(disposition_date),
    days_to_disp_net = if_else(is_pending, NA_real_, net_days),
    # Std 2.2(g): exceptional cases exempt from time goals -> flags left blank
    within_t1 = if_else(
      is_pending | exceptional,
      NA_integer_,
      as.integer(days_to_disp_net <= t1)
    ),
    within_t2 = if_else(
      is_pending | exceptional,
      NA_integer_,
      as.integer(days_to_disp_net <= t2)
    ),
    within_t3 = if_else(
      is_pending | exceptional | is.na(t3),
      NA_integer_,
      as.integer(days_to_disp_net <= t3)
    ),
    disposition_stage = if_else(
      is_pending,
      NA_character_,
      case_when(
        case_group == "Unlimited civil" ~ pick_one(
          c("Before trial", "Court trial", "Jury trial"),
          n(),
          c(.83, .15, .02)
        ),
        case_group == "Limited civil" ~ pick_one(
          c("Before trial", "Court trial"),
          n(),
          c(.97, .03)
        ),
        case_group == "Unlawful detainer" ~ pick_one(
          c("Before trial", "Court trial"),
          n(),
          c(.91, .09)
        ),
        case_group == "Small claims" ~ pick_one(
          c("Before trial", "Court trial"),
          n(),
          c(.45, .55)
        ),
        TRUE ~ NA_character_
      )
    ),
    case_track = case_when(
      exceptional ~ "Exceptional/complex (rule 3.714(c))",
      cm010_category == "Collections" ~ "Collections (rule 3.740)",
      case_group %in% c("Unlimited civil", "Limited civil") ~ "Standard",
      TRUE ~ case_group
    ),
    # ---- pending snapshot as of 2026-06-30 ----
    age_days_gross = if_else(
      is_pending,
      as.numeric(as_of - filing_date),
      NA_real_
    ),
    excluded_days = if_else(
      is_pending,
      pmin(excluded_days, age_days_gross),
      excluded_days
    ),
    age_days_net = age_days_gross -
      if_else(is_pending, excluded_days, NA_real_),
    past_24mo_goal = as.integer(
      is_pending &
        case_group %in% c("Unlimited civil", "Limited civil") &
        age_days_net > if_else(exceptional, 1095, 730)
    ),
    p_no_event = case_when(
      court_id == 1 & case_type_id %in% 2:3 & age_days_net > 540 ~ 0.65,
      age_days_net > 540 ~ 0.25,
      TRUE ~ 0.08
    ),
    next_event_date = if_else(
      is_pending & runif(n()) > p_no_event,
      as_of + sample(7:120, n(), TRUE),
      NA
    ),
    next_event_type = if_else(
      is.na(next_event_date),
      NA_character_,
      pick_one(
        c(
          "Case management conference",
          "Status conference",
          "Trial setting conference",
          "Trial"
        ),
        n()
      )
    )
  ) |>
  arrange(filing_date) |>
  group_by(court_id, filing_yr = year(filing_date)) |>
  mutate(
    case_number = str_c(
      court_code,
      "-",
      format(filing_date, "%y"),
      "-",
      str_pad(row_number(), 5, pad = "0")
    )
  ) |>
  ungroup() |>
  mutate(case_id = row_number())

fact_case <- fact |>
  select(
    case_id,
    case_number,
    court_id,
    location_id,
    case_type_id,
    cm010_id,
    case_track,
    filing_date,
    disposition_date,
    is_pending,
    disposition_stage,
    days_to_disp_net,
    within_t1,
    within_t2,
    within_t3,
    excluded_days,
    stay_reason,
    exceptional,
    age_days_gross,
    age_days_net,
    past_24mo_goal,
    next_event_date,
    next_event_type
  ) |>
  mutate(across(c(is_pending, exceptional), as.integer))

# ---- Date dimension (fiscal year Jul-Jun) ------------------------------------
dim_date <- tibble(date = seq(start, as_of, by = "day")) |>
  mutate(
    month_start = floor_date(date, "month"),
    month_name = as.character(month(date, label = TRUE)),
    fy_month = (month(date) - 7) %% 12 + 1, # Jul = 1 (sort key for month_name)
    fiscal_year = fy_label(date),
    fy_end_year = fy_end(date)
  ) # sort key for fiscal_year

# ---- Write -------------------------------------------------------------------
list(
  dimCourt = select(dim_court, -size),
  dimLocation = dim_location,
  dimCasetype = select(dim_case_type, -monthly_base, -median_days),
  dimCM010 = select(dim_cm010, -speed),
  dimGoal = dim_goal,
  dimDate = dim_date,
  fctCase = fact_case
) |>
  iwalk(\(df, nm) write_csv(df, file.path(out_dir, str_c(nm, ".csv")), na = ""))

# ---- Sanity check: story should show Cedar Ridge unlimited civil falling behind ----
fact_case |>
  filter(!is_pending, disposition_date >= ymd("2023-07-01")) |>
  left_join(
    select(dim_case_type, case_type_id, case_group),
    by = "case_type_id"
  ) |>
  mutate(
    cedar_ridge = court_id == 1,
    fiscal_year = fy_label(disposition_date)
  ) |>
  summarise(
    on_time_t1 = mean(within_t1, na.rm = TRUE),
    .by = c(cedar_ridge, case_group, fiscal_year)
  ) |>
  filter(case_group == "Unlimited civil") |>
  arrange(cedar_ridge, fiscal_year) |>
  print()
