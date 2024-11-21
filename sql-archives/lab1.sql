
SELECT * FROM player_seasons;

-- ONE ROW PER PLAYER WITH A ARRAY OF DATA RELATED TO SEASON
-- THIS IS A SEASON STAT STRUCT, a type defined to hold all the data that is related to the player during one season.
CREATE TYPE season_stats AS (
	season INTEGER,
	gp INTEGER,
	pts REAL,
	reb REAL,
	ast REAL
);

--NEW TABLE -> All of the columns at the player level so that you don't duplicate it and the stats that will be on the season level!
CREATE TABLE players (
	-- ALL THE VALUES THAT DON'T REALLY CHANGE IN A DATASET
	player_name TEXT,
	height TEXT,
	college TEXT,
	country TEXT,
	draft_year TEXT,
	draft_round TEXT,
	draft_number TEXT,
	-- NEW THINGS -> season_stats to store the data
	season_stats season_stats[],
	-- DEVELOPING THE TABLE CUMULATIVELY (will hold the current column)
	current_season INTEGER,
	PRIMARY KEY(player_name, current_season)
)

-- FULL OUTER JOIN LOGIC
SELECT MIN(SEASON) FROM player_seasons; 
-- RETURNS 1996, so the least season is 1996!

-- TODAY AND YESTERDAY QUERY
-- THIS QUERY WILL HAVE ALL VALUES AS NULL
WITH yesterday AS (
	SELECT * FROM players
	WHERE current_season = 1995
), today AS (
	SELECT * FROM player_seasons
	WHERE season = 1996
)

-- THIS QUERY WILL HAVE ALL VALUES AS NULL
SELECT * FROM today t FULL OUTER JOIN yesterday y
ON t.player_name = y.player_name;

-- SEED QUERY FOR CUMMILATION, MANAGES TO GET THE FIRST DATA
-- FOR ME The COALESCE function returns the first of its arguments that is not null. Null is returned only if all arguments are null. It is often used to substitute a default value for null values when data is retrieved for display.
WITH yesterday AS (
	SELECT * FROM players
	WHERE current_season = 1995
), today AS (
	SELECT * FROM player_seasons
	WHERE season = 1996
)

SELECT 
	COALESCE(t.player_name, y.player_name) AS player_name,
	COALESCE(t.height, y.height) AS height,
	COALESCE(t.college, y.college) AS college,
	COALESCE(t.country, y.country) AS country,
	COALESCE(t.draft_year, y.draft_year) AS draft_year,
	COALESCE(t.draft_round, y.draft_round) AS draft_round,
	COALESCE(t.draft_number, y.draft_number) AS draft_number
	FROM today t FULL OUTER JOIN yesterday y
ON t.player_name = y.player_name;

--SLOWLY BUILDING UP THE FULL TABLE
INSERT INTO players
WITH yesterday AS (
	SELECT * FROM players
	WHERE current_season = 1996 --ORG STARTING FROM 1995, change these values and get the output.
), today AS (
	SELECT * FROM player_seasons
	WHERE season = 1997
)
SELECT 
	COALESCE(t.player_name, y.player_name) AS player_name,
	COALESCE(t.height, y.height) AS height,
	COALESCE(t.college, y.college) AS college,
	COALESCE(t.country, y.country) AS country,
	COALESCE(t.draft_year, y.draft_year) AS draft_year,
	COALESCE(t.draft_round, y.draft_round) AS draft_round,
	COALESCE(t.draft_number, y.draft_number) AS draft_number,
	CASE WHEN y.season_stats IS NULL
		THEN ARRAY[ROW(
			t.season,
			t.gp,
			t.pts,
			t.reb,
			t.ast
		)::season_stats]
	-- WE DON'T WANT TO KEEP ADDING VALUES IF SOMEONE HAS RETIRED
	-- CREATING NEW VALUE
	WHEN t.season IS NOT NULL THEN y.season_stats || ARRAY[ROW(
			t.season,
			t.gp,
			t.pts,
			t.reb,
			t.ast
		)::season_stats]
	-- CARRYING THE HISTORY FORWARD
	ELSE y.season_stats
	END as season_stats,
	COALESCE(t.season, y.current_season+1) as current_season
	FROM today t FULL OUTER JOIN yesterday y
ON t.player_name = y.player_name;

-- GET THE DATA FOR MICHEAL JORDAN FOR SEASON 2001, and see the anamoly that we have a few missing seasons as he had left the game
SELECT * FROM players WHERE current_season = 2001 and player_name = 'Michael Jordan';

USING THE UNNEST QUERY YOU CAN EASILY GET THE DATA FOR ALL THREE SEASONS
SELECT 
	player_name, 
	UNNEST(season_stats)::season_stats AS season_stats
FROM players
WHERE current_season = 2001
and player_name = 'Michael Jordan';

-- EXPLODE IT OUT TO GET ALL THE COLUMNS
WITH UNNESTED AS
(SELECT 
	player_name, 
	UNNEST(season_stats)::season_stats AS season_stats
FROM players
WHERE current_season = 2001
and player_name = 'Michael Jordan')
SELECT 
	player_name, 
	(season_stats::season_stats).*
FROM 
	UNNESTED;

-- EVEN IF WE SKIP THE player_name, all the names are kept sorted in the table which helps with the run length encoding part.
WITH UNNESTED AS
(SELECT 
	player_name, 
	UNNEST(season_stats)::season_stats AS season_stats
FROM players
WHERE current_season = 2001)
SELECT 
	player_name, 
	(season_stats::season_stats).*
FROM 
	UNNESTED;

-- DROPPING THE PLAYERS TABLE TO ADD A SCORING CLASS FEATURE
DROP TABLE players;

-- CREATING A STORING CLASS COLUMN TO PUT PLAYERS INTO BINS
CREATE TYPE scoring_class AS ENUM ('star', 'good', 'avg', 'bad');

CREATE TABLE PLAYERS (
	-- ALL THE VALUES THAT DON'T REALLY CHANGE IN A DATASET
	player_name TEXT,
	height TEXT,
	college TEXT,
	country TEXT,
	draft_year TEXT,
	draft_round TEXT,
	draft_number TEXT,
	-- NEW THINGS -> season_stats to store the data
	season_stats season_stats[],
	-- ADDING THE SCORING CLASS METRIC
	scoring_class scoring_class,
	years_since_last_season INTEGER,
	-- DEVELOPING THE TABLE CUMULATIVELY (will hold the current column)
	current_season INTEGER,
	PRIMARY KEY(player_name, current_season)
)

-- POPULATING THE NEW TABLE
INSERT INTO players
WITH yesterday AS (
	SELECT * FROM players
	WHERE current_season = 2000 --ORG STARTING FROM 1995, change these values and get the output.
), today AS (
	SELECT * FROM player_seasons
	WHERE season = 2001
)
SELECT 
	COALESCE(t.player_name, y.player_name) AS player_name,
	COALESCE(t.height, y.height) AS height,
	COALESCE(t.college, y.college) AS college,
	COALESCE(t.country, y.country) AS country,
	COALESCE(t.draft_year, y.draft_year) AS draft_year,
	COALESCE(t.draft_round, y.draft_round) AS draft_round,
	COALESCE(t.draft_number, y.draft_number) AS draft_number,
	CASE WHEN y.season_stats IS NULL
		THEN ARRAY[ROW(
			t.season,
			t.gp,
			t.pts,
			t.reb,
			t.ast
		)::season_stats]
	-- WE DON'T WANT TO KEEP ADDING VALUES IF SOMEONE HAS RETIRED
	-- CREATING NEW VALUE
	WHEN t.season IS NOT NULL THEN y.season_stats || ARRAY[ROW(
			t.season,
			t.gp,
			t.pts,
			t.reb,
			t.ast
		)::season_stats]
	-- CARRYING THE HISTORY FORWARD
	ELSE y.season_stats
	END as season_stats,
	-- SCORING CLASS LOGIC
	CASE 
		WHEN t.season IS NOT NULL THEN
			CASE 
				WHEN t.pts > 20 THEN 'star'
				WHEN t.pts > 15 THEN 'good'
				WHEN t.pts > 10 THEN 'avg'
			ELSE 'bad'
		END::scoring_class
		ELSE y.scoring_class
	END as scoring_class,
	-- YEARS SINCE LAST SEASON LOGIC
	CASE 
		WHEN t.season IS NOT NULL THEN 0
		ELSE y.years_since_last_season + 1
	END as years_since_last_season,
	COALESCE(t.season, y.current_season+1) as current_season
	FROM today t FULL OUTER JOIN yesterday y
ON t.player_name = y.player_name;

-- COOL QUERIES/ANALYTICS
-- THIS QUERY WE DON'T HAVE A GROUP BY 
-- EVERYTHING HAPPENS IN A MAP STEP THERE IS NO REDUCE STEP
-- SPARK CAN PARALLELIZE THIS QUERY AND RUN IT VERY FAST!
SELECT 
    player_name,
    -- Points scored in the first season
    (season_stats[1]::season_stats).pts AS first_season,
    -- Points scored in the latest season
    (season_stats[CARDINALITY(season_stats)]::season_stats).pts AS latest_season,
    -- Improvement ratio calculation
    (season_stats[CARDINALITY(season_stats)]::season_stats).pts / 
    CASE 
        WHEN (season_stats[1]::season_stats).pts = 0 THEN 1 
        ELSE (season_stats[1]::season_stats).pts 
    END AS improvement
FROM players
WHERE current_season = 2001
AND scoring_class = 'star'
ORDER BY 4 DESC;

-- LAB 2
INSERT INTO players
WITH years AS (
	SELECT *
	FROM generate_series(1996, 2022) as season
),
	p AS (
		SELECT player_name, MIN(season) as first_season
		FROM player_seasons
		GROUP BY player_name
	),
	players_and_seasons AS (
		SELECT * 
		FROM p
		JOIN years y ON p.first_season <= y.season
	),
	windowed AS (
	SELECT 
		ps.player_name,
		ps.season,
		array_remove(ARRAY_AGG(CASE
				WHEN p1.season IS NOT NULL THEN 
				ROW (p1.season, p1.gp, p1.pts, p1.reb, p1.ast)
			END) 
			OVER (PARTITION BY ps.player_name), NULL) AS season_stats
		FROM players_and_seasons ps
		LEFT JOIN player_seasons p1 ON ps.player_name = p1.player_name AND ps.season = p1.season
	)
SELECT 
	player_name,
	NULL AS height,
	NULL AS college,
	NULL AS country,
	NULL AS draft_year,
	NULL AS draft_round,
	NULL AS draft_number,
	season_stats,
	NULL AS scoring_class,
	NULL AS years_since_last_season,
	season AS current_season
FROM windowed
JOIN static s ON windowed.player_name = s.player_name;
