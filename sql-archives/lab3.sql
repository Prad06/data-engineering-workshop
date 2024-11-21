CREATE TYPE vertex_type
    AS ENUM('player', 'team', 'game');


CREATE TABLE vertices (
    identifier TEXT,
    type vertex_type,
    properties JSON,
    PRIMARY KEY (identifier, type)
);

CREATE TYPE edge_type AS
    ENUM ('plays_against',
          'shares_team',
          'plays_in',
          'plays_on'
        );

CREATE TABLE edges (
    subject_identifier TEXT,
    subject_type vertex_type,
    object_identifier TEXT,
    object_type vertex_type,
    edge_type edge_type,
    properties JSON,
    PRIMARY KEY (subject_identifier,
                subject_type,
                object_identifier,
                object_type,
                edge_type)
);

INSERT INTO vertices
WITH teams_deduped AS (
	SELECT *, ROW_NUMBER() OVER(PARTITION BY team_id) as row_num
	FROM teams
)
SELECT 
	team_id AS identifier,
	'team'::vertex_type AS type,
	json_build_object(
		'abbreviation', abbreviation,
		'nickname', nickname,
		'city', city,
		'arena', arena,
		'year_founded', yearfounded
	)
FROM teams_deduped
WHERE row_num = 1;

SELECT type, COUNT(1)
FROM vertices
GROUP BY 1;

-- MOVING ON TO EDGES TABLES
SELECT * FROM game_details;

SELECT 
	player_id AS subject_identifier,
	'player'::vertex_type as subject_type,
	game_id AS object_identifier, 
	'game'::vertex_type AS object_type,
	'plays_in'::edge_type AS edge_type,
	json_build_object(
		'start_position', start_position,
		'pts', pts,
		'team_id', team_id,
		'team_abbreviation', team_abbreviation
	) as properties
FROM game_details;

SELECT * FROM edges;

SELECT * FROM game_details
WHERE player_id = 1628370
and game_id = 22000069;

SELECT player_id, game_id, count(1) FROM game_details
GROUP BY 1, 2;

SELECT player_id, game_id, count(1) as times FROM game_details
GROUP BY 1, 2
HAVING count(1) > 1;

INSERT INTO edges
WITH game_details_deduped AS (
	SELECT *, ROW_NUMBER() OVER(PARTITION BY player_id, game_id) as row_num
	FROM game_details
)
SELECT 
	player_id AS subject_identifier,
	'player'::vertex_type as subject_type,
	game_id AS object_identifier, 
	'game'::vertex_type AS object_type,
	'plays_in'::edge_type AS edge_type,
	json_build_object(
		'start_position', start_position,
		'pts', pts,
		'team_id', team_id,
		'team_abbreviation', team_abbreviation
	) as properties
FROM game_details_deduped
WHERE row_num = 1;

-- GET THE MAX POINTS SCORED BY A PLAYER
SELECT 
	v.properties ->> 'player_name',
	MAX(e.properties ->> 'pts')
FROM vertices v JOIN edges e
ON e.subject_identifier = v.identifier
AND e.subject_type = v.type
GROUP BY 1
ORDER BY 2 DESC;

WITH game_details_deduped AS (
	SELECT *, ROW_NUMBER() OVER(PARTITION BY player_id, game_id) as row_num
	FROM game_details
),
filtered AS (
	SELECT * FROM game_details_deduped
	WHERE row_num = 1
)

SELECT * FROM filtered f;

INSERT INTO edges
WITH game_details_deduped AS (
	SELECT *, ROW_NUMBER() OVER(PARTITION BY player_id, game_id) as row_num
	FROM game_details
),
filtered AS (
	SELECT * FROM game_details_deduped
	WHERE row_num = 1
),
aggregated AS (
	SELECT 
		MAX(f1.player_name) as subject_player_name,
		f1.player_id as subject_player_id,
		MAX(f2.player_name) as object_player_name,
		f2.player_id as object_player_id,
		CASE WHEN f1.team_abbreviation = f2.team_abbreviation THEN 'shares_team'::edge_type
		ELSE 'plays_against'::edge_type
		END as edge_type,
		COUNT(1) AS num_games,
		SUM(f1.pts) AS left_points, 
		SUM(f2.pts) AS right_points
	FROM filtered f1
	JOIN filtered f2
	ON f1.game_id = f2.game_id
	AND f1.player_name <> f2.player_name
	WHERE f1. player_id > f2.player_id -- MAKE SINGLE EDGES
	GROUP BY 
		f1.player_id,
		f2.player_id,
		CASE WHEN f1.team_abbreviation = f2.team_abbreviation THEN 'shares_team'::edge_type
		ELSE 'plays_against'::edge_type
		END
)
SELECT 
	subject_player_id AS subject_identifier,
	'player'::vertex_type AS subject_type,
	object_player_id AS object_identifier,
	'player'::vertex_type AS object_type,
	edge_type AS edge_type,
	json_build_object(
		'num_games', num_games,
		'subject_points', left_points,
		'object_points', right_points
	)
FROM aggregated;


SELECT * FROM edges;


SELECT 
	v.properties ->> 'player_name' as player_name,
	e.object_identifier,
	CAST(v.properties ->> 'number_of_games' AS REAL)/
	CASE WHEN CAST(v.properties ->> 'total_points' AS REAL) = 0 THEN 1 ELSE CAST(v.properties ->> 'total_points' AS REAL) END,
	e.properties ->> 'subject_points',
	e.properties ->> 'num_games'
FROM vertices v
JOIN edges e
ON v.identifier = e.subject_identifier
AND v.type = e.subject_type
WHERE e.object_type = 'player'::vertex_type
ORDER BY player_name;