-- DONE: creating the table works.
CREATE OR REPLACE TABLE USER (
    Email VARCHAR(256) CHARACTER SET utf8 PRIMARY KEY CHECK (Email LIKE "%@%"),
    DateAdded DATETIME NOT NULL, -- not user modifiable.
    NickName VARCHAR(256) CHARACTER SET utf8 UNIQUE,
    Profile VARCHAR(256) CHARACTER SET utf8
);

CREATE OR REPLACE TRIGGER afterInsertRow_setDateAddedToNow
AFTER INSERT
ON `USER`
FOR EACH ROW -- See MariaDB specifics on row and statement orientation.
UPDATE `USER`
SET NEW.DateAdded = CURRENT_TIMESTAMP();

CREATE OR REPLACE TRIGGER afterUpdateRow_preventDateAddedModification
BEFORE UPDATE
ON `USER`
FOR EACH ROW
UPDATE `USER` SET NEW.DateAdded = OLD.DateAdded;

/* Warn database clients that deleting users is impossible manually; they must
use the provided function. */
CREATE OR REPLACE TRIGGER beforeDeleteRow_signalErrorUseProcedure
BEFORE DELETE
ON `USER`
FOR EACH ROW
-- Make use of the behaviour of trigger errors to prevent the row deletion.
-- https://mariadb.com/kb/en/trigger-overview/#trigger-errors
-- https://mariadb.com/kb/en/signal/
SIGNAL SQLSTATE '45000' SET
MESSAGE_TEXT = 'Users must not be deleted manually; use the DELETE_USER() procedure';




CREATE OR REPLACE TABLE BOOK (
  BookID INT AUTO_INCREMENT PRIMARY KEY,
  Title VARCHAR(256) CHARACTER SET utf8 NOT NULL,
  -- Year is additionally constrained by a trigger to be
  -- <= YEAR(CURDATE()).
  Year INT CHECK (Year >= -3500),
  NumRaters INT DEFAULT 0,
  Rating DECIMAL(2,1) DEFAULT 0.0 CHECK (Rating BETWEEN 0.0 AND 5.0)
);

CREATE OR REPLACE TRIGGER beforeUpdateRow_preventNumRatersUpdate
BEFORE UPDATE
ON BOOK
FOR EACH ROW
UPDATE BOOK SET NEW.NumRaters = OLD.NumRaters; -- This line was added to prevent the update

/*Warn database clients that Rating cannot be set. */
CREATE OR REPLACE TRIGGER beforeUpdateRow_preventRatingsUpdate
BEFORE UPDATE
ON BOOK
FOR EACH ROW
UPDATE BOOK SET NEW.Rating = OLD.Rating; -- This line was added to prevent the update

/* Warn database clients that deleting users is impossible manually; they must
use the provided function. */
CREATE OR REPLACE TRIGGER beforeDeleteRow_signalErrorImpossible
BEFORE DELETE
ON BOOK
FOR EACH ROW
-- Make use of the behaviour of trigger errors to prevent the row deletion.
-- https://mariadb.com/kb/en/trigger-overview/#trigger-errors
-- https://mariadb.com/kb/en/signal/
SIGNAL SQLSTATE '45000' SET
MESSAGE_TEXT = 'Deleting books is prohibited.';

CREATE OR REPLACE TRIGGER beforeInsertRow_constrainYearToPresent
BEFORE INSERT 
ON BOOK 
FOR EACH ROW
SET NEW.Year = IF(NEW.Year > YEAR(CURDATE()), YEAR(CURDATE()), NEW.Year);




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
