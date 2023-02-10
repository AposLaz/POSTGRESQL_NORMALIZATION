DROP TABLE IF EXISTS movies CASCADE;
DROP TABLE IF EXISTS critics CASCADE;
DROP TABLE IF EXISTS description CASCADE;
DROP TABLE IF EXISTS genre CASCADE;
DROP TABLE IF EXISTS directors CASCADE;
DROP TABLE IF EXISTS stars CASCADE;
DROP TABLE IF EXISTS dates CASCADE;
DROP TABLE IF EXISTS costs CASCADE;


CREATE TABLE movies (
	ID SERIAL,
	MOVIES VARCHAR(200) DEFAULT NULL,
	YEAR VARCHAR(50) DEFAULT NULL,
	GENRE VARCHAR(50) DEFAULT NULL,
	RATING FLOAT DEFAULT NULL,
	ONELINE TEXT DEFAULT NULL,
	STARS TEXT DEFAULT NULL,
	VOTES VARCHAR(50) DEFAULT NULL,
	RunTime INT DEFAULT NULL,
	Gross VARCHAR(50) DEFAULT NULL,
	PRIMARY KEY (ID)
); 

--IMPORT CSV --- SET YOUR CSV PATH
COPY movies(MOVIES, YEAR, GENRE, RATING, ONELINE, STARS,VOTES,RunTime,Gross)
FROM '/var/lib/postgresql/data/movies.csv'
DELIMITER ','
CSV HEADER;

--remove special characters FROM movies
UPDATE movies SET movies = regexp_replace(movies, '[^\w\s]', '', 'g'),
				  YEAR = regexp_replace(YEAR, '[^0-9]+', '', 'g');
				  
--SET EMPTY VALUE TO NULL
UPDATE movies SET YEAR = NULLIF(YEAR,''), 
                  GROSS = NULLIF(GROSS,'');

--TRIM AND REMOVE NEWLINES
UPDATE movies
	SET STARS = regexp_replace(STARS, E'[\\n\\r]+', '', 'g' ),
		ONELINE = regexp_replace(ONELINE, E'[\\n\\r]+', '', 'g' ),
		GENRE = regexp_replace(genre, E'[\\n\\r]+', '', 'g' );

UPDATE movies
  SET STARS = TRIM(LEADING FROM STARS),
  	  ONELINE = TRIM(LEADING FROM ONELINE),
	  MOVIES = TRIM(LEADING FROM MOVIES),
	  GENRE = TRIM(GENRE);

--IF THERE ARE MANY YEARS THEN THIS MOVIE IS SERIE
CREATE VIEW series_movies AS 
	SELECT ID,movies,LEFT(YEAR,4) as start_year,RIGHT(YEAR,4) as end_year, GENRE, RATING, ONELINE, STARS, VOTES, RUNTIME, GROSS
	FROM movies
	WHERE LENGTH(YEAR)>5
	UNION ALL
	SELECT ID, movies, YEAR as start_year,(SELECT NULL) as end_year, GENRE, RATING, ONELINE, STARS, VOTES, RUNTIME, GROSS 
	FROM movies 
	WHERE LENGTH(YEAR)<5 OR YEAR IS NULL 
;

--GIVE ID TO MOVIES FOR BREAK THE TABLE
CREATE VIEW series_movie_with_movie_id AS 
	SELECT ID,movies,DENSE_RANK() OVER(ORDER BY movies,start_year) as movie_id
		   ,start_year,end_year, GENRE, RATING, ONELINE, STARS, VOTES, RUNTIME, GROSS
	FROM series_movies 
	ORDER BY movies
;

--CREATE VIEW REMOVE DUPLICATES ID -- DELETE VALUES WITH NULL YEAR -- remove multivalues from GENRE
CREATE VIEW clear_duplicate_movies AS(
    SELECT movie_id, movies , CAST(start_year AS INT),CAST(end_year AS INT),gross
	FROM series_movie_with_movie_id
	GROUP BY movies,movie_id, start_year,end_year,gross
	ORDER BY movie_id
);


CREATE VIEW genre_view AS(
	SELECT movie_id,movies, unnest(string_to_array(GENRE, ',')) as genre
	FROM series_movie_with_movie_id
	GROUP BY movie_id,movies,GENRE
	ORDER BY movie_id 
);

CREATE TABLE movies_group (
	ID SERIAL,
	MOVIES VARCHAR(200),
	start_year INT,
	end_year INT,
	Gross VARCHAR(50),
	PRIMARY KEY (ID)
);

CREATE TABLE movies_info (
	ID SERIAL,
	RATING FLOAT DEFAULT NULL,
	ONELINE TEXT DEFAULT NULL,
	STARS TEXT DEFAULT NULL,
	VOTES VARCHAR(50) DEFAULT NULL,
	RunTime INT DEFAULT NULL,
	movie_id INT NOT NULL,
	PRIMARY KEY (ID),
	CONSTRAINT fk_movie_info
      FOREIGN KEY(movie_id) 
	  REFERENCES movies_group(ID) ON DELETE CASCADE
);

CREATE TABLE genre_table (
	ID SERIAL,
	GENRE VARCHAR(50) DEFAULT NULL,
	movie_id INT NOT NULL,
	PRIMARY KEY (ID),
	CONSTRAINT fk_genre_movie
	  FOREIGN KEY(movie_id) 
	  REFERENCES movies_group(ID) ON DELETE CASCADE
);

INSERT INTO movies_group 
SELECT movie_id, movies , CAST(start_year AS INT),CAST(end_year AS INT),gross 
	FROM clear_duplicate_movies
	ORDER BY movies;

INSERT INTO genre_table
SELECT ROW_NUMBER() OVER(ORDER BY movie_id) as ID, genre, movie_id
	FROM genre_view;

--CLEAR genre TABLE FROM DUPLICATE VALUES
DELETE  FROM
    genre_table a
        USING genre_table b
WHERE a.id > b.id AND a.movie_id = b.movie_id AND a.genre = b.genre;

INSERT INTO movies_info
SELECT ROW_NUMBER() OVER(ORDER BY movie_id) as ID, RATING, ONELINE, STARS, VOTES, RUNTIME, movie_id
	FROM series_movie_with_movie_id
	ORDER BY movie_id;

-- DROP UNUSED TABLES
DROP TABLE IF EXISTS movies CASCADE;

--REPLACE DIRECTOR WITH DIRECTORS
UPDATE movies_info
	SET STARS = REPLACE(STARS,'Directors','Director');
UPDATE movies_info
	SET STARS = REPLACE(STARS,'Director','Directors');
UPDATE movies_info
	SET STARS = REPLACE(STARS,'Stars','Star');
UPDATE movies_info
	SET STARS = REPLACE(STARS,'Star','Stars');
	
-- NULL no values
UPDATE movies_info
	SET STARS = NULLIF(STARS,'');

-- HAVE TO CREATE A NEW TABLE FOR DIRECTORS AND STARS
CREATE VIEW movies_info_dir_stars AS 
	SELECT *, left(stars, strpos(stars, '|') - 1) as Directors, substring(stars, '[^|]*$') as StarsOnly
	FROM movies_info as a 
	ORDER BY ID
;

CREATE VIEW movies_info_dir_stars_clear_stage_1 AS
	SELECT id,rating, oneline,votes,runtime,movie_id,CAST((directors = NULL) AS TEXT) as directors_clear, starsonly as stars
	FROM movies_info_dir_stars
	WHERE directors LIKE '%Stars%'
	UNION
	SELECT id,rating, oneline,votes,runtime,movie_id,directors as directors_clear, CAST((directors = NULL) AS TEXT) as stars
	FROM movies_info_dir_stars
	WHERE directors LIKE '%Director%'
	UNION
	SELECT id,rating, oneline,votes,runtime,movie_id,directors as directors_clear, starsonly as stars
	FROM movies_info_dir_stars
	WHERE directors IS NULL
	ORDER BY ID
;


--CREATE 2 NEW TABLES FOR TABLE MOVIES INFO

-- first create a helper table for remove duplicates from movies_info_dir_stars_clear_stage_1
CREATE TABLE movies_info_delete_duplicates (
	ID SERIAL,
	RATING FLOAT DEFAULT NULL,
	ONELINE TEXT DEFAULT NULL,
	VOTES VARCHAR(50) DEFAULT NULL,
	RunTime INT DEFAULT NULL,
	Directors TEXT DEFAULT NULL,
	Stars TEXT DEFAULT NULL,
	movie_id INT NOT NULL,
	PRIMARY KEY (ID),
	CONSTRAINT fk_movie_info
      FOREIGN KEY(movie_id) 
	  REFERENCES movies_group(ID) 
);


INSERT INTO movies_info_delete_duplicates
SELECT ROW_NUMBER() OVER(ORDER BY movie_id) as ID, rating, oneline,votes,runtime, 
		REPLACE(directors_clear,'Directors:','') as directors, 
		REPLACE(stars,'Stars:','') as stars,
		movie_id
	FROM movies_info_dir_stars_clear_stage_1
	ORDER BY movie_id;

--DELETE DUPLICATE ROWS (4083 was a duplicate row after union so I delete it)
DELETE  FROM
    movies_info_delete_duplicates 
WHERE id=4084;

--DELETE UNUSED TABLE
DROP TABLE IF EXISTS movies_info CASCADE;

--NOW SPLIT THE TABLE IN 2 NEWS

CREATE TABLE movies_info (
	ID SERIAL,
	RATING FLOAT DEFAULT NULL,
	ONELINE TEXT DEFAULT NULL,
	VOTES VARCHAR(50) DEFAULT NULL,
	RunTime INT DEFAULT NULL,
	movie_id INT NOT NULL,
	PRIMARY KEY (ID),
	CONSTRAINT fk_movie_info
      FOREIGN KEY(movie_id) 
	  REFERENCES movies_group(ID) ON DELETE CASCADE
);

INSERT INTO movies_info
SELECT ROW_NUMBER() OVER(ORDER BY ID) as ID, rating, oneline,votes,runtime, movie_id
	FROM movies_info_delete_duplicates;

CREATE TABLE director_stars (
	ID SERIAL,
	Directors TEXT DEFAULT NULL,
	Stars TEXT DEFAULT NULL,
	stars_id INT NOT NULL,
	PRIMARY KEY (ID),
	CONSTRAINT fk_stars_info
      FOREIGN KEY(stars_id) 
	  REFERENCES movies_info(ID)
);

INSERT INTO director_stars
SELECT ROW_NUMBER() OVER(ORDER BY ID) as ID, directors, stars, ROW_NUMBER() OVER(ORDER BY ID) as stars_id
	FROM movies_info_delete_duplicates;

--REMOVE SPACE IN FRONT OF Stars
UPDATE director_stars
  SET Stars = TRIM(LEADING FROM Stars);

--DELETE UNUSED TABLE
DROP TABLE IF EXISTS movies_info_delete_duplicates CASCADE;

--CREATE TABLE DIRECTORS (SPLIT TABLE DIRECTOR_STARS)
CREATE TABLE directors (
	ID SERIAL,
	Directors TEXT DEFAULT NULL,
	director_info_id INT NOT NULL, 	--same as stars_id
	director_movie_id INT NOT NULL,	--same as movie_id
	PRIMARY KEY (ID),
	CONSTRAINT fk_director_info
      FOREIGN KEY(director_info_id) 
	  REFERENCES movies_info(ID) ON DELETE CASCADE,
	CONSTRAINT fk_director_movie
      FOREIGN KEY(director_movie_id) 
	  REFERENCES movies_group(ID) ON DELETE CASCADE
);

INSERT INTO directors
SELECT ROW_NUMBER() OVER(ORDER BY d.ID) as ID, d.directors, d.stars_id, m.movie_id
	FROM director_stars as d
	JOIN movies_info as m
	ON d.stars_id = m.ID
;


--CREATE TABLE STARS (SPLIT TABLE DIRECTOR_STARS)
CREATE TABLE stars (
	ID SERIAL,
	Stars TEXT DEFAULT NULL,
	stars_info_id INT NOT NULL, 	--same as stars_id
	stars_movie_id INT NOT NULL,	--same as movie_id
	PRIMARY KEY (ID),
	CONSTRAINT fk_stars_info
      FOREIGN KEY(stars_info_id) 
	  REFERENCES movies_info(ID) ON DELETE CASCADE,
	CONSTRAINT fk_stars_movie
      FOREIGN KEY(stars_movie_id) 
	  REFERENCES movies_group(ID) ON DELETE CASCADE
);

--SET NULL VALUES WITH STRING
UPDATE director_stars 
	SET Stars = 'NotStar'
	WHERE Stars IS NULL;

--CREATE HELPER VIEW
CREATE VIEW helper_stars AS(
	SELECT unnest(string_to_array(d.stars, ',')) as star_name, d.stars_id, m.movie_id
	FROM director_stars as d
	JOIN movies_info as m
	ON d.stars_id = m.ID
	ORDER BY m.ID
);

INSERT INTO stars
SELECT ROW_NUMBER() OVER(ORDER BY stars_id) as ID, star_name, stars_id, movie_id
	FROM helper_stars
;

--TRIM SPACE FROM BEGGINING
UPDATE stars
  SET Stars = TRIM(LEADING FROM Stars);

UPDATE stars
  SET Stars = NULL
  WHERE Stars = 'NotStar';

--DELETE UNUSED TABLES
DROP TABLE IF EXISTS director_stars CASCADE;

--RENAME TABLES
ALTER TABLE movies_group RENAME TO movies;
ALTER TABLE genre_table RENAME TO genre;

--CREATE TABLE DATES FOR EVERY MOVIE
CREATE TABLE dates (
	ID SERIAL,
	start_year INT,
	end_year INT,
	movie_id INT,
	Gross VARCHAR(50),
	PRIMARY KEY (ID),
	CONSTRAINT fk_dates_movie
      FOREIGN KEY(movie_id) 
	  REFERENCES movies(ID) ON DELETE CASCADE
);

INSERT INTO dates
SELECT ROW_NUMBER() OVER(ORDER BY ID) as ID, start_year, end_year, ID
	FROM movies
;

--CREATE TABLE COSTS FOR EVERY MOVIE
CREATE TABLE costs (
	ID SERIAL,
	Gross VARCHAR(50),
	movie_id INT,
	PRIMARY KEY (ID),
	CONSTRAINT fk_costs_movie
      FOREIGN KEY(movie_id) 
	  REFERENCES movies(ID) ON DELETE CASCADE
);

INSERT INTO costs
SELECT ROW_NUMBER() OVER(ORDER BY ID) as ID, gross, ID
	FROM movies
;

ALTER TABLE movies
  DROP COLUMN start_year,
  DROP COLUMN end_year,
  DROP COLUMN gross;

--CREATE TABLE FOR DESCRIPTION
CREATE TABLE description (
	ID SERIAL,
	ONELINE TEXT DEFAULT NULL,
	RunTime INT DEFAULT NULL,
	movie_id INT NOT NULL,
	PRIMARY KEY (ID),
	CONSTRAINT fk_movie_description
      FOREIGN KEY(movie_id) 
	  REFERENCES movies(ID) ON DELETE CASCADE
);

CREATE VIEW helper_description AS
	SELECT oneline, runtime, movie_id
	FROM movies_info
	GROUP BY oneline,runtime,movie_id
	ORDER BY movie_id
;

INSERT INTO description
	SELECT ROW_NUMBER() OVER(ORDER BY movie_id) as movie_id,oneline, runtime, movie_id
	FROM helper_description;

DROP VIEW helper_description;

--CREATE TABLE CRITICS
CREATE TABLE critics (
	ID SERIAL,
	RATING FLOAT DEFAULT NULL,
	VOTES VARCHAR(50) DEFAULT NULL,
	movie_id INT NOT NULL,
	description_id INT NOT NULL,
	PRIMARY KEY (ID),
	CONSTRAINT fk_description_critics
      FOREIGN KEY(description_id) 
	  REFERENCES description(ID) ON DELETE CASCADE
);


CREATE VIEW helper_critics AS
	SELECT rating, votes, movie_id
	FROM movies_info
	GROUP BY rating,votes,movie_id
	ORDER BY movie_id
;

INSERT INTO critics
	SELECT ROW_NUMBER() OVER(ORDER BY c.ID) as ID,h.rating, h.votes, h.movie_id, ROW_NUMBER() OVER(ORDER BY c.ID) as description_id
	FROM helper_critics as h
	JOIN  movies_info as c
	ON h.movie_id = c.ID;

DROP VIEW helper_critics;

ALTER TABLE stars
  DROP COLUMN stars_info_id;
 ALTER TABLE directors
  DROP COLUMN director_info_id;
 	
DROP TABLE IF EXISTS movies_info CASCADE;


