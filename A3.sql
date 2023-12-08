/* USER TABLE AND RELATED STATEMENTS */
CREATE OR REPLACE TABLE USER (
    Email VARCHAR(256) CHARACTER SET utf8 PRIMARY KEY CHECK (Email LIKE "%@%"),
    DateAdded DATETIME NOT NULL, -- not user modifiable.
    NickName VARCHAR(256) CHARACTER SET utf8 UNIQUE,
    Profile VARCHAR(256) CHARACTER SET utf8
);
-- setDateAddedToNow
CREATE OR REPLACE TRIGGER afterInsertRow_setDateAddedToNow
AFTER INSERT
ON `USER`
FOR EACH ROW -- See MariaDB specifics on row and statement orientation.
UPDATE `USER`
SET NEW.DateAdded = CURRENT_TIMESTAMP();
-- preventDateAddedModification
CREATE OR REPLACE TRIGGER afterUpdateRow_preventDateAddedModification
BEFORE UPDATE
ON `USER`
FOR EACH ROW
UPDATE `USER` SET NEW.DateAdded = OLD.DateAdded;
-- signalErrorUseProcedure
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


/* BOOK TABLE AND RELATED STATEMENTS */
CREATE OR REPLACE TABLE BOOK (
  BookID INT PRIMARY KEY AUTO_INCREMENT,
  Title VARCHAR(256) CHARACTER SET utf8 NOT NULL,
  -- Year is additionally constrained by a trigger to be
  -- <= YEAR(CURDATE()).
  Year INT CHECK (Year >= -3500),
  NumRaters INT DEFAULT 0,
  Rating DECIMAL(2,1) DEFAULT 0.0
);
-- signalErrorUseProcedure
CREATE OR REPLACE TRIGGER beforeDeleteRow_signalErrorImpossible
BEFORE DELETE
ON BOOK
FOR EACH ROW
-- Make use of the behaviour of trigger errors to prevent the row deletion.
-- https://mariadb.com/kb/en/trigger-overview/#trigger-errors
-- https://mariadb.com/kb/en/signal/
SIGNAL SQLSTATE '45000' SET
MESSAGE_TEXT = 'Deleting books is prohibited.';
-- constrainYearToPresent
CREATE OR REPLACE TRIGGER beforeInsertRow_constrainYearToPresent
BEFORE INSERT 
ON BOOK 
FOR EACH ROW
SET NEW.Year = IF(NEW.Year > YEAR(CURDATE()), YEAR(CURDATE()), NEW.Year);


/* AUTHOR TABLE AND RELATED STATEMENTS */
CREATE OR REPLACE TABLE AUTHOR (
    AuthorID INT PRIMARY KEY AUTO_INCREMENT,
    FirstName VARCHAR(256) CHARACTER SET utf8 NOT NULL,
    MiddleName VARCHAR(256) CHARACTER SET utf8,
    Lastname VARCHAR(256) CHARACTER SET utf8
);


/* BOOKAUTHOR TABLE AND RELATED STATEMENTS */
CREATE OR REPLACE TABLE BOOKAUTHOR (
    AuthorID INT,
    BookID INT,
    FOREIGN KEY (AuthorID) REFERENCES AUTHOR(AuthorID),
    FOREIGN KEY (BookID) REFERENCES BOOK(BookID),
    PRIMARY KEY (AuthorID, BookID)
);
-- Composite primary key composed of foreign keys:
ALTER TABLE BOOKAUTHOR ADD CONSTRAINT
    PRIMARY KEY (AuthorID, BookID);
-- Foreign key AuthorID
ALTER TABLE BOOKAUTHOR ADD CONSTRAINT
FOREIGN KEY (AuthorID) REFERENCES AUTHOR (AuthorID)
ON
DELETE
	CASCADE;
-- Foreign key BookID; books cannot be deleted, so do not permit cascading.
ALTER TABLE BOOKAUTHOR ADD CONSTRAINT
FOREIGN KEY (BookID) REFERENCES BOOK (BookID);

/* READBOOK TABLE AND RELATED STATEMENTS */
CREATE OR REPLACE TABLE READBOOK (
BookID INT,
Email VARCHAR(256) CHARACTER SET utf8,
DateRead DATE NOT NULL,
Rating INT NOT NULL CHECK (Rating BETWEEN 1 AND 10),
FOREIGN KEY (BookID) REFERENCES BOOK(BookID),
FOREIGN KEY (Email) REFERENCES `USER`(Email) ON DELETE CASCADE);
-- Add composite primary key
ALTER TABLE READBOOK ADD CONSTRAINT PRIMARY KEY (BookID, Email);
-- recalculateBookRatingOnUpdate
CREATE OR REPLACE TRIGGER afterUpdateRow_recalculateBookRating
    AFTER UPDATE ON READBOOK FOR EACH ROW CalculateRating();
-- recalculateBookRatingOnInsert
CREATE OR REPLACE TRIGGER afterInsertRow_recalculateBookRating
AFTER INSERT ON READBOOK FOR EACH ROW CalculateRating();
-- recalculateBookRatingOnDelete
CREATE OR REPLACE TRIGGER afterDeleteRow_recalculateBookRating
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
   
   

/* USER Test Data */
INSERT INTO USER(Email,DateAdded, NickName) VALUES ("E@GMAIL.COM","2023-12-06" ,"t");
INSERT INTO USER (Email, NickName, Profile) VALUES ("bcars268@mtroyal.ca", NULL, NULL);
INSERT INTO USER (EMAIL,DateAdded,NICKNAME, PROFILE) VALUES ("TO@gmail.com","2023-12-06" ,"gre", NULL);
SELECT * FROM USER;

/* BOOK Test Data */
INSERT INTO BOOK(Title, Year) VALUES  ("What a Wonderful Day", "2003");
INSERT INTO BOOK(Title, Year) VALUES  ("Diary of a WimpyKid", "2010");
INSERT INTO BOOK(Title, Year) VALUES  ("A Novel", "1002");
INSERT INTO BOOK (Title, Year) VALUES  ("Harry's Quest", "2007");
INSERT INTO BOOK (Title, Year) VALUES  ("Don't Give Up", "2014");
INSERT INTO BOOK (Title, Year) VALUES  ("The Great Adventure", "1998");
INSERT INTO BOOK (Title, Year) VALUES  ("Mysteries Unveiled", "2022");
INSERT INTO BOOK (Title, Year) VALUES  ("Journey to the Unknown", "1985");
SELECT * FROM BOOK;

/* AUTHOR Test Data */
INSERT INTO AUTHOR (FirstName, LastName) VALUES  ("Thomas", "Heffley");
INSERT INTO AUTHOR(FirstName, LastName) VALUES  ("Thomas", NULL);
INSERT INTO AUTHOR(FirstName, LastName, MiddleName) VALUES  ("Flint", NULL, "Red");
INSERT INTO AUTHOR (FirstName, LastName) VALUES  ("John", "Doe");
INSERT INTO AUTHOR (FirstName, LastName, MiddleName) VALUES  ("Jane", "Smith", "A");
INSERT INTO AUTHOR (FirstName, LastName) VALUES  ("Robert", "O'Connor");
INSERT INTO AUTHOR (FirstName, LastName) VALUES  ("Eliza", "Müller");
INSERT INTO AUTHOR (FirstName, LastName, MiddleName) VALUES  ("Sara", "Williams", NULL);
SELECT * FROM AUTHOR;

/* BOOKAUTHOR Test Data */
INSERT INTO BOOKAUTHOR (AuthorID, BookID) VALUES  ("1", "3");
INSERT INTO BOOKAUTHOR (AuthorID, BookID) VALUES  ("2", "5");
INSERT INTO BOOKAUTHOR (AuthorID, BookID) VALUES  ("3", "1");
INSERT INTO BOOKAUTHOR (AuthorID, BookID) VALUES  ("4", "8");
INSERT INTO BOOKAUTHOR (AuthorID, BookID) VALUES  ("5", "2");
INSERT INTO BOOKAUTHOR (AuthorID, BookID) VALUES  ("6", "4");
INSERT INTO BOOKAUTHOR (AuthorID, BookID) VALUES  ("7", "7");
INSERT INTO BOOKAUTHOR (AuthorID, BookID) VALUES  ("8", "6");
-- Big wild select statement
SELECT
	BA.AuthorID,
	A.FirstName,
	A.LastName,
	A.MiddleName,
	BA.BookID,
	B.Title
FROM
	BOOKAUTHOR BA,
	AUTHOR A,
	BOOK B
WHERE
	BA.AuthorID = A.AuthorID
	AND BA.BookID = B.BookID;

/* READBOOK Test Data */
INSERT INTO READBOOK (BookID, Email, Rating, DateRead) VALUES (1, 'E@GMAIL.COM', 8, '2023-12-01');
INSERT INTO READBOOK (BookID, Email, Rating, DateRead) VALUES (2, 'E@GMAIL.COM', 6, '2023-12-05');
INSERT INTO READBOOK (BookID, Email, Rating, DateRead) VALUES (3, 'bcars268@mtroyal.ca', 9, '2023-11-20');
INSERT INTO READBOOK (BookID, Email, Rating, DateRead) VALUES (4, 'bcars268@mtroyal.ca', 7, '2023-11-25');
INSERT INTO READBOOK (BookID, Email, Rating, DateRead) VALUES (5, 'TO@gmail.com', 5, '2023-12-10');
INSERT INTO READBOOK (BookID, Email, Rating, DateRead) VALUES (6, 'TO@gmail.com', 8, '2023-12-15');
INSERT INTO READBOOK (BookID, Email, Rating, DateRead) VALUES (7, 'john.doe@example.com', 10, '2023-12-20');
INSERT INTO READBOOK (BookID, Email, Rating, DateRead) VALUES (8, 'john.doe@example.com', 4, '2023-12-25');
Select * from READBOOK;
