-- CREATE TABLE FOR METRICS TO CREATE FACTS ON TOP OF EVENTS TABLE
CREATE TABLE ARRAY_METRICS (
	USER_ID NUMERIC,
	MONTH_START DATE,
	METRIC_NAME TEXT,
	METRIC_ARRAY REAL[],
	PRIMARY KEY (USER_ID, MONTH_START, METRIC_NAME)
);

TRUNCATE TABLE ARRAY_METRICS;

-- CREATE A DAILY AGGREGATE TABLE
INSERT INTO
	ARRAY_METRICS
WITH
	DAILY_AGGREGATE AS (
		SELECT
			USER_ID,
			DATE (EVENT_TIME) AS DATE,
			COUNT(1) AS NUM_SITE_HITS
		FROM
			EVENTS
		WHERE
			DATE (EVENT_TIME) = DATE ('2023-01-06')
			AND USER_ID IS NOT NULL
		GROUP BY
			USER_ID,
			DATE (EVENT_TIME)
	),
	YESTERDAY_ARRAY AS (
		SELECT
			*
		FROM
			ARRAY_METRICS
		WHERE
			MONTH_START = DATE ('2023-01-01')
	)
SELECT
	COALESCE(DA.USER_ID, YA.USER_ID) AS USER_ID,
	COALESCE(YA.MONTH_START, DATE_TRUNC('month', DA.DATE)) AS MONTH,
	'site_hits' AS METRIC_NAME,
	CASE
		WHEN YA.METRIC_ARRAY IS NOT NULL THEN YA.METRIC_ARRAY || ARRAY[COALESCE(DA.NUM_SITE_HITS, 0)]
		WHEN YA.METRIC_ARRAY IS NULL THEN ARRAY_FILL(
			0,
			ARRAY[
				COALESCE(DATE - DATE_TRUNC('month', DATE)::DATE, 0)
			]
		) || ARRAY[COALESCE(DA.NUM_SITE_HITS, 0)]
	END AS METRIC_ARRAY
FROM
	DAILY_AGGREGATE DA
	FULL OUTER JOIN YESTERDAY_ARRAY YA ON DA.USER_ID = YA.USER_ID
	-- UPDATE OVERWRITE CONDITION
ON CONFLICT (USER_ID, MONTH_START, METRIC_NAME) DO
UPDATE
SET
	METRIC_ARRAY = EXCLUDED.METRIC_ARRAY;

-- DAILY AGG for the metrics
WITH
	AGG AS (
		SELECT
			METRIC_NAME,
			MONTH_START,
			ARRAY[
				SUM(METRIC_ARRAY[1]),
				SUM(METRIC_ARRAY[2]),
				SUM(METRIC_ARRAY[3])
			] AS SUMMED_ARRAY
		FROM
			ARRAY_METRICS
		GROUP BY
			METRIC_NAME,
			MONTH_START
	)
SELECT
	METRIC_NAME,
	MONTH_START + CAST(CAST(INDEX -1 AS TEXT) || ' day' AS INTERVAL),
	ELEM AS VALUE
FROM
	AGG
	CROSS JOIN UNNEST(AGG.SUMMED_ARRAY)
WITH
	ORDINALITY AS A (ELEM, INDEX);