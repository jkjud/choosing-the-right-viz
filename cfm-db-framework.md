# Caseflow Demo Plan: Design Framework Applied

2026-09-18 · @Someone

## Overview

The demo walks a caseload health dashboard from a correct-but-ugly draft to a Maven Toys-style storytelling page, using my five design steps as the titles and Maven's six steps as the structure. The payoff is one page, scoped to one court, where the story resolves on the dashboard itself with no drill page.

|My step (slide title)|Demo artifact|
|-|-|
|1. Identify the user question|Purpose card slide|
|2. Choose the right metric|Goal → metric → level of detail table|
|3. Choose chart types that highlight the data|Metric → visual type table, then the ugly draft page|
|5. Simplify and organize to focus attention|Decluttered page, then re-laid-out page|
|4. Use storytelling elements|Final page with narrative titles|

Ordering note: the demo runs step 5 before step 4, matching Maven. Say it out loud: "You don't give the house tour while the boxes are still in the hallway. We simplify first, then narrate."

## Step 1: Identify the user question

The dashboard serves one court's caseflow leadership, reviewing monthly whether they are keeping pace with filings.

|Question|Answer|
|-|-|
|Who is the audience?|Court executive officers and caseflow managers; presiding judges secondary|
|What are their goals?|Keep pace with incoming filings; resolve cases within time standards so backlog doesn't build|
|What do they need answered?|Are we disposing of cases as fast as they come in? Is the pending caseload getting older? Which case types and locations are falling behind?|
|How often is it reviewed?|Monthly, with a quarterly look at trends|

## Step 2: Choose the right metric

Clearance rate is the headline metric and gets the most slicing; the others each answer one question at one grain.

|Business goal|Metric|Level of detail|
|-|-|-|
|Keep pace with filings|Clearance rate|Quarter, Case type, Case subtype|
|Keep pace with filings|Change in clearance rate vs last FY|Court, Case type, Case subtype|
|Keep pace with filings|Backlog index|Location × Case type|
|Resolve cases on time|Cases pending past standard|Court|

Teaching point: not every metric needs every grain. Case subtype plays the role of Maven's "product", and case type plays "category".

## Step 3: Choose chart types that highlight the data

Each metric-and-grain pair gets one visual, mirroring Maven's metric → visual type slide.

|Metric \& level of detail|Visual type|
|-|-|
|Clearance rate, selected court|KPI card, with change vs last FY and last quarter|
|Clearance rate by quarter|Line chart with a 100 target line|
|Clearance rate by case type|Bar chart|
|Change in clearance rate by case type|Diverging bar chart (paired with the bars above)|
|Backlog index by location × case type|Table|
|Cases pending past standard|KPI card|
|Change in clearance rate by case subtype|Top 5 and Bottom 5 tables|

The pivot (Maven's Image 4 moment): show `v1\_draft`, with every chart type correct and the page still not communicating. It uses default rainbow colors by case type, gridlines and borders everywhere, legends instead of direct labels, and two-decimal data labels. Line to say: "We picked the right visuals, and it still doesn't tell us anything. That's why the next steps exist."

## Step 5: Simplify and organize to focus attention

This step has two beats, one page version each, so the audience sees one kind of change at a time.

**Beat A: declutter (`v2\_decluttered`, Maven's Image 5).** Keep every visual in the same position as the draft and change only the styling:

* Use navy for the data, gray for context, and green/red only for the biggest gain and biggest drop.
* Remove gridlines, borders, and backgrounds; replace legends with direct labels; round to whole numbers.
* Shade the Top/Bottom 5 change columns green and red, fading as the change shrinks.

**Beat B: layout (`v3\_layout`, Maven's Image 6).** Rearrange the page:

* Left column: clearance rate KPI with its two deltas on top, quarterly trend line beneath.
* Middle: clearance rate by case type and change vs last FY combined into one paired bar visual.
* Right column: the problems, meaning the location × case type backlog table plus the cases-past-standard KPI.
* Bottom: Top 5 and Bottom 5 case subtypes side by side.
* Slicers for Court and Location sit top-right; section headers are still plain labels.

## Step 4: Use storytelling elements

In `v4\_story` (Maven's Image 7), the section titles chain into one sentence, read top-to-bottom and left-to-right. Key words are colored to double as the legend.

|Panel|Title|Key word color|
|-|-|-|
|Page subtitle|How did the court perform in FY 2025-26?|FY 2025-26 in navy|
|Clearance KPI|We're closing this many cases for every 100 filed...|—|
|Trend line|...and we've been below 100 since early 2025|Line turns red below target|
|Case type bars|This is clearance by case type this year...|—|
|Backlog table + KPI|We're falling behind here...|"falling behind" and "past standard" in red|
|Top/Bottom 5|...where these 5 subtypes drove the improvements \& declines|"improvements" green, "declines" red|

The aha moment: unlimited civil is the red bar in the middle, it tops the backlog table at the Main location, and the Bottom 5 shows which subtypes drive it (auto tort, contract, employment). The story resolves on the page with no drill-through.

## Demo flow and next steps

The demo clicks through four versions of one page in about 15 minutes.

|Segment|What's on screen|Time|
|-|-|-|
|Steps 1–2|Purpose card, goal → metric table|\~3 min|
|Step 3|Metric → visual table, then `v1\_draft`|\~3 min|
|Step 5|`v2\_decluttered`, then `v3\_layout`|\~4 min|
|Step 4|`v4\_story`, walk the title chain to the Bottom 5|\~4 min|
|Close|Q\&A buffer|\~1 min|

* \[ ] Duplicate the overview page into `v1\_draft`, `v2\_decluttered`, `v3\_layout`, `v4\_story`
* \[ ] Keep visual positions identical between v1 and v2 so only styling changes
* \[ ] Add case subtype to the synthetic data with enough volume per subtype to rank
* \[ ] Add a minimum-filings filter (e.g. 25+ in both years) to the Top/Bottom 5 tables
* \[ ] Replace mockup placeholder numbers with the synthetic data's actual values
* \[ ] Add Court and Location slicers
* \[ ] Build the purpose card and the two mapping tables as slides

