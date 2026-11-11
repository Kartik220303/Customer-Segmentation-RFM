# Customer Segmentation & Marketing Analytics (RFM)

End-to-end analytics project on a synthetic multi-table retail dataset: MySQL cleaning and RFM scoring, K-Means clustering in Python, and a three-page Power BI report on customer value and campaign engagement.

<!-- TODO: add 3 report screenshots here (Customer Segments, Campaign Engagement, Cluster Comparison) -->

## Business questions

1. Who are our most valuable customers, and how much revenue do they carry?
2. Which customer segments respond to email campaigns?
3. Do data-driven clusters (K-Means) agree with simple rule-based RFM segments?

## Key findings

- **Revenue is concentrated.** 519 Champions (17.5% of 2,962 customers) generate 65.4M of 130.6M revenue, which is 50.07%.
- **At Risk is the biggest retention gap.** It is the largest segment (687 customers) and the second-largest revenue pool (28.1M).
- **Engagement follows value.** Across 4,361 sends, the open rate is 42.1%, the click rate 16.9% and the conversion rate 6.1%. Champions convert at 13.4%; Lost customers convert at 0.4%.
- **K-Means and RFM mostly agree.** 92.1% of Champions fall in the High-value regulars cluster, 99.1% of Lost customers fall in Gone, low-value, and all 192 New Customers fall in Recent light buyers. Loyal and Needs Attention split across three clusters each, which is where the two methods disagree.

## Data

Five tables, loaded as raw text into MySQL staging tables:
`customers`, `products`, `orders`, `order_items`, `campaign_responses`.

The raw data was deliberately messy. The cleaning step handles:

- duplicate customers, products, orders and campaign responses
- four signup date formats (ISO, slash, dash, month name)
- order totals stored as `Rs.` text, and missing totals rebuilt from line items
- inconsistent status, gender and yes/no values
- orders and responses pointing to customers that don't exist
- 15 campaign rows flagged `Converted without click` (excluded from conversion counts)

## Method

| Step | Tool | What happens |
|---|---|---|
| 1. Clean | MySQL | Profile each raw table, build `*_clean` tables, validate counts and integrity |
| 2. Score | MySQL | Recency, frequency and monetary value from **Delivered** orders; 1-5 scores by cumulative distribution; 8 rule-based segments |
| 3. Cluster | Python | K-Means with 4 clusters, named Gone low-value, High-value regulars, Mid-value cooling and Recent light buyers <!-- TODO: features used, scaling, how k=4 was chosen --> |
| 4. Report | Power BI | 3 pages; every figure reconciled to the SQL output |

RFM details:
- Recency is measured from a fixed snapshot date, 2026-07-01.
- Segments are rules on the R, F and M scores, for example Champions = R, F and M all at least 4.

## Power BI report

1. **Customer Segments:** customers and revenue by segment, with headline cards.
2. **Campaign Engagement:** open, click and conversion rates by segment.
3. **Cluster Comparison:** K-Means clusters against RFM segments, as counts and as a share of each segment.

Definitions used in the report:
- Rates are counts divided by **all sends**, so conversion is a share of sends, not of clicks.
- Conversion counts only rows where the customer clicked and converted.
- Revenue is in rupees (the raw data stores totals as `Rs.` text) <!-- TODO: confirm currency -->.

## Data quality notes

- **38 customers (1.3% of 3,000)** are excluded from RFM because all their orders were Returned or Cancelled. They have no Delivered order to score.
- **25 of 4,386 campaign sends** go to customers with no segment and are excluded from Page 2.
- **Small samples:** conversion counts are only 1 for Hibernating, 2 for Lost and 7 for Needs Attention, so their conversion rates are unreliable.
- The data is synthetic, so the findings illustrate the method and are not real business results.

## Reproduce it

1. Create the five staging tables and load the raw CSVs <!-- TODO: how the CSVs were loaded -->.
2. Run `sql/customer_segmentation_consolidated.sql` top to bottom in one session (MySQL 8.0+). Section 12 holds checks with expected values.
3. Export `rfm_segments` (query at the end of section 11) and run the clustering notebook <!-- TODO: file name -->.
4. Open the Power BI file and refresh.

## Repository

```
sql/        customer_segmentation_consolidated.sql
python/     K-Means clustering        <!-- TODO -->
powerbi/    report file (.pbix)
data/       raw CSVs                  <!-- TODO: include if shareable -->
images/     report screenshots
```

## Tools

MySQL 8, Python, Power BI

## Author

Kartik K N
