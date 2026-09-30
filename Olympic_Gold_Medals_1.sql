/* =========================================================================
   File:    player_only_gold.sql
   Author:  ROHIT RAJ
   Engine:  SQL Server (T-SQL)
   -------------------------------------------------------------------------
   Problem:
     Find each player and the number of gold medals they won,
     but ONLY for players who won gold medals and nothing else
     (i.e., their name never appears in SILVER or BRONZE).
   ========================================================================= */


/* -------------------------------------------------------------------------
   Schema + sample data
   ------------------------------------------------------------------------- */

CREATE TABLE events (
    ID     INT,
    event  VARCHAR(255),
    YEAR   INT,
    GOLD   VARCHAR(255),
    SILVER VARCHAR(255),
    BRONZE VARCHAR(255)
);

INSERT INTO events VALUES (1,  '100m', 2016, 'Amthhew Mcgarray', 'donald',       'barbara');
INSERT INTO events VALUES (2,  '200m', 2016, 'Nichole',          'Alvaro Eaton', 'janet Smith');
INSERT INTO events VALUES (3,  '500m', 2016, 'Charles',          'Nichole',      'Susana');
INSERT INTO events VALUES (4,  '100m', 2016, 'Ronald',           'maria',        'paula');
INSERT INTO events VALUES (5,  '200m', 2016, 'Alfred',           'carol',        'Steven');
INSERT INTO events VALUES (6,  '500m', 2016, 'Nichole',          'Alfred',       'Brandon');
INSERT INTO events VALUES (7,  '100m', 2016, 'Charles',          'Dennis',       'Susana');
INSERT INTO events VALUES (8,  '200m', 2016, 'Thomas',           'Dawn',         'catherine');
INSERT INTO events VALUES (9,  '500m', 2016, 'Thomas',           'Dennis',       'paula');
INSERT INTO events VALUES (10, '100m', 2016, 'Charles',          'Dennis',       'Susana');
INSERT INTO events VALUES (11, '200m', 2016, 'jessica',          'Donald',       'Stefeney');
INSERT INTO events VALUES (12, '500m', 2016, 'Thomas',           'Steven',       'Catherine');


/* =========================================================================
   My thought process
   -------------------------------------------------------------------------
   1. Setup first, question later.
      Before reading the question, I created the table locally and
      studied the schema. Reading data before the question prevents me
      from biasing my interpretation of the columns.

   2. Grain of the table.
      One row = one occurrence of an event in a given year, with its
      three medalists (GOLD, SILVER, BRONZE).
      Note: the same (event, year) can repeat (e.g., '100m' in 2016
      appears in rows 1, 4, 7, 10) — so grain is NOT (event, year).
      ID looks like a plain surrogate key with no business meaning.

   3. Decomposition (divide and conquer).
      Sub-part A: count gold medals per player (superset of final answer).
      Sub-part B: from that set, remove any player whose name shows up
                  in SILVER or BRONZE anywhere in the table.

   4. Why NOT IN instead of EXCEPT ALL?
      Set theory says: {gold winners} MINUS {silver winners ∪ bronze winners}.
      Natural fit = EXCEPT ALL (preserves duplicates so a player who
      won 3 golds still counts as 3). But SQL Server does not support
      EXCEPT ALL — only EXCEPT (which deduplicates and would collapse
      my 3 golds to 1). So I used a row-level anti-filter with NOT IN,
      which preserves duplicates naturally because it filters rows,
      not values.

   5. Caveats I'm aware of (worth revisiting):
      - NOT IN + NULL trap: if SILVER or BRONZE contained a NULL, the
        NOT IN predicate would return zero rows. Current data has no
        NULLs, but NOT EXISTS would be the safer production choice.
      - Collation sensitivity: SQL Server's default collation is
        case-insensitive (CI), so 'Donald' == 'donald'. If it were
        case-sensitive, results would differ. Verify with:
            SELECT SERVERPROPERTY('Collation');

   6. Optimization vs. my first draft:
      My original query used a CTE to apply the SILVER filter, then
      applied the BRONZE filter in the outer query. The two filters
      are independent, so the CTE was cosmetic — I've merged them
      into one WHERE clause with AND. Same result, less machinery.
   ========================================================================= */


/* -------------------------------------------------------------------------
   Final solution — NOT IN anti-filter (with NULL guards)
   ------------------------------------------------------------------------- */

SELECT
    GOLD                AS Player,
    COUNT(*)            AS NoOfGoldMedals
FROM events
WHERE GOLD NOT IN (SELECT SILVER FROM events WHERE SILVER IS NOT NULL)
  AND GOLD NOT IN (SELECT BRONZE FROM events WHERE BRONZE IS NOT NULL)
GROUP BY GOLD
ORDER BY NoOfGoldMedals DESC;   -- nice-to-have: shows top winners first


/* -------------------------------------------------------------------------
   Alternative (safer, production-preferred) — NOT EXISTS variant.
   NOT EXISTS immunizes against the NULL trap and is often better
   optimized by SQL Server's query planner.
   ------------------------------------------------------------------------- */

-- SELECT
--     e.GOLD              AS Player,
--     COUNT(*)            AS NoOfGoldMedals
-- FROM events e
-- WHERE NOT EXISTS (SELECT 1 FROM events s WHERE s.SILVER = e.GOLD)
--   AND NOT EXISTS (SELECT 1 FROM events b WHERE b.BRONZE = e.GOLD)
-- GROUP BY e.GOLD
-- ORDER BY NoOfGoldMedals DESC;