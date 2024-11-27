DROP TABLE users_cummulated;

SELECT * FROM EVENTS;

CREATE TABLE users_cummulated(
	user_id TEXT,
	-- LIST OF DATES IN PAST WHERE THE USER WAS ACTIVE
	dates_active DATE[],
	-- CURRENT_DATE
	date DATE,
	PRIMARY KEY(user_id, date)
);

-- QUERY RUN FOR DEC 31, 2022 to JAN 31, 2023
INSERT INTO users_cummulated
WITH
	YESTERDAY AS (
		SELECT
			*
		FROM
			USERS_CUMMULATED
		WHERE
			DATE = DATE ('2023-01-30')
	),
	TODAY AS (
		SELECT
			CAST(USER_ID as TEXT) AS user_id,
			CAST(EVENT_TIME AS TIMESTAMP)::DATE AS DATE_ACTIVE
		FROM
			EVENTS
		WHERE
			CAST(EVENT_TIME AS TIMESTAMP)::DATE = DATE ('2023-01-31')
			AND USER_ID IS NOT NULL
		GROUP BY
			USER_ID,
			CAST(EVENT_TIME AS TIMESTAMP)::DATE
	)
SELECT
	COALESCE (t.user_id, y.user_id) as user_id,
	CASE 
		WHEN y.dates_active IS NULL
		THEN ARRAY[t.date_active]
		WHEN t.date_active IS NULL
		THEN y.dates_active
		ELSE ARRAY[t.date_active] || y.dates_active
		END
	as dates_active,
	COALESCE(t.date_active, y.date + INTERVAL '1 DAY') as date
FROM
	yesterday y
FULL OUTER JOIN
	today t
ON t.user_id = y.user_id;

-- DATA READY
SELECT * FROM users_cummulated WHERE date = DATE('2023-01-31')

-- THIS TABLE HAS LIST OF ALL ACTIVE DATES
WITH USERS AS (
	SELECT * FROM users_cummulated
	WHERE date = DATE('2023-01-31')
),
-- HERE WE GENERATE DATES FROM JAN 1 TO JAN 31
series AS (
	SELECT * FROM generate_series(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 Day') as series_date
),
-- THE DATES ARE CROSS JOINED WITH USERS TABLE
-- WE BASICALLY GET THE 2 TO THE POWER OF 32 
-- WHICH WHEN CONVERTED TO BITS BECOMES A REPRESENTATION OF
-- LAST 31 DATES OF A PERSONS ACTIVITY
place_holder_int AS (
	SELECT 
		date - DATE(series_date), 
		CASE WHEN
			dates_active @> ARRAY[DATE(series_date)] 
		THEN CAST(POW(2, 32 - (date - DATE(series_date))) AS BIGINT)
		ELSE 0
		END as placeholder_int_value, 
		* 
	FROM USERS CROSS JOIN series
)
SELECT 
	user_id,
	SUM(placeholder_int_value)::BIGINT::BIT(32),
	BIT_COUNT(SUM(placeholder_int_value)::BIGINT::BIT(32)) as dim_monthly_active_for_n_days,
	BIT_COUNT(SUM(placeholder_int_value)::BIGINT::BIT(32)) > 0 as dim_is_monthly_active,
	BIT_COUNT(SUM(placeholder_int_value)::BIGINT::BIT(32) &
       CAST('11111110000000000000000000000000' AS BIT(32))) > 0 AS weekly_active,
    BIT_COUNT(SUM(placeholder_int_value)::BIGINT::BIT(32) &
       CAST('10000000000000000000000000000000' AS BIT(32))) > 0 AS daily_active
FROM place_holder_int
GROUP BY user_id
ORDER BY 3 DESC;