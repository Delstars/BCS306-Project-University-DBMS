-- BCS 306 Project 1: University Registration System
-- MySQL 8.0. Run in MySQL Workbench as an administrator.
-- Uses CREATE, INSERT, SELECT, JOIN, GROUP BY, subqueries, views and transactions.
-- Triggers and procedures are included because Project 1 specifically requires them.
-- Running this file replaces the bcs306_university database.

DROP DATABASE IF EXISTS bcs306_university;
CREATE DATABASE bcs306_university;
USE bcs306_university;

-- 1. TABLES
CREATE TABLE Department (
    DeptCode VARCHAR(10) PRIMARY KEY,
    DeptName VARCHAR(100) NOT NULL,
    Office VARCHAR(30),
    ChairID INT NOT NULL UNIQUE
);

CREATE TABLE Instructor (
    InstructorID INT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    MiddleName VARCHAR(50),
    FamilyName VARCHAR(50) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    Specialization VARCHAR(100),
    OfficeExtension VARCHAR(10),
    DeptCode VARCHAR(10) NOT NULL,
    UNIQUE (InstructorID, DeptCode),
    FOREIGN KEY (DeptCode) REFERENCES Department(DeptCode)
);

CREATE TABLE Student (
    StudentID INT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    MiddleName VARCHAR(50),
    FamilyName VARCHAR(50) NOT NULL,
    DateOfBirth DATE NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    AdmissionYear INT NOT NULL,
    AcademicStatus VARCHAR(20) NOT NULL,
    Street VARCHAR(100),
    City VARCHAR(50),
    Emirate VARCHAR(50),
    PostalCode VARCHAR(20),
    DeptCode VARCHAR(10) NOT NULL,
    AdvisorID INT,
    FOREIGN KEY (DeptCode) REFERENCES Department(DeptCode),
    FOREIGN KEY (AdvisorID) REFERENCES Instructor(InstructorID)
);

CREATE TABLE StudentPhone (
    StudentID INT,
    PhoneNumber VARCHAR(20),
    PRIMARY KEY (StudentID, PhoneNumber),
    FOREIGN KEY (StudentID) REFERENCES Student(StudentID) ON DELETE CASCADE
);

CREATE TABLE Course (
    CourseCode VARCHAR(10) PRIMARY KEY,
    CourseTitle VARCHAR(150) NOT NULL,
    CreditHours INT NOT NULL,
    AcademicLevel INT NOT NULL,
    CourseStatus VARCHAR(20) NOT NULL,
    DeptCode VARCHAR(10) NOT NULL,
    FOREIGN KEY (DeptCode) REFERENCES Department(DeptCode)
);

CREATE TABLE CoursePrerequisite (
    CourseCode VARCHAR(10),
    PrerequisiteCourseCode VARCHAR(10),
    PRIMARY KEY (CourseCode, PrerequisiteCourseCode),
    FOREIGN KEY (CourseCode) REFERENCES Course(CourseCode),
    FOREIGN KEY (PrerequisiteCourseCode) REFERENCES Course(CourseCode),
    CHECK (CourseCode <> PrerequisiteCourseCode)
);

CREATE TABLE Section (
    CourseCode VARCHAR(10),
    SectionNo VARCHAR(5),
    Semester VARCHAR(10),
    AcademicYear INT,
    MaximumCapacity INT NOT NULL,
    Classroom VARCHAR(30),
    DeliveryMode VARCHAR(20),
    InstructorID INT NOT NULL,
    PRIMARY KEY (CourseCode, SectionNo, Semester, AcademicYear),
    FOREIGN KEY (CourseCode) REFERENCES Course(CourseCode),
    FOREIGN KEY (InstructorID) REFERENCES Instructor(InstructorID),
    CHECK (MaximumCapacity > 0)
);

CREATE TABLE SectionMeeting (
    CourseCode VARCHAR(10),
    SectionNo VARCHAR(5),
    Semester VARCHAR(10),
    AcademicYear INT,
    MeetingNo INT,
    DayOfWeek VARCHAR(12),
    StartTime TIME,
    EndTime TIME,
    Room VARCHAR(30),
    PRIMARY KEY (CourseCode, SectionNo, Semester, AcademicYear, MeetingNo),
    FOREIGN KEY (CourseCode, SectionNo, Semester, AcademicYear)
        REFERENCES Section(CourseCode, SectionNo, Semester, AcademicYear)
        ON DELETE CASCADE,
    CHECK (StartTime < EndTime)
);

CREATE TABLE Registration (
    RegistrationID INT AUTO_INCREMENT PRIMARY KEY,
    StudentID INT NOT NULL,
    CourseCode VARCHAR(10) NOT NULL,
    SectionNo VARCHAR(5) NOT NULL,
    Semester VARCHAR(10) NOT NULL,
    AcademicYear INT NOT NULL,
    RegistrationDate DATE NOT NULL,
    RegistrationStatus VARCHAR(12) NOT NULL DEFAULT 'Registered',
    FinalMark DECIMAL(5,2),
    UNIQUE (StudentID, CourseCode, SectionNo, Semester, AcademicYear),
    FOREIGN KEY (StudentID) REFERENCES Student(StudentID),
    FOREIGN KEY (CourseCode, SectionNo, Semester, AcademicYear)
        REFERENCES Section(CourseCode, SectionNo, Semester, AcademicYear),
    CHECK (RegistrationStatus IN ('Registered','Dropped','Completed')),
    CHECK (FinalMark IS NULL OR FinalMark BETWEEN 0 AND 100),
    CHECK (RegistrationStatus <> 'Completed' OR FinalMark IS NOT NULL)
);

-- Keep audit rows even after a registration is deleted.
CREATE TABLE RegistrationAudit (
    AuditID INT AUTO_INCREMENT PRIMARY KEY,
    RegistrationID INT NOT NULL,
    EventType VARCHAR(40) NOT NULL,
    OldStatus VARCHAR(12),
    NewStatus VARCHAR(12),
    OldFinalMark DECIMAL(5,2),
    NewFinalMark DECIMAL(5,2),
    ChangedBy VARCHAR(100) NOT NULL,
    ChangedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. REGISTRATION RULES AND AUDIT
DELIMITER $$

-- Prevent lowering capacity below the number of active registrations.
CREATE TRIGGER CheckSectionCapacityUpdate
BEFORE UPDATE ON Section
FOR EACH ROW
BEGIN
    DECLARE enrolled INT;
    IF NEW.MaximumCapacity < OLD.MaximumCapacity THEN
        SELECT COUNT(*) INTO enrolled FROM Registration
        WHERE CourseCode = OLD.CourseCode AND SectionNo = OLD.SectionNo
          AND Semester = OLD.Semester AND AcademicYear = OLD.AcademicYear
          AND RegistrationStatus = 'Registered';
        IF NEW.MaximumCapacity < enrolled THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Capacity below active enrollment';
        END IF;
    END IF;
END$$

CREATE TRIGGER CheckRegistrationInsert
BEFORE INSERT ON Registration
FOR EACH ROW
BEGIN
    DECLARE seats INT;
    DECLARE enrolled INT;
    IF NEW.RegistrationStatus = 'Registered' THEN
        SELECT MaximumCapacity INTO seats FROM Section
        WHERE CourseCode = NEW.CourseCode AND SectionNo = NEW.SectionNo
          AND Semester = NEW.Semester AND AcademicYear = NEW.AcademicYear
        FOR UPDATE;
        SELECT COUNT(*) INTO enrolled FROM Registration
        WHERE CourseCode = NEW.CourseCode AND SectionNo = NEW.SectionNo
          AND Semester = NEW.Semester AND AcademicYear = NEW.AcademicYear
          AND RegistrationStatus = 'Registered';
        IF enrolled >= seats THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section is full';
        END IF;
    END IF;
END$$

CREATE TRIGGER CheckRegistrationUpdate
BEFORE UPDATE ON Registration
FOR EACH ROW
BEGIN
    DECLARE seats INT;
    DECLARE enrolled INT;
    IF NEW.RegistrationStatus = 'Registered' AND
       (OLD.RegistrationStatus <> 'Registered'
        OR OLD.CourseCode <> NEW.CourseCode
        OR OLD.SectionNo <> NEW.SectionNo
        OR OLD.Semester <> NEW.Semester
        OR OLD.AcademicYear <> NEW.AcademicYear) THEN
        SELECT MaximumCapacity INTO seats FROM Section
        WHERE CourseCode = NEW.CourseCode AND SectionNo = NEW.SectionNo
          AND Semester = NEW.Semester AND AcademicYear = NEW.AcademicYear
        FOR UPDATE;
        SELECT COUNT(*) INTO enrolled FROM Registration
        WHERE CourseCode = NEW.CourseCode AND SectionNo = NEW.SectionNo
          AND Semester = NEW.Semester AND AcademicYear = NEW.AcademicYear
          AND RegistrationStatus = 'Registered';
        IF enrolled >= seats THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section is full';
        END IF;
    END IF;
END$$

CREATE TRIGGER AuditRegistrationInsert
AFTER INSERT ON Registration
FOR EACH ROW
BEGIN
    INSERT INTO RegistrationAudit
        (RegistrationID, EventType, NewStatus, NewFinalMark, ChangedBy)
    VALUES (NEW.RegistrationID, 'REGISTRATION_CREATED',
            NEW.RegistrationStatus, NEW.FinalMark, USER());
END$$

CREATE TRIGGER AuditRegistrationUpdate
AFTER UPDATE ON Registration
FOR EACH ROW
BEGIN
    IF NOT (OLD.RegistrationStatus <=> NEW.RegistrationStatus) THEN
        INSERT INTO RegistrationAudit
            (RegistrationID, EventType, OldStatus, NewStatus, ChangedBy)
        VALUES (NEW.RegistrationID, 'REGISTRATION_STATUS_CHANGED',
                OLD.RegistrationStatus, NEW.RegistrationStatus, USER());
    END IF;
    IF NOT (OLD.FinalMark <=> NEW.FinalMark) THEN
        INSERT INTO RegistrationAudit
            (RegistrationID, EventType, OldFinalMark, NewFinalMark, ChangedBy)
        VALUES (NEW.RegistrationID, 'FINAL_MARK_CHANGED',
                OLD.FinalMark, NEW.FinalMark, USER());
    END IF;
END$$

CREATE TRIGGER AuditRegistrationDelete
BEFORE DELETE ON Registration
FOR EACH ROW
BEGIN
    INSERT INTO RegistrationAudit
        (RegistrationID, EventType, OldStatus, OldFinalMark, ChangedBy)
    VALUES (OLD.RegistrationID, 'REGISTRATION_DELETED',
            OLD.RegistrationStatus, OLD.FinalMark, USER());
END$$

DELIMITER ;

-- 3. PROVIDED DATA
INSERT INTO Department VALUES
('CS','Computer Science','B-201',201),
('IT','Information Technology','B-203',202),
('CYB','Cybersecurity','C-105',203),
('AI','Artificial Intelligence','C-107',204);

INSERT INTO Instructor (InstructorID,FirstName,MiddleName,FamilyName,Email,Specialization,DeptCode) VALUES
(201,'Sami','H.','Hassan','sami.hassan@uni.edu','Databases','CS'),
(202,'Amal','N.','Noor','amal.noor@uni.edu','Networking','IT'),
(203,'Noor','S.','Salem','noor.salem@uni.edu','Cybersecurity','CYB'),
(204,'Hani','O.','Omar','hani.omar@uni.edu','AI','AI'),
(205,'Maha','A.','Ali','maha.ali@uni.edu','Software Engineering','CS');

-- A chair must work in the department they chair.
ALTER TABLE Department
ADD FOREIGN KEY (ChairID, DeptCode) REFERENCES Instructor(InstructorID, DeptCode);

INSERT INTO Student
(StudentID,FirstName,MiddleName,FamilyName,DateOfBirth,Email,AdmissionYear,AcademicStatus,DeptCode,AdvisorID) VALUES
(101,'Ahmed','M.','Ali','2005-02-14','ahmed.ali@uni.edu',2024,'Active','CS',201),
(102,'Sara','A.','Omar','2004-09-03','sara.omar@uni.edu',2023,'Active','IT',202),
(103,'Khalid','N.','Noor','2005-06-19','khalid.noor@uni.edu',2024,'Active','CS',205),
(104,'Mona','S.','Salem','2004-11-25','mona.salem@uni.edu',2023,'Active','CYB',203),
(105,'Omar','H.','Saeed','2005-01-08','omar.saeed@uni.edu',2024,'Active','IT',NULL),
(106,'Huda','K.','Ali','2004-04-30','huda.ali@uni.edu',2023,'Active','AI',204),
(107,'Noura','R.','Hassan','2005-07-11','noura.hassan@uni.edu',2024,'Active','CYB',203),
(108,'Yousef','A.','Adel','2003-12-22','yousef.adel@uni.edu',2022,'Active','CS',205);

INSERT INTO StudentPhone VALUES
(101,'0501111001'),(101,'0561111001'),(102,'0501111002'),
(103,'0501111003'),(104,'0501111004'),(105,'0501111005'),
(106,'0501111006'),(107,'0501111007'),(108,'0501111008');

INSERT INTO Course VALUES
('BCS306','Database Management Systems',3,3,'Active','CS'),
('BCS221','Networking Basics',3,2,'Active','IT'),
('CYS321','Security Threats and Risk Analysis',3,3,'Active','CYB'),
('BCS407','Applied Artificial Intelligence',3,4,'Active','AI'),
('BCS301','Operating System Fundamentals',3,3,'Active','CS'),
('NET222','Wireless Networks',3,2,'Active','IT'),
('CYS312','Cryptographic Algorithms and Protocols',3,3,'Active','CYB'),
('BCS210','Prerequisite Course BCS210',3,2,'Inactive','CS');

INSERT INTO CoursePrerequisite VALUES
('BCS301','BCS210'),('NET222','BCS221'),
('CYS321','BCS221'),('CYS312','CYS321');

INSERT INTO Section VALUES
('BCS306','01','Fall',2026,8,'HUB-101','On-campus',201),
('BCS306','02','Fall',2026,6,'HUB-103','On-campus',205),
('BCS221','01','Fall',2026,10,'HUB-105','On-campus',202),
('CYS321','01','Fall',2026,8,'HUB-107','On-campus',203),
('BCS407','01','Fall',2026,7,'HUB-109','Hybrid',204),
('BCS301','01','Fall',2026,9,'HUB-111','On-campus',205);

-- Example meetings, since meeting times were not supplied.
INSERT INTO SectionMeeting VALUES
('BCS306','01','Fall',2026,1,'Monday','09:00','10:15','HUB-101'),
('BCS306','01','Fall',2026,2,'Wednesday','09:00','10:15','HUB-101');

-- Registration dates and term are illustrative because these fields were not supplied.
INSERT INTO Registration
(RegistrationID, StudentID, CourseCode, SectionNo, Semester, AcademicYear,
 RegistrationDate, RegistrationStatus, FinalMark) VALUES
(1001,101,'BCS306','01','Fall',2026,'2026-09-01','Completed',88),
(1002,101,'BCS301','01','Fall',2026,'2026-09-01','Registered',NULL),
(1003,102,'BCS221','01','Fall',2026,'2026-09-01','Completed',81),
(1005,103,'BCS306','01','Fall',2026,'2026-09-01','Completed',74),
(1007,104,'CYS321','01','Fall',2026,'2026-09-01','Completed',52),
(1009,105,'BCS221','01','Fall',2026,'2026-09-01','Completed',67),
(1011,106,'BCS407','01','Fall',2026,'2026-09-01','Completed',95),
(1014,108,'BCS306','02','Fall',2026,'2026-09-01','Completed',84);

-- 4. VIEWS FOR STAFF
CREATE VIEW RegistrationDetails AS
SELECT r.RegistrationID, s.StudentID,
       CONCAT_WS(' ',s.FirstName,s.MiddleName,s.FamilyName) AS StudentName,
       d.DeptName, c.CourseCode, c.CourseTitle,
       r.SectionNo, r.Semester, r.AcademicYear,
       CONCAT_WS(' ',i.FirstName,i.MiddleName,i.FamilyName) AS InstructorName,
       r.RegistrationStatus, r.RegistrationDate, r.FinalMark
FROM Registration r
JOIN Student s ON r.StudentID=s.StudentID
JOIN Section sec ON r.CourseCode=sec.CourseCode AND r.SectionNo=sec.SectionNo
                AND r.Semester=sec.Semester AND r.AcademicYear=sec.AcademicYear
JOIN Course c ON sec.CourseCode=c.CourseCode
JOIN Department d ON s.DeptCode=d.DeptCode
JOIN Instructor i ON sec.InstructorID=i.InstructorID;

CREATE VIEW SectionCapacity AS
SELECT sec.CourseCode, sec.SectionNo, sec.Semester, sec.AcademicYear,
       c.CourseTitle, sec.MaximumCapacity,
       COUNT(CASE WHEN r.RegistrationStatus='Registered' THEN 1 END) AS ActiveEnrollment,
       sec.MaximumCapacity - COUNT(CASE WHEN r.RegistrationStatus='Registered' THEN 1 END) AS RemainingSeats
FROM Section sec
JOIN Course c ON sec.CourseCode=c.CourseCode
LEFT JOIN Registration r ON sec.CourseCode=r.CourseCode AND sec.SectionNo=r.SectionNo
                        AND sec.Semester=r.Semester AND sec.AcademicYear=r.AcademicYear
GROUP BY sec.CourseCode, sec.SectionNo, sec.Semester, sec.AcademicYear,
         c.CourseTitle, sec.MaximumCapacity;

-- 5. PROCEDURES: TRANSACTIONS, MARKS AND REPORT
DELIMITER $$

CREATE PROCEDURE RegisterStudent(
    IN p_student INT, IN p_course VARCHAR(10), IN p_section VARCHAR(5),
    IN p_semester VARCHAR(10), IN p_year INT
)
BEGIN
    DECLARE seats INT;
    DECLARE enrolled INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    SELECT MaximumCapacity INTO seats FROM Section
    WHERE CourseCode=p_course AND SectionNo=p_section
      AND Semester=p_semester AND AcademicYear=p_year
    FOR UPDATE;
    IF seats IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section not found';
    END IF;
    SELECT COUNT(*) INTO enrolled FROM Registration
    WHERE CourseCode=p_course AND SectionNo=p_section
      AND Semester=p_semester AND AcademicYear=p_year
      AND RegistrationStatus='Registered';
    IF enrolled >= seats THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section is full';
    END IF;
    INSERT INTO Registration
        (StudentID,CourseCode,SectionNo,Semester,AcademicYear,RegistrationDate,RegistrationStatus)
    VALUES (p_student,p_course,p_section,p_semester,p_year,CURDATE(),'Registered');
    COMMIT;
END$$

CREATE PROCEDURE ChangeRegistrationStatus(IN p_registration INT, IN p_status VARCHAR(12))
BEGIN
    UPDATE Registration SET RegistrationStatus=p_status WHERE RegistrationID=p_registration;
END$$

CREATE PROCEDURE SetFinalMark(IN p_registration INT, IN p_mark DECIMAL(5,2))
BEGIN
    IF p_mark IS NULL OR p_mark < 0 OR p_mark > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Final mark must be 0 to 100';
    END IF;
    UPDATE Registration
    SET FinalMark=p_mark, RegistrationStatus='Completed'
    WHERE RegistrationID=p_registration;
END$$

CREATE PROCEDURE AcademicSectionReport(IN p_semester VARCHAR(10), IN p_year INT)
BEGIN
    SELECT s.CourseCode, c.CourseTitle, d.DeptName, s.SectionNo,
           CONCAT_WS(' ',i.FirstName,i.MiddleName,i.FamilyName) AS InstructorName,
           s.MaximumCapacity, cap.ActiveEnrollment, cap.RemainingSeats,
           grades.AverageFinalMark, grades.HighestFinalMark,
           grades.LowestFinalMark, COALESCE(grades.Below60,0) AS Below60
    FROM Section s
    JOIN Course c ON s.CourseCode=c.CourseCode
    JOIN Department d ON c.DeptCode=d.DeptCode
    JOIN Instructor i ON s.InstructorID=i.InstructorID
    JOIN SectionCapacity cap ON s.CourseCode=cap.CourseCode AND s.SectionNo=cap.SectionNo
                            AND s.Semester=cap.Semester AND s.AcademicYear=cap.AcademicYear
    LEFT JOIN (
        SELECT CourseCode, SectionNo, Semester, AcademicYear,
               AVG(FinalMark) AS AverageFinalMark,
               MAX(FinalMark) AS HighestFinalMark,
               MIN(FinalMark) AS LowestFinalMark,
               SUM(CASE WHEN FinalMark < 60 THEN 1 ELSE 0 END) AS Below60
        FROM Registration
        WHERE RegistrationStatus='Completed' AND FinalMark IS NOT NULL
        GROUP BY CourseCode, SectionNo, Semester, AcademicYear
    ) grades ON s.CourseCode=grades.CourseCode AND s.SectionNo=grades.SectionNo
            AND s.Semester=grades.Semester AND s.AcademicYear=grades.AcademicYear
    WHERE s.Semester=p_semester AND s.AcademicYear=p_year
      AND (
          cap.ActiveEnrollment > (
              SELECT AVG(ActiveEnrollment) FROM SectionCapacity
              WHERE Semester=p_semester AND AcademicYear=p_year
          )
          OR grades.AverageFinalMark < (
              SELECT AVG(FinalMark) FROM Registration
              WHERE Semester=p_semester AND AcademicYear=p_year
                AND RegistrationStatus='Completed' AND FinalMark IS NOT NULL
          )
      )
    ORDER BY cap.ActiveEnrollment DESC, grades.AverageFinalMark ASC;
END$$

DELIMITER ;

-- 6. DATABASE USERS (replace demo passwords before real use)
CREATE USER IF NOT EXISTS 'uni_registrar'@'localhost' IDENTIFIED BY 'Registrar123!';
CREATE USER IF NOT EXISTS 'uni_officer'@'localhost' IDENTIFIED BY 'Officer123!';
CREATE USER IF NOT EXISTS 'uni_report'@'localhost' IDENTIFIED BY 'Report123!';

GRANT SELECT, INSERT, UPDATE, DELETE ON bcs306_university.Department TO 'uni_registrar'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON bcs306_university.Instructor TO 'uni_registrar'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON bcs306_university.Student TO 'uni_registrar'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON bcs306_university.StudentPhone TO 'uni_registrar'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON bcs306_university.Course TO 'uni_registrar'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON bcs306_university.CoursePrerequisite TO 'uni_registrar'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON bcs306_university.Section TO 'uni_registrar'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON bcs306_university.SectionMeeting TO 'uni_registrar'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON bcs306_university.Registration TO 'uni_registrar'@'localhost';
GRANT SELECT ON bcs306_university.RegistrationAudit TO 'uni_registrar'@'localhost';
GRANT SELECT ON bcs306_university.RegistrationDetails TO 'uni_registrar'@'localhost';
GRANT SELECT ON bcs306_university.SectionCapacity TO 'uni_registrar'@'localhost';
GRANT EXECUTE ON bcs306_university.* TO 'uni_registrar'@'localhost';
-- Officer cannot change final marks or edit audit records.
GRANT SELECT, INSERT, UPDATE ON bcs306_university.Student TO 'uni_officer'@'localhost';
GRANT SELECT, INSERT, UPDATE ON bcs306_university.StudentPhone TO 'uni_officer'@'localhost';
GRANT SELECT ON bcs306_university.RegistrationDetails TO 'uni_officer'@'localhost';
GRANT SELECT ON bcs306_university.SectionCapacity TO 'uni_officer'@'localhost';
GRANT EXECUTE ON PROCEDURE bcs306_university.RegisterStudent TO 'uni_officer'@'localhost';
GRANT EXECUTE ON PROCEDURE bcs306_university.ChangeRegistrationStatus TO 'uni_officer'@'localhost';
GRANT SELECT ON bcs306_university.RegistrationDetails TO 'uni_report'@'localhost';
GRANT SELECT ON bcs306_university.SectionCapacity TO 'uni_report'@'localhost';
GRANT EXECUTE ON PROCEDURE bcs306_university.AcademicSectionReport TO 'uni_report'@'localhost';

-- 7. STUDENT AGE (calculated from DateOfBirth, not stored)
SELECT StudentID, FirstName, FamilyName,
       TIMESTAMPDIFF(YEAR, DateOfBirth, CURDATE()) AS Age
FROM Student;

-- Run to view the required management report:
CALL AcademicSectionReport('Fall',2026);
