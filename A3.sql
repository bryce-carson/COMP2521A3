CREATE TABLE USER (
    Email VARCHAR(21,844) CHARACTER SET utf8 PRIMARY KEY
        CHECK Email LIKE "%@%",
    DateAdded DATETIME NOT NULL, -- not user modifiable.
    NickName VARCHAR(21,844) CHARACTER SET utf8 UNIQUE,
    Profile VARCHAR(21,844) CHARACTER SET utf8
);

/* Warn database clients that deleting users is impossible manually; they must
use the provided function. */

CREATE TABLE BOOK (
  BookID INT PRIMARY KEY AUTO_INCREMENT,
  Title VARCHAR(255) NOT NULL,
  Year INT CHECK (Year >= -3500 AND
                  Year <= YEAR(CURDATE())),
  NumRaters INT DEFAULT 0,
  Rating DECIMAL(2,1) DEFAULT 0.0
      CHECK (Rating >= 0.0 AND Rating <= 5.0)
);

-- See https://www.mssqltips.com/sqlservertip/2711/different
-- -ways-to-make-a-table-read-only-in-a-sql-server-database/
-- for source of inspiration.
CREATE TRIGGER beforeDeleteRow_warnClientImpossibleChange
    BEFORE DELETE ON BOOK INSTEAD OF DELETE AS
    BEGIN
        RAISEERROR('BOOKS cannot be deleted, only updated.')
        ROLLBACK;
    END;
CREATE TABLE AUTHOR (
    AuthorID INT PRIMARY KEY AUTO_INCREMENT,
    Lastname VARCHAR(256) CHARACTER SET utf8,
    FirstName VARChar(256) CHARACTER SET utf8 NOT NULL,
    MiddleName VARCHAR(256) CHARACTER SET utf8
);
CREATE TABLE BOOKAUTHOR (
    AuthorID INT FOREIGN KEY REFERENCES AUTHOR(AuthorID),
    BookID INT FOREIGN KEY REFERENCES BOOK(BookID)
);
CREATE TABLE READBOOK (
    BookID INT FOREIGN KEY REFERENCES BOOK(BookID) NOT NULL,
    Email VARCHAR(...) FOREIGN KEY REFERENCES USER(Email)
    NOT NULL
    ON DELETE CASCADE,
    DateRead DATE NOT NULL,
    Rating INT(2) CHECK Rating >= 1 AND Rating <= 10 NOT NULL,
    PRIMARY KEY (BookID, Email)
    ) ENGINE=INNODB;

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
                  WHERE BOOK.BookID = ReadBook.BookID),
    SET NumRaters = (SELECT COUNT(*)
                     FROM READBOOK
                     WHERE BOOK.BookID = ReadBook.BookID)
    WHERE BOOK.BookID = ReadBook.BookID;
    END;

