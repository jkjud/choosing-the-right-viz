# Handoff: CA Civil Caseflow Dashboard (.pbip)

Build a single-page Power BI Project (PBIP: TMDL semantic model + PBIR report) from the CSVs produced by `generate_caseflow_data.R`. The page is a court-level (one court per county) caseflow overview in the style of the Maven Analytics "Maven Toys" storytelling dashboard. Every target comes from California Standards of Judicial Administration, standard 2.2; do not use NCSC benchmarks.

## Working rules
- Terminal commands in Git Bash syntax, never PowerShell.
- Never run git commit, push, rebase, force-push or reset --hard. Hand the user copy-pasteable commands instead.

## Inputs (`data/`, one CSV each)
| Table | Grain / key | Notes |
| --- | --- | --- |
| fact_case | case_id | filing_date, disposition_date (blank = pending), within_t1/t2/t3 (1/0, blank = pending or exceptional), past_24mo_goal, age_days_net, next_event_date, case_number |
| dim_court | court_id | court_name, court_code, n_locations, peer_cluster (1–4) |
| dim_location | location_id | court_id, location_name |
| dim_case_type | case_type_id | case_type, case_group, t1/t2/t3_window_label, t1/t2/t3_target_pct |
| dim_cm010 | cm010_id | cm010_category (Civil Case Cover Sheet) |
| dim_goal | case_group + tier | Reference only; leave disconnected |
| dim_date | date | fiscal_year (sort by fy_end_year), month_name (sort by fy_month), month_start |

Load via a Power Query parameter `DataFolder`. Mark dim_date as the date table. Data runs FY 2020-21 to FY 2025-26 (early years are burn-in); default the page to FY 2025-26.

## Model
- fact_case[filing_date] → dim_date[date]: **active**.
- fact_case[disposition_date] → dim_date[date]: **inactive** (USERELATIONSHIP for dispositions and on-time measures).
- fact_case → dim_court, dim_location, dim_case_type, dim_cm010: single-direction, many-to-one.
- dim_location → dim_court is not needed (fact carries both keys).

## Measures
```dax
Filings = COUNTROWS ( fact_case )
Dispositions = CALCULATE ( COUNTROWS ( fact_case ), USERELATIONSHIP ( fact_case[disposition_date], dim_date[date] ) )
Clearance Rate = DIVIDE ( [Dispositions], [Filings] )
Clearance vs Last FY = [Clearance Rate] - CALCULATE ( [Clearance Rate], SAMEPERIODLASTYEAR ( dim_date[date] ) )
Clearance Latest Month = VAR m = MAX ( dim_date[month_start] ) RETURN CALCULATE ( [Clearance Rate], dim_date[month_start] = m )
Clearance vs Last Month = [Clearance Latest Month] - CALCULATE ( [Clearance Rate], dim_date[month_start] = EDATE ( MAX ( dim_date[month_start] ), -1 ) )
Clearance Statewide = CALCULATE ( [Clearance Rate], REMOVEFILTERS ( dim_court ), REMOVEFILTERS ( dim_location ) )
Clearance Peer = VAR c = SELECTEDVALUE ( dim_court[peer_cluster] )
    RETURN CALCULATE ( [Clearance Rate], REMOVEFILTERS ( dim_court ), REMOVEFILTERS ( dim_location ), dim_court[peer_cluster] = c )

On-Time T1 % = CALCULATE ( AVERAGE ( fact_case[within_t1] ), USERELATIONSHIP ( fact_case[disposition_date], dim_date[date] ) )
On-Time T1 vs Last FY = [On-Time T1 %] - CALCULATE ( [On-Time T1 %], SAMEPERIODLASTYEAR ( dim_date[date] ) )
T1 Goal = MAX ( dim_case_type[t1_target_pct] )

-- JCC Trial Court Operational Metrics method (Gov. Code 68515), by case group
Est Backlog =
SUMX ( VALUES ( dim_case_type[case_group] ),
    VAR cur = [Clearance Rate]
    VAR prior = CALCULATE ( [Clearance Rate], SAMEPERIODLASTYEAR ( dim_date[date] ) )
    RETURN IF ( cur < prior, ( prior - cur ) * [Filings] ) )

-- Snapshot as of 2026-06-30; ignores the date filter
Pending Past 24 Mo = CALCULATE ( SUM ( fact_case[past_24mo_goal] ), REMOVEFILTERS ( dim_date ) )
```
Add a 30-disposition minimum for CM-010 rankings (`IF ( [Dispositions] >= 30, … )`).

## Page layout (16:9, reading order Z-pattern)
1. **Header:** title "CIVIL CASEFLOW DASHBOARD"; dynamic subtitle `"How did civil caseflow perform in " & SELECTEDVALUE ( dim_date[fiscal_year] ) & "?"`; single-select Court slicer (dropdown); Location slicer (Power BI can't auto-hide a visual, so either accept it or place a shape over it whose fill matches the background when `DISTINCTCOUNT ( dim_location[location_id] ) = 1`); fiscal year slicer; logo placeholder top right.
2. **Left panel (boxed):** "This is how many cases we cleared…" Big KPI = Clearance Rate; small: vs last month, vs last FY (blue up / orange down); caption "Statewide x% | Peer courts y%". Below: "…and the trend in FY26 vs FY25": monthly clearance line, current FY navy, prior FY grey, dashed 100% goal line, Jul→Jun axis.
3. **Middle:** "This is how each case type tracks vs its Std 2.2 goal…" Horizontal bars of On-Time T1 % by case_type (six rows), goal marker = T1 Goal (error bar or target line). Beside it, diverging bars of On-Time T1 vs Last FY. Caption: "% within first goal window (12 mo; UD 30 d; SC 75 d)".
4. **Right panel (boxed):** "We are falling behind here…" Table: case_number, cm010_category, age (months = age_days_net/30.4), next_event_date, filtered to past_24mo_goal = 1, sorted oldest first, blank next event highlighted. Big number = Pending Past 24 Mo; caption "general civil cases past the 24-month goal (Std 2.2(d))".
5. **Bottom:** "…where these 5 case categories drove the gains & losses" Two tables of cm010_category, On-Time T1 %, vs Last FY: Top N 5 and Bottom N 5 by On-Time T1 vs Last FY. Conditional formatting blue (gains) / orange (losses).
6. **Insight strip:** text box for the presenter's finding and next step (e.g., status conferences under Std 2.1).

## Formatting
- Colors: current navy `#1E3A8A`, prior grey `#9CA3AF`, gain blue `#2563EB`, loss orange `#C2410C`, goal markers `#1E1E1E`. No red/green.
- No gridlines, borders, or background images; minimal axes; data labels instead of axes where possible.
- Enclosure (light rounded boxes) only around the left and right panels.
- Titles are sentences, as above. Fonts: Segoe UI; KPI 48–60 pt.

## Acceptance checks
- Cedar Ridge, FY 2025-26: Other PI/PD/WD and Civil complaints On-Time T1 % below the 75% goal and down vs FY 2024-25.
- Bottom-5 CM-010 table for Cedar Ridge includes slow categories (construction defect, medical malpractice, employment).
- Cedar Ridge Pending Past 24 Mo > 0, with most listed cases showing no next event.
- Switching Court to a one-location county still renders every visual.
- The R script's printed sanity table agrees with the page's On-Time T1 % for unlimited civil.
