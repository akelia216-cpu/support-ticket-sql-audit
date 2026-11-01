# Support Ticket Data Quality Audit (SQL)

An audit of a customer support ticket export, written in Oracle SQL and run in [Oracle FreeSQL](https://freesql.com). I checked how tickets are spread across categories, which products and subjects drive volume, whether required fields are filled in, and whether the timestamps make sense, then looked at satisfaction once the bad records were removed. I also checked for duplicate tickets and reconciled every category breakdown back to the total row count.

**Dataset:** [Customer Support Ticket Dataset](https://www.kaggle.com/datasets/suraj520/customer-support-ticket-dataset) on Kaggle (CC0: Public Domain). 8,469 tickets for 42 tech products. This is a synthetic dataset, so the findings describe the data and its problems, not a real company. I dropped customer names, emails, age, gender and the free-text description and resolution fields before loading.

**SQL used:** `GROUP BY` and `HAVING`, `UNION ALL`, subqueries, `CASE WHEN`, `NULL` handling, `LISTAGG`, CTEs (`WITH`), and the window functions `DENSE_RANK() OVER (PARTITION BY ...)` and `SUM(COUNT(*)) OVER ()`.

## Findings

### Query 1: Ticket counts by status, type, priority and channel
The 8,469 tickets are spread almost evenly in every category. Status splits into roughly thirds: Pending Customer Response 2,881, Open 2,819, Closed 2,769. The other categories are just as flat:

* Type: 1,634 to 1,752
* Priority: 2,063 to 2,192
* Channel: 2,073 to 2,143

In each category, the largest group is no more than about 7% bigger than the smallest. That's what you'd expect from a synthetic Kaggle dataset, so I wouldn't read anything into which group comes out on top.

### Query 2: Products and subjects with the most tickets
With 42 products, the average is about 202 tickets per product. Canon EOS has the most at 240, about 19% above average, followed by GoPro Hero at 228. Nintendo Switch has the fewest at 178, about 12% below. Across the 16 subjects the average is about 529. Refund request (576) and Software bug (574) lead, and Display issue (478) is last. Every subject is within about 10% of the average, so no single subject stands out. The more useful patterns show up at the product level in Query 6.

### Query 3: Closed tickets missing a rating or resolution time
None. All 2,769 closed tickets have both a satisfaction rating and a resolution time. The missing values in this table follow ticket status. Open tickets have no response, resolution or rating. Pending tickets have a first response but no resolution or rating. Closed tickets have all three. So the nulls are expected for unfinished tickets and don't need cleaning.

### Query 4: Resolution time earlier than first response
1,365 tickets show a resolution time earlier than the first response, and every one of them is closed. Only closed tickets have a resolution time, so this check can only flag closed tickets. That's 49% of all closed tickets, which is far too many to be occasional entry mistakes. The most likely cause is that the synthetic data generated the two timestamps independently. This was the biggest data quality problem the audit found. In a real system, I'd raise it with whoever owns the data before trusting any timing metric built on these columns. I'd also recommend a validation rule that blocks a resolution time earlier than the first response when a ticket is closed.

### Query 5: Satisfaction by channel and priority, bad records removed
I kept closed tickets that have a rating and a resolution time, and dropped the 1,365 rows from Query 4. That leaves 1,404 tickets. Ratings run from 1 to 5.

* By channel: Chat has the highest average at 3.19 and Phone the lowest at 2.92. That gap of about a quarter of a point is the only one that might be worth a second look.
* By priority: averages run from 3.07 (Low) to 3.00 (Critical), which is effectively flat.

### Query 6: Top 3 ticket subjects within each product
I ranked subjects by ticket count within each product using `DENSE_RANK()`. I kept ties because dropping a tied subject at random would hide real issues. `ROW_NUMBER()` would force exactly 3 rows per product, but it breaks ties arbitrarily unless you add a tie-breaker, so a tied subject could appear in one run and vanish in the next. `RANK()` keeps ties but skips numbers after them, which can leave fewer than 3 distinct ranks. Because of the ties, the query returned 176 rows, not 126 (42 products × 3). Sony Xperia alone shows 9 subjects across its top 3 ranks.

For context, 8,469 tickets across 42 products and 16 subjects works out to about 13 tickets per product-and-subject pair. GoPro Hero refund requests, at 28, is roughly double that and the clearest outlier. The next highest are MacBook Pro product compatibility at 24, and Garmin Forerunner software bugs and Sony 4K HDR TV network problems at 23. Those sit closer to the average. Refund request is the most common number-one subject, topping or tying for the top spot on 10 products. Because this is a synthetic dataset, I treat gaps of a few tickets as probable noise, not real product problems.

### Query 7: Duplicate tickets
7a returned 0 rows, as expected. `ticket_id` is the table's primary key, and I checked the constraint list to confirm it. The database itself refuses a repeated ID, so this check confirms the key is working. 7b also returned 0 rows, so no ticket was entered twice under a new ID. The 2,819 open tickets have no first response time. `GROUP BY` treats those blanks as matching, so open tickets were still compared against each other on the other six columns, and none matched.

### Query 8: Reconciliation
All four breakdowns add back to 8,469:

| Breakdown | Groups | Total |
|---|---|---|
| Status | 3 | 8,469 |
| Type | 5 | 8,469 |
| Priority | 4 | 8,469 |
| Channel | 4 | 8,469 |

The `SUM(COUNT(*)) OVER ()` version gives the same total next to each status row. The null check found 0 blanks in all four columns. That's why nothing went missing: a `NULL` would have shown up as an extra unlabeled group, and there isn't one. The breakdowns in Query 1 account for every ticket. `COUNT(*) - COUNT(column)` counts the blanks because `COUNT(column)` skips `NULL`s and `COUNT(*)` doesn't.

## What I'd recommend
* Fix the timestamps first. Half of the closed tickets have a resolution time earlier than the first response, so no response-time or resolution-time report from this data can be trusted yet.
* Add a validation rule that blocks a resolution time earlier than the first response when a ticket is closed.
* Leave the missing values for open and pending tickets alone. They match the ticket status and aren't errors.
* Take a second look at the Chat vs. Phone satisfaction gap once the timing data is fixed.

## Files
| File | What it does |
|---|---|
| `01_create_table.sql` | Creates the `support_tickets` table |
| `02_load_part1.sql` to `02_load_part5.sql` | Loads the 8,469 tickets (run in order) |
| `03_check_load.sql` | Confirms the row count |
| `04_audit_queries.sql` | The audit queries (1 to 8) |
| `customer_support_tickets.csv` | Original Kaggle file |

To run it yourself: sign in to [FreeSQL](https://freesql.com), run the files in number order with Run Script, then run `04_audit_queries.sql`.
