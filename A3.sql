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
IF PERMIT_DEL_NOT_OVERRIDDEN THEN
SIGNAL SQLSTATE '45000' SET
MESSAGE_TEXT = 'Users must not be deleted manually; use the DELETE_USER() procedure';
END IF;

SET @PROHIBIT_DEL_OVERRIDDEN = 0;

CREATE
OR REPLACE
PROCEDURE DELETE_USER (IN param_email VARCHAR(256) CHARACTER SET utf8)
MODIFIES SQL DATA
COMMENT 'Delete a user from the database.'
BEGIN
DELETE FROM READBOOK WHERE READBOOK.Email = param_email;
-- Ignore the usual trigger somehow.
SET @PROHIBIT_DEL_NOT_OVERRIDDEN = 0;
DELETE FROM USER WHERE USER.Email = param_email;
SET @PROHIBIT_DEL_NOT_OVERRIDDEN = 1;
END;

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

/* Warn database clients that deleting users is impossible manually; they must
use the provided function. */
CREATE OR REPLACE TRIGGER beforeDeleteRow_signalErrorImpossible
BEFORE DELETE
ON `BOOK`
FOR EACH ROW
-- Make use of the behaviour of trigger errors to prevent the row deletion.
-- https://mariadb.com/kb/en/trigger-overview/#trigger-errors
-- https://mariadb.com/kb/en/signal/
SIGNAL SQLSTATE '45000' SET
MESSAGE_TEXT = 'Deleting books is prohibited.';
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

ALTER TABLE READBOOK ADD CONSTRAINT
PRIMARY KEY (BookID, Email);

/* This view can be used to identify invalid users (users
without an @ in their email) */
CREATE VIEW InvalidUsers AS
SELECT Email, NickName
FROM
    USER
WHERE
    Email NOT LIKE '%@%';


/* This view provides details about books, including
multiple authors if applicable */
CREATE VIEW BookDetails AS
SELECT B.BookID, B.Title, B.Year, B.NumRaters, B.Rating,
       GROUP_CONCAT(A.FirstName, ' ',
                    A.MiddleName, ' ',
                    A.Lastname) AS Authors
FROM
    BOOK B
LEFT JOIN
    BOOKAUTHOR BA ON B.BookID = BA.BookID
LEFT JOIN
    AUTHOR A ON BA.AuthorID = A.AuthorID
GROUP BY
    B.BookID, B.Title, B.Year, B.NumRaters, B.Rating;


-- View to display books with their average ratings
CREATE VIEW BooksAvgRatings AS
SELECT B.BookID, B.Title, AVG(RB.Rating) AS AverageRating
FROM
    BOOK B
LEFT JOIN
    READBOOK RB ON B.BookID = RB.BookID
GROUP BY
    B.BookID, B.Title;


/* This view provides statistics about users who have read
and rated books */
CREATE VIEW UserBookDetails AS
SELECT U.Email, U.NickName,
       COUNT(RB.BookID) AS TotalBooksRead,
       AVG(RB.Rating) AS AverageRating
FROM
    USER U
LEFT JOIN
    READBOOK RB ON U.Email = RB.Email
GROUP BY
    U.Email, U.NickName;
