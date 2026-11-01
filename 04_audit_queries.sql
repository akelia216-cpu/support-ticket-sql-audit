-- 1. Tickets per status, type, priority and channel (one combined list)
SELECT 'status' AS dimension, ticket_status AS value, COUNT(*) AS tickets
FROM support_tickets GROUP BY ticket_status
UNION ALL
SELECT 'type', ticket_type, COUNT(*) FROM support_tickets GROUP BY ticket_type
UNION ALL
SELECT 'priority', ticket_priority, COUNT(*) FROM support_tickets GROUP BY ticket_priority
UNION ALL
SELECT 'channel', ticket_channel, COUNT(*) FROM support_tickets GROUP BY ticket_channel
ORDER BY dimension, tickets DESC;

-- 2a. Products with the most tickets
SELECT product, COUNT(*) AS tickets
FROM support_tickets
GROUP BY product
ORDER BY tickets DESC;

-- 2b. Subjects with the most tickets
SELECT ticket_subject, COUNT(*) AS tickets
FROM support_tickets
GROUP BY ticket_subject
ORDER BY tickets DESC;

-- 3. Closed tickets missing a satisfaction rating or a resolution time
SELECT
  COUNT(*) AS closed_tickets,
  SUM(CASE WHEN csat_rating IS NULL THEN 1 ELSE 0 END) AS missing_rating,
  SUM(CASE WHEN resolved_at IS NULL THEN 1 ELSE 0 END) AS missing_resolution_time,
  SUM(CASE WHEN csat_rating IS NULL
            OR resolved_at IS NULL THEN 1 ELSE 0 END) AS missing_either
FROM support_tickets
WHERE ticket_status = 'Closed';

-- 4. Tickets resolved before their first response
SELECT COUNT(*) AS resolved_before_first_response
FROM support_tickets
WHERE resolved_at < first_response_at;

-- 5a. Average satisfaction by channel, bad records left out
SELECT ticket_channel,
       COUNT(*) AS tickets,
       ROUND(AVG(csat_rating), 2) AS avg_satisfaction
FROM support_tickets
WHERE ticket_status = 'Closed'
  AND csat_rating IS NOT NULL
  AND resolved_at IS NOT NULL
  AND resolved_at >= first_response_at
GROUP BY ticket_channel
ORDER BY avg_satisfaction DESC;

-- 5b. Same filters, by priority
SELECT ticket_priority,
       COUNT(*) AS tickets,
       ROUND(AVG(csat_rating), 2) AS avg_satisfaction
FROM support_tickets
WHERE ticket_status = 'Closed'
  AND csat_rating IS NOT NULL
  AND resolved_at IS NOT NULL
  AND resolved_at >= first_response_at
GROUP BY ticket_priority
ORDER BY avg_satisfaction DESC;

-- 6. Top 3 ticket subjects within each product (window function)
WITH subject_counts AS (
  SELECT product,
         ticket_subject,
         COUNT(*) AS tickets
  FROM support_tickets
  GROUP BY product, ticket_subject
),
ranked AS (
  SELECT product,
         ticket_subject,
         tickets,
         DENSE_RANK() OVER (PARTITION BY product
                            ORDER BY tickets DESC) AS subject_rank
  FROM subject_counts
)
SELECT product, ticket_subject, tickets, subject_rank
FROM ranked
WHERE subject_rank <= 3
ORDER BY product, subject_rank, ticket_subject;

-- 7a. Repeated ticket IDs
SELECT ticket_id, COUNT(*) AS copies
FROM support_tickets
GROUP BY ticket_id
HAVING COUNT(*) > 1;

-- 7b. Same ticket entered twice under different IDs
SELECT product, purchase_date, ticket_type, ticket_subject,
       ticket_channel, ticket_priority, first_response_at,
       COUNT(*) AS tickets,
       LISTAGG(ticket_id, ', ') WITHIN GROUP (ORDER BY ticket_id) AS ticket_ids
FROM support_tickets
GROUP BY product, purchase_date, ticket_type, ticket_subject,
         ticket_channel, ticket_priority, first_response_at
HAVING COUNT(*) > 1
ORDER BY tickets DESC;

-- 8a. Reconciliation: total each breakdown
SELECT 'status' AS breakdown, COUNT(*) AS groups_found, SUM(n) AS total
FROM (SELECT ticket_status, COUNT(*) AS n FROM support_tickets GROUP BY ticket_status)
UNION ALL
SELECT 'type', COUNT(*), SUM(n)
FROM (SELECT ticket_type, COUNT(*) AS n FROM support_tickets GROUP BY ticket_type)
UNION ALL
SELECT 'priority', COUNT(*), SUM(n)
FROM (SELECT ticket_priority, COUNT(*) AS n FROM support_tickets GROUP BY ticket_priority)
UNION ALL
SELECT 'channel', COUNT(*), SUM(n)
FROM (SELECT ticket_channel, COUNT(*) AS n FROM support_tickets GROUP BY ticket_channel);

-- 8b. Same check with a window function
SELECT ticket_status, COUNT(*) AS tickets,
       SUM(COUNT(*)) OVER () AS grand_total
FROM support_tickets
GROUP BY ticket_status;

-- 8c. Missing values in the grouping columns
SELECT COUNT(*) AS total_rows,
       COUNT(*) - COUNT(ticket_status)   AS null_status,
       COUNT(*) - COUNT(ticket_type)     AS null_type,
       COUNT(*) - COUNT(ticket_priority) AS null_priority,
       COUNT(*) - COUNT(ticket_channel)  AS null_channel
FROM support_tickets;
