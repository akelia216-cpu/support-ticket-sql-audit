-- Customer Support Ticket Dataset (Kaggle, suraj520, CC0). Synthetic data.
-- Dropped: customer name, email, age, gender, ticket description, resolution text.
CREATE TABLE support_tickets (
  ticket_id          NUMBER PRIMARY KEY,
  product            VARCHAR2(60),
  purchase_date      DATE,
  ticket_type        VARCHAR2(40),
  ticket_subject     VARCHAR2(60),
  ticket_status      VARCHAR2(40),
  ticket_priority    VARCHAR2(20),
  ticket_channel     VARCHAR2(20),
  first_response_at  TIMESTAMP,
  resolved_at        TIMESTAMP,
  csat_rating        NUMBER(1)
);
