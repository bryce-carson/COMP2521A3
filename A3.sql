-- DONE: creating the table works.
CREATE OR REPLACE TABLE USER (
    Email VARCHAR(256) CHARACTER SET utf8 PRIMARY KEY CHECK (Email LIKE "%@%"),
    DateAdded DATETIME NOT NULL, -- not user modifiable.
    NickName VARCHAR(256) CHARACTER SET utf8 UNIQUE,
    Profile VARCHAR(256) CHARACTER SET utf8
);

-- FIXME: You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near 'END' at line 1
CREATE OR REPLACE TRIGGER afterCreateRow_setDateAddedToNow
BEGIN
UPDATE USER
SET DateAdded = CURDATE();
END;

-- Untested
CREATE OR REPLACE TRIGGER afterUpdateRow_preventDateAddedModification
BEGIN
UPDATE USER
SET new.DateAdded = old.DateAdded
END;
/* Warn database clients that deleting users is impossible manually; they must
use the provided function. */
CREATE TABLE BOOK (
  BookID INT PRIMARY KEY AUTO_INCREMENT,
  Title VARCHAR(256) CHARACTER SET utf8 NOT NULL,
  -- Year is additionally constrained by a trigger to be
  -- <= YEAR(CURDATE()).
  Year INT CHECK (Year >= -3500),
  NumRaters INT DEFAULT 0,
  Rating DECIMAL(2,1) DEFAULT 0.0
      CHECK (Rating BETWEEN 0.0 AND 5.0)
);

-- See https://www.mssqltips.com/sqlservertip/2711/different
-- -ways-to-make-a-table-read-only-in-a-sql-server-database/
-- for source of inspiration.
CREATE TRIGGER beforeDeleteRow_warnClientImpossibleChange
    BEFORE DELETE ON BOOK INSTEAD OF DELETE AS
    BEGIN
        -- NOP: TODO: implement the trigger; use rollback?
    END;
CREATE OR REPLACE TRIGGER beforeInsertRow_constrainYearToPresent
BEFORE INSERT ROW
BEGIN
IF new.Year > YEAR(CURDATE())
SET new.Year = YEAR(CURDATE())
END;
CREATE TABLE AUTHOR (
    AuthorID INT PRIMARY KEY AUTO_INCREMENT,
    FirstName VARCHAR(256) CHARACTER SET utf8 NOT NULL,
    MiddleName VARCHAR(256) CHARACTER SET utf8,
    Lastname VARCHAR(256) CHARACTER SET utf8
);
CREATE TABLE BOOKAUTHOR (
    AuthorID INT,
    BookID INT
);
ALTER TABLE BOOKAUTHOR DROP PRIMARY KEY;

-- Composite primary key composed of foreign keys:
ALTER TABLE BOOKAUTHOR ADD CONSTRAINT
    PRIMARY KEY (AuthorID, BookID);

ALTER TABLE BOOKAUTHOR ADD CONSTRAINT
FOREIGN KEY (AuthorID) REFERENCES AUTHOR (AuthorID)
ON DELETE CASCADE;

-- Books cannot be deleted, so do not permit cascading.
ALTER TABLE BOOKAUTHOR ADD CONSTRAINT
FOREIGN KEY (BookID) REFERENCES BOOK (BookID);
CREATE TABLE READBOOK (
    BookID INT NOT NULL FOREIGN KEY REFERENCES BOOK(BookID),
    Email VARCHAR(256) CHARACTER SET utf8 NOT NULL
        FOREIGN KEY REFERENCES USER(Email)
        ON DELETE CASCADE,
    -- Constaint DateRead to be less than YEAR(CURDATE()).
    DateRead DATE NOT NULL,
    Rating INT(2) NOT NULL CHECK (Rating >= 1 AND Rating <= 10))
    ENGINE=INNODB;

-- Include the following code
CREATE TRIGGER afterUpdateRow_recalculateBookRating
    AFTER UPDATE ON READBOOK FOR EACH ROW CalculateRating();

CREATE TRIGGER afterInsertRow_recalculateBookRating
AFTER INSERT ON READBOOK FOR EACH ROW CalculateRating();

CREATE TRIGGER afterDeleteRow_recalculateBookRating
    AFTER DELETE ON READBOOK FOR EACH ROW CalculateRating();

-- Include the following procedure after this code.
CREATE OR REPLACE PROCEDURE CalculateRating
    AS BEGIN
    UPDATE BOOK
    SET Rating = (SELECT AVG(Rating)
                  FROM READBOOK
                  WHERE BOOK.BookID = READBOOK.BookID),
    SET NumRaters = (SELECT COUNT(*)
                     FROM READBOOK
                     WHERE BOOK.BookID = READBOOK.BookID)
    WHERE BOOK.BookID = READBOOK.BookID;
    END;

ALTER TABLE READBOOK ADD CONSTRAINT
PRIMARY KEY (BookID, Email);
