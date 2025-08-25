create Database ShodweHotels;
SET SQL_SAFE_UPDATES = 0;
-- For dim_date
ALTER TABLE dim_date
ADD COLUMN temp_date DATE;
UPDATE dim_date
SET temp_date = STR_TO_DATE(`date`, '%d-%M-%y');
ALTER TABLE dim_date
DROP COLUMN `date`;
ALTER TABLE dim_date
CHANGE COLUMN temp_date `date` DATE;
ALTER TABLE dim_date
ADD PRIMARY KEY (`date`);

-- For dim_hotels
ALTER TABLE dim_hotels
ADD PRIMARY KEY (property_id);

-- For dim_rooms
ALTER TABLE dim_rooms
MODIFY COLUMN room_id VARCHAR(10);

-- For fact_bookings
ALTER TABLE fact_bookings
MODIFY COLUMN booking_id VARCHAR(50);
-- Add a new temporary column for booking_date
ALTER TABLE fact_bookings
ADD COLUMN temp_booking_date DATETIME;
UPDATE fact_bookings
SET temp_booking_date = STR_TO_DATE(booking_date, '%Y-%m-%d %H:%i:%s');
-- Drop the original booking_date column
ALTER TABLE fact_bookings
DROP COLUMN booking_date;
-- Rename the temporary column to booking_date
ALTER TABLE fact_bookings
CHANGE COLUMN temp_booking_date booking_date DATETIME;
-- Add a new temporary column for check_in_date
ALTER TABLE fact_bookings
ADD COLUMN temp_check_in_date DATETIME;
-- Disable safe update mode and update the new temporary column
UPDATE fact_bookings
SET temp_check_in_date = STR_TO_DATE(check_in_date, '%Y-%m-%d %H:%i:%s');
-- Drop the original check_in_date column
ALTER TABLE fact_bookings
DROP COLUMN check_in_date;
-- Rename the temporary column to check_in_date
ALTER TABLE fact_bookings
CHANGE COLUMN temp_check_in_date check_in_date DATETIME;
-- Add a new temporary column for checkout_date
ALTER TABLE fact_bookings
ADD COLUMN temp_checkout_date DATETIME;
-- Disable safe update mode and update the new temporary column
UPDATE fact_bookings
SET temp_checkout_date = STR_TO_DATE(checkout_date, '%Y-%m-%d %H:%i:%s');
-- Drop the original checkout_date column
ALTER TABLE fact_bookings
DROP COLUMN checkout_date;
-- Rename the temporary column to checkout_date
ALTER TABLE fact_bookings
CHANGE COLUMN temp_checkout_date checkout_date DATETIME;

-- For fact_aggregated_bookings
ALTER TABLE fact_aggregated_bookings
ADD COLUMN temp_check_in_date DATE;
UPDATE fact_aggregated_bookings
SET temp_check_in_date = STR_TO_DATE(check_in_date, '%d-%M-%y');
ALTER TABLE fact_aggregated_bookings
DROP COLUMN check_in_date;
ALTER TABLE fact_aggregated_bookings
CHANGE COLUMN temp_check_in_date check_in_date DATE;

-- 1 Created a grand view by connecting all the tables using joins.
CREATE OR REPLACE VIEW hotel_booking AS
SELECT
    -- Core Fact Booking Details (from fb, potentially NULL if no booking)
    fb.booking_id,
    fb.no_guests,
    fb.booking_platform,
    fb.ratings_given,
    fb.booking_status,
    fb.revenue_generated,
    fb.revenue_realized,
    fb.customer_id,
    fb.payment_method,
    fb.stay_duration,
    fb.cancellation_reason,
    fb.is_loyalty_member,
    fb.country,
    fb.customer_age,
    fb.special_requests,
    fb.discount_applied,
    fb.booking_channel,
    
    -- New net_revenue column
    CASE
        WHEN fb.booking_status = 'Cancelled' THEN fb.revenue_realized
        ELSE fb.revenue_realized - fb.discount_applied
    END AS net_revenue,

    -- Unified Key Identifiers (COALESCE to get value from any source if available)
    COALESCE(fb.property_id, dh.property_id, fab.property_id) AS unified_property_id,
    COALESCE(fb.room_category, dr.room_id, fab.room_category) AS unified_room_id,
    COALESCE(fb.check_in_date, dd.date, fab.check_in_date) AS unified_check_in_date, 

    -- Hotel Dimension Details (from dh, potentially NULL)
    dh.property_name,
    dh.category AS hotel_category,
    dh.city AS hotel_city,

    -- Room Dimension Details (from dr, potentially NULL)
    dr.room_class,

    -- Date Dimension Details (from dd, potentially NULL)
    dd.date AS dim_date_actual_date, 
    dd.`mmm yy` AS dim_date_month_year,
    dd.`week no` AS dim_date_week_no,
    dd.day_type AS dim_date_day_type,

    -- Aggregated Booking Details (from fab, potentially NULL)
    fab.successful_bookings,
    fab.capacity

FROM
    fact_bookings fb
LEFT JOIN
    dim_hotels dh ON fb.property_id = dh.property_id
LEFT JOIN
    dim_rooms dr ON fb.room_category = dr.room_id
LEFT JOIN
    dim_date dd ON DATE(fb.check_in_date) = dd.date 
LEFT JOIN
    fact_aggregated_bookings fab ON fb.property_id = fab.property_id
                                AND DATE(fb.check_in_date) = fab.check_in_date
                                AND fb.room_category = fab.room_category

UNION ALL

-- Rows from dim_hotels not matched in fact_bookings
SELECT
    NULL AS booking_id, NULL AS no_guests, NULL AS booking_platform, NULL AS ratings_given, NULL AS booking_status,
    NULL AS revenue_generated, NULL AS revenue_realized, NULL AS customer_id, NULL AS payment_method,
    NULL AS stay_duration, NULL AS cancellation_reason, NULL AS is_loyalty_member, NULL AS country,
    NULL AS customer_age, NULL AS special_requests, NULL AS discount_applied,
    NULL AS booking_channel,

    NULL AS net_revenue,

    dh.property_id AS unified_property_id,
    NULL AS unified_room_id,
    NULL AS unified_check_in_date,

    dh.property_name,
    dh.category AS hotel_category,
    dh.city AS hotel_city,

    NULL AS room_class,

    NULL AS dim_date_actual_date,
    NULL AS dim_date_month_year,
    NULL AS dim_date_week_no,
    NULL AS dim_date_day_type,

    NULL AS successful_bookings,
    NULL AS capacity
FROM
    dim_hotels dh
LEFT JOIN
    fact_bookings fb ON dh.property_id = fb.property_id
WHERE
    fb.booking_id IS NULL

UNION ALL

-- Rows from dim_rooms not matched in fact_bookings
SELECT
    NULL AS booking_id, NULL AS no_guests, NULL AS booking_platform, NULL AS ratings_given, NULL AS booking_status,
    NULL AS revenue_generated, NULL AS revenue_realized, NULL AS customer_id, NULL AS payment_method,
    NULL AS stay_duration, NULL AS cancellation_reason, NULL AS is_loyalty_member, NULL AS country,
    NULL AS customer_age, NULL AS special_requests, NULL AS discount_applied,
    NULL AS booking_channel,

    NULL AS net_revenue,

    NULL AS unified_property_id,
    dr.room_id AS unified_room_id,
    NULL AS unified_check_in_date,

    NULL AS property_name,
    NULL AS hotel_category,
    NULL AS hotel_city,

    NULL AS room_class,

    NULL AS dim_date_actual_date,
    NULL AS dim_date_month_year,
    NULL AS dim_date_week_no,
    NULL AS dim_date_day_type,

    NULL AS successful_bookings,
    NULL AS capacity
FROM
    dim_rooms dr
LEFT JOIN
    fact_bookings fb ON dr.room_id = fb.room_category
WHERE
    fb.booking_id IS NULL

UNION ALL

-- Rows from dim_date not matched in fact_bookings
SELECT
    NULL AS booking_id, NULL AS no_guests, NULL AS booking_platform, NULL AS ratings_given, NULL AS booking_status,
    NULL AS revenue_generated, NULL AS revenue_realized, NULL AS customer_id, NULL AS payment_method,
    NULL AS stay_duration, NULL AS cancellation_reason, NULL AS is_loyalty_member, NULL AS country,
    NULL AS customer_age, NULL AS special_requests, NULL AS discount_applied,
    NULL AS booking_channel,

    NULL AS net_revenue,

    NULL AS unified_property_id,
    NULL AS unified_room_id,
    dd.date AS unified_check_in_date, 

    NULL AS property_name,
    NULL AS hotel_category,
    NULL AS hotel_city,

    NULL AS room_class,

    dd.date AS dim_date_actual_date, 
    dd.`mmm yy` AS dim_date_month_year,
    dd.`week no` AS dim_date_week_no,
    dd.day_type AS dim_date_day_type,

    NULL AS successful_bookings,
    NULL AS capacity
FROM
    dim_date dd
LEFT JOIN
    fact_bookings fb ON dd.date = DATE(fb.check_in_date)
WHERE
    fb.booking_id IS NULL

UNION ALL

-- Rows from fact_aggregated_bookings not matched in fact_bookings
SELECT
    NULL AS booking_id, NULL AS no_guests, NULL AS booking_platform, NULL AS ratings_given, NULL AS booking_status,
    NULL AS revenue_generated, NULL AS revenue_realized, NULL AS customer_id, NULL AS payment_method,
    NULL AS stay_duration, NULL AS cancellation_reason, NULL AS is_loyalty_member, NULL AS country,
    NULL AS customer_age, NULL AS special_requests, NULL AS discount_applied,
    NULL AS booking_channel,

    NULL AS net_revenue,

    fab.property_id AS unified_property_id,
    fab.room_category AS unified_room_id,
    fab.check_in_date AS unified_check_in_date, 

    NULL AS property_name,
    NULL AS hotel_category,
    NULL AS hotel_city,

    NULL AS room_class,

    NULL AS dim_date_actual_date,
    NULL AS dim_date_month_year,
    NULL AS dim_date_week_no,
    NULL AS dim_date_day_type,

    fab.successful_bookings,
    fab.capacity
FROM
    fact_aggregated_bookings fab
LEFT JOIN
    fact_bookings fb ON fab.property_id = fb.property_id
                     AND fab.check_in_date = DATE(fb.check_in_date)
                     AND fab.room_category = fb.room_category
WHERE
    fb.booking_id IS NULL;

-- 2 Property Performance and Revenue Analysis
SELECT
    COALESCE(T1.property_name, 'Total') AS property_name,
    CONCAT(ROUND(SUM(T2.net_revenue) / 1000000000.0, 2), ' B') AS net_revenue,
    CONCAT(ROUND(SUM(CASE WHEN T2.booking_status <> 'Cancelled' THEN T2.discount_applied ELSE 0 END) / 1000000.0, 2), ' M') AS total_discount,
    CONCAT(ROUND(AVG(CASE WHEN T2.booking_status <> 'Cancelled' THEN T2.discount_percent END), 2), ' %') AS discount_percent,
    Concat(Round(COUNT(DISTINCT CASE WHEN T2.booking_status <> 'Cancelled' THEN T2.customer_id END)/1000,2), "K") AS unique_customers,
    ROUND(AVG(NULLIF(T2.ratings_given, '')) , 2) AS avg_rating
FROM
    dim_hotels AS T1
JOIN
    (SELECT
        property_id,
        booking_status,
        (revenue_realized - discount_applied) AS net_revenue,
        discount_applied,
        (discount_applied / revenue_realized) * 100 AS discount_percent,
        customer_id,
        ratings_given
    FROM
        fact_bookings) AS T2
ON T1.property_id = T2.property_id
GROUP BY
    T1.property_name WITH ROLLUP;

-- 3 Months by Total Revenue
SELECT
  DATE_FORMAT(dim_date_actual_date, '%Y-%m') AS month_year,
  concat(round(SUM(revenue_realized)/1000000,2)," M") AS total_monthly_revenue
FROM
  hotel_booking
GROUP BY
  month_year
ORDER BY
  total_monthly_revenue DESC
LIMIT 3;

-- 4 Low Cancellation Hotels (Stored Procedure)
DELIMITER //

CREATE PROCEDURE GetHotelsWithLowCancellations (
  IN max_cancellations_threshold INT
)
BEGIN
  SELECT
    dh.property_name,
    COUNT(fb.booking_id) AS total_cancellations
  FROM
    fact_bookings AS fb
  JOIN
    dim_hotels AS dh ON fb.property_id = dh.property_id
  WHERE
    fb.booking_status = 'Cancelled'
  GROUP BY
    dh.property_name
  HAVING
    total_cancellations < max_cancellations_threshold
  ORDER BY
    total_cancellations ASC;
END //

DELIMITER ;

-- 5 High-Utilized Hotel Properties by Bookings
SELECT
    t2.property_name,
    CONCAT(ROUND(SUM(t1.successful_bookings)/1000,2), " K") AS total_successful_bookings,
    CONCAT(ROUND(SUM(t1.capacity)/1000,2)," K") AS total_capacity,
    Concat(ROUND((SUM(t1.successful_bookings) / SUM(t1.capacity)) * 100,2)," %") AS capacity_utilization_percentage
FROM
    fact_aggregated_bookings AS t1
JOIN
    dim_hotels AS t2 ON t1.property_id = t2.property_id
GROUP BY
    t2.property_name;

-- 6 May 2022 Property-wise Booking Summary
SELECT
    COALESCE(dh.property_name, 'Total') AS property_name,
    concat(round(SUM(fab.successful_bookings)/1000,2), " K") AS Bookings_through_MAY
FROM
    fact_aggregated_bookings AS fab
JOIN
    dim_hotels AS dh ON fab.property_id = dh.property_id
WHERE
    fab.check_in_date BETWEEN '2022-05-01' AND '2022-05-31'
GROUP BY
    dh.property_name WITH ROLLUP;

-- 7 Hotel and Room Class Revenue and Booking Summary
SELECT
  dh.property_name,
  dh.category AS hotel_category,
  dh.city,
  dr.room_class,
  CONCAT(ROUND(SUM(fb.revenue_realized) / 1000000, 2), "M") AS total_revenue,
  CONCAT(ROUND(COUNT(fb.booking_id) / 1000, 2), "K") AS total_bookings
FROM dim_hotels AS dh
JOIN fact_bookings AS fb
  ON dh.property_id = fb.property_id
JOIN dim_rooms AS dr
  ON fb.room_category = dr.room_id
GROUP BY
  dh.property_name,
  dh.category,
  dh.city,
  dr.room_class WITH ROLLUP
ORDER BY
  dh.property_name,
  dr.room_class;


-- 8 Loyalty Members Count
SELECT
  T2.city,
  CONCAT(ROUND(COUNT(DISTINCT T1.customer_id) / 1000, 2), ' K') AS loyalty_members
FROM
  fact_bookings AS T1
JOIN
  dim_hotels AS T2 ON T1.property_id = T2.property_id
WHERE
  T1.is_loyalty_member = 'TRUE'
GROUP BY
  T2.city
ORDER BY
  T2.city;

-- 9 Repeat Customers by Month
SELECT
  `mmm yy`,
  COUNT(DISTINCT customer_id) AS repeated_customers
FROM
  (
    SELECT
      f.customer_id,
      d.`mmm yy`,
      d.date
    FROM
      fact_bookings AS f
    JOIN
      dim_date AS d ON f.booking_date = d.date
    GROUP BY
      f.customer_id,
      d.`mmm yy`,
      d.date
    HAVING
      COUNT(f.booking_id) > 1
  ) AS monthly_repeats
GROUP BY
  `mmm yy`
ORDER BY
  MIN(date);

-- 10 Monthly Guest Count by Booking Platform
SELECT
  COALESCE(T1.booking_platform, 'Total') AS booking_platform,
  COALESCE(T2.`mmm yy`, 'Total') AS month_year,
  CONCAT(ROUND(SUM(T1.no_guests) / 1000, 2), ' K') AS total_guests
FROM
  fact_bookings AS T1
INNER JOIN
  dim_date AS T2 ON T1.check_in_date = T2.date
GROUP BY
  T1.booking_platform,
  T2.`mmm yy` WITH ROLLUP
ORDER BY
  T2.`mmm yy`,
  T1.booking_platform;
    
-- 11 weekdays vs weekend
SELECT
    T2.day_type,
    concat(round(COUNT(T1.booking_id)/1000,2), " K") AS total_bookings
FROM
    fact_bookings AS T1
JOIN
    dim_date AS T2 ON DATE(T1.check_in_date) = T2.date
GROUP BY
    T2.day_type
ORDER BY
    total_bookings DESC;
    
-- 12 Average Stay Duration by City
SELECT
    COALESCE(T2.city, 'Total') AS city,
    AVG(T1.stay_duration) AS average_stay_duration
FROM
    fact_bookings AS T1
JOIN
    dim_hotels AS T2 ON T1.property_id = T2.property_id
GROUP BY
    T2.city WITH ROLLUP;
    
-- 11 Longest Stay Booking
SELECT T2.property_name, T1.stay_duration
FROM fact_bookings AS T1
INNER JOIN dim_hotels AS T2
  ON T1.property_id = T2.property_id
ORDER BY
  T1.stay_duration DESC
LIMIT 1;
  
-- 13
-- trigger
DELIMITER $$
CREATE TRIGGER tr_generate_custom_booking_id
BEFORE INSERT ON fact_bookings
FOR EACH ROW
BEGIN
    IF NEW.booking_id IS NULL OR NEW.booking_id = '' THEN
        SET NEW.booking_id = CONCAT(
            DATE_FORMAT(NOW(), '%b%d%y'),   -- 'Jul3122' part
            DATE_FORMAT(NOW(), '%H%i%s'),   -- Time part (e.g., '19559' would be 19:55:09)
            'RT',
            LPAD(FLOOR(RAND() * 1000), 3, '0') -- Random 3-digit number
        );
    END IF;
END$$
DELIMITER ;

-- trigger check
INSERT INTO fact_bookings (
  booking_id,
  property_id,
  no_guests,
  room_category,
  booking_platform,
  ratings_given,
  booking_status,
  revenue_generated,
  revenue_realized,
  customer_id,
  payment_method,
  stay_duration,
  cancellation_reason,
  is_loyalty_member,
  country,
  customer_age,
  special_requests,
  discount_applied,
  booking_channel,
  booking_date,
  check_in_date,
  checkout_date
)
VALUES (
  null, -- booking_id (or NULL if you use the trigger)
  101,          -- property_id
  2,            -- no_guests
  'RT3',     -- room_category
  'Website',    -- booking_platform
  '5',          -- ratings_given
  'Confirmed',  -- booking_status
  2500,         -- revenue_generated
  2500,         -- revenue_realized
  4567,         -- customer_id
  'Credit Card',-- payment_method
  3,            -- stay_duration
  NULL,         -- cancellation_reason
  'TRUE',       -- is_loyalty_member
  'India',      -- country
  35,           -- customer_age
  'Extra pillow',-- special_requests
  0.0,          -- discount_applied
  'Online',     -- booking_channel
  '2022-08-22 10:00:00', -- booking_date
  '2022-09-01 14:00:00', -- check_in_date
  '2022-09-04 11:00:00'  -- checkout_date
);