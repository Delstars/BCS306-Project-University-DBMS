-- BCS 306 PROJECT 1 | Execute using a local administrator in MySQL Workbench.
-- WARNING: This script RESETS ONLY the dedicated UniversityProject1DB database.
-- Do not run against an existing database containing work you need to keep.
DROP DATABASE IF EXISTS UniversityProject1DB;
CREATE DATABASE UniversityProject1DB;
USE UniversityProject1DB;

-- ChairID FK is added after initial data is loaded because of the circular
-- relationship: Department has a chair, and Instructor belongs to Department.
CREATE TABLE Department (
    DeptCode VARCHAR(10) PRIMARY KEY,
    DeptName VARCHAR(100) NOT NULL UNIQUE,
    Office VARCHAR(30) NOT NULL,
    ChairID INT UNIQUE
);

CREATE TABLE Instructor (
    InstructorID INT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    MiddleName VARCHAR(50),
    FamilyName VARCHAR(50) NOT NULL,
    Email VARCHAR(120) NOT NULL UNIQUE,
    Specialization VARCHAR(100) NOT NULL,
    OfficeExtension VARCHAR(12),
    DeptCode VARCHAR(10) NOT NULL,
    CONSTRAINT UQ_Instructor_Dept UNIQUE (InstructorID, DeptCode),
    CONSTRAINT FK_Instructor_Department FOREIGN KEY (DeptCode)
        REFERENCES Department(DeptCode) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE Student (
    StudentID INT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    MiddleName VARCHAR(50),
    FamilyName VARCHAR(50) NOT NULL,
    DateOfBirth DATE NOT NULL,
    Email VARCHAR(120) NOT NULL UNIQUE,
    AdmissionYear INT NOT NULL,
    StudentStatus VARCHAR(20) NOT NULL DEFAULT 'Active',
    Street VARCHAR(100),
    City VARCHAR(60),
    Emirate VARCHAR(60),
    PostalCode VARCHAR(20),
    DeptCode VARCHAR(10) NOT NULL,
    AdvisorID INT,
    CONSTRAINT CHK_Student_Status CHECK (StudentStatus IN ('Active', 'Inactive', 'Graduated', 'Suspended')),
    CONSTRAINT CHK_Student_AdmissionYear CHECK (AdmissionYear BETWEEN 1950 AND 2100),
    CONSTRAINT FK_Student_Department FOREIGN KEY (DeptCode)
        REFERENCES Department(DeptCode) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT FK_Student_Advisor FOREIGN KEY (AdvisorID)
        REFERENCES Instructor(InstructorID) ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE StudentPhone (
    StudentID INT NOT NULL,
    PhoneNumber VARCHAR(20) NOT NULL,
    CONSTRAINT PK_StudentPhone PRIMARY KEY (StudentID, PhoneNumber),
    CONSTRAINT FK_StudentPhone_Student FOREIGN KEY (StudentID)
        REFERENCES Student(StudentID) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE Course (
    CourseCode VARCHAR(10) PRIMARY KEY,
    CourseTitle VARCHAR(150) NOT NULL,
    Credits INT NOT NULL,
    AcademicLevel INT NOT NULL,
    CourseStatus VARCHAR(20) NOT NULL DEFAULT 'Active',
    DeptCode VARCHAR(10) NOT NULL,
    CONSTRAINT CHK_Course_Credits CHECK (Credits BETWEEN 1 AND 6),
    CONSTRAINT CHK_Course_Level CHECK (AcademicLevel BETWEEN 1 AND 8),
    CONSTRAINT CHK_Course_Status CHECK (CourseStatus IN ('Active', 'Inactive')),
    CONSTRAINT FK_Course_Department FOREIGN KEY (DeptCode)
        REFERENCES Department(DeptCode) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE CoursePrerequisite (
    CourseCode VARCHAR(10) NOT NULL,
    PrerequisiteCourseCode VARCHAR(10) NOT NULL,
    CONSTRAINT PK_CoursePrerequisite PRIMARY KEY (CourseCode, PrerequisiteCourseCode),
    CONSTRAINT FK_Prereq_Course FOREIGN KEY (CourseCode)
        REFERENCES Course(CourseCode) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_Prereq_Required FOREIGN KEY (PrerequisiteCourseCode)
        REFERENCES Course(CourseCode) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE Section (
    CourseCode VARCHAR(10) NOT NULL,
    SectionNo VARCHAR(5) NOT NULL,
    Semester VARCHAR(15) NOT NULL,
    AcademicYear INT NOT NULL,
    MaximumCapacity INT NOT NULL,
    Classroom VARCHAR(30) NOT NULL,
    DeliveryMode VARCHAR(30) NOT NULL,
    InstructorID INT NOT NULL,
    CONSTRAINT PK_Section PRIMARY KEY (CourseCode, SectionNo, Semester, AcademicYear),
    CONSTRAINT CHK_Section_Capacity CHECK (MaximumCapacity > 0),
    CONSTRAINT CHK_Section_Semester CHECK (Semester IN ('Fall','Spring','Summer')),
    CONSTRAINT CHK_Section_Mode CHECK (DeliveryMode IN ('On-campus','Hybrid','Online')),
    CONSTRAINT FK_Section_Course FOREIGN KEY (CourseCode)
        REFERENCES Course(CourseCode) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT FK_Section_Instructor FOREIGN KEY (InstructorID)
        REFERENCES Instructor(InstructorID) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- MeetingNo is meaningful only within its parent Section (weak entity).
CREATE TABLE SectionMeeting (
    CourseCode VARCHAR(10) NOT NULL,
    SectionNo VARCHAR(5) NOT NULL,
    Semester VARCHAR(15) NOT NULL,
    AcademicYear INT NOT NULL,
    MeetingNo INT NOT NULL,
    DayOfWeek VARCHAR(12) NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    Room VARCHAR(30) NOT NULL,
    CONSTRAINT PK_SectionMeeting PRIMARY KEY
        (CourseCode, SectionNo, Semester, AcademicYear, MeetingNo),
    CONSTRAINT CHK_SectionMeeting_Times CHECK (StartTime < EndTime),
    CONSTRAINT CHK_SectionMeeting_Day CHECK
        (DayOfWeek IN ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')),
    CONSTRAINT FK_SectionMeeting_Section FOREIGN KEY
        (CourseCode, SectionNo, Semester, AcademicYear)
        REFERENCES Section(CourseCode, SectionNo, Semester, AcademicYear)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE Registration (
    RegistrationID INT AUTO_INCREMENT PRIMARY KEY,
    StudentID INT NOT NULL,
    CourseCode VARCHAR(10) NOT NULL,
    SectionNo VARCHAR(5) NOT NULL,
    Semester VARCHAR(15) NOT NULL,
    AcademicYear INT NOT NULL,
    RegistrationDate DATE NOT NULL,
    RegistrationStatus VARCHAR(20) NOT NULL DEFAULT 'Registered',
    FinalMark DECIMAL(5,2) NULL,
    CONSTRAINT UQ_Registration_StudentSection UNIQUE
        (StudentID, CourseCode, SectionNo, Semester, AcademicYear),
    CONSTRAINT CHK_Registration_Status CHECK
        (RegistrationStatus IN ('Registered','Dropped','Completed')),
    CONSTRAINT CHK_Registration_Mark CHECK (FinalMark IS NULL OR FinalMark BETWEEN 0 AND 100),
    CONSTRAINT CHK_Completed_HasMark CHECK
        (RegistrationStatus <> 'Completed' OR FinalMark IS NOT NULL),
    CONSTRAINT FK_Registration_Student FOREIGN KEY (StudentID)
        REFERENCES Student(StudentID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT FK_Registration_Section FOREIGN KEY
        (CourseCode, SectionNo, Semester, AcademicYear)
        REFERENCES Section(CourseCode, SectionNo, Semester, AcademicYear)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Keep a historical snapshot; intentionally NO FK to Registration, since
-- registration deletion must not delete its audit history.
CREATE TABLE RegistrationAudit (
    AuditID INT AUTO_INCREMENT PRIMARY KEY,
    RegistrationID INT NOT NULL,
    StudentID INT NOT NULL,
    CourseCode VARCHAR(10) NOT NULL,
    SectionNo VARCHAR(5) NOT NULL,
    Semester VARCHAR(15) NOT NULL,
    AcademicYear INT NOT NULL,
    EventType VARCHAR(40) NOT NULL,
    OldStatus VARCHAR(20),
    NewStatus VARCHAR(20),
    OldFinalMark DECIMAL(5,2),
    NewFinalMark DECIMAL(5,2),
    DatabaseUser VARCHAR(288) NOT NULL,
    EventTime DATETIME NOT NULL,
    CONSTRAINT CHK_Audit_Event CHECK (EventType IN (
        'REGISTRATION_CREATED', 'REGISTRATION_STATUS_CHANGED',
        'FINAL_MARK_CHANGED', 'REGISTRATION_DELETED'))
);

SHOW TABLES;

-- BCS 306 PROJECT 1 | Rules, audit triggers, views, and procedures.
-- Run after 01_schema.sql and BEFORE 03_seed.sql (seed events are audited).
USE UniversityProject1DB;

DELIMITER //
-- Use triggers because the prerequisite columns have cascading foreign keys.
CREATE TRIGGER trg_prerequisite_before_insert
BEFORE INSERT ON CoursePrerequisite FOR EACH ROW
BEGIN
    IF NEW.CourseCode = NEW.PrerequisiteCourseCode THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A course cannot be its own prerequisite';
    END IF;
END//

CREATE TRIGGER trg_prerequisite_before_update
BEFORE UPDATE ON CoursePrerequisite FOR EACH ROW
BEGIN
    IF NEW.CourseCode = NEW.PrerequisiteCourseCode THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A course cannot be its own prerequisite';
    END IF;
END//

CREATE TRIGGER trg_registration_before_insert
BEFORE INSERT ON Registration FOR EACH ROW
BEGIN
    DECLARE v_capacity INT DEFAULT NULL;
    DECLARE v_active INT DEFAULT 0;
    -- FOR UPDATE serializes competing attempts to reserve the same section.
    SELECT MaximumCapacity INTO v_capacity
    FROM Section
    WHERE CourseCode=NEW.CourseCode AND SectionNo=NEW.SectionNo
      AND Semester=NEW.Semester AND AcademicYear=NEW.AcademicYear
    FOR UPDATE;
    IF v_capacity IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section does not exist';
    END IF;
    IF NEW.RegistrationStatus='Registered' THEN
        SELECT COUNT(*) INTO v_active FROM Registration
        WHERE CourseCode=NEW.CourseCode AND SectionNo=NEW.SectionNo
          AND Semester=NEW.Semester AND AcademicYear=NEW.AcademicYear
          AND RegistrationStatus='Registered';
        IF v_active >= v_capacity THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section is at maximum capacity';
        END IF;
    END IF;
END//

CREATE TRIGGER trg_registration_before_update
BEFORE UPDATE ON Registration FOR EACH ROW
BEGIN
    DECLARE v_capacity INT DEFAULT NULL;
    DECLARE v_active INT DEFAULT 0;
    IF NEW.StudentID<>OLD.StudentID OR NEW.CourseCode<>OLD.CourseCode
       OR NEW.SectionNo<>OLD.SectionNo OR NEW.Semester<>OLD.Semester
       OR NEW.AcademicYear<>OLD.AcademicYear THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Registration identity cannot be changed';
    END IF;
    -- Completed records are final; their mark may be corrected by Registrar,
    -- but the enrollment should not be silently reopened or dropped.
    IF OLD.RegistrationStatus='Completed'
       AND NEW.RegistrationStatus<>'Completed' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Completed registration cannot be reopened';
    END IF;
    IF NEW.RegistrationStatus='Registered' AND OLD.RegistrationStatus<>'Registered' THEN
        SELECT MaximumCapacity INTO v_capacity FROM Section
        WHERE CourseCode=NEW.CourseCode AND SectionNo=NEW.SectionNo
          AND Semester=NEW.Semester AND AcademicYear=NEW.AcademicYear FOR UPDATE;
        SELECT COUNT(*) INTO v_active FROM Registration
        WHERE CourseCode=NEW.CourseCode AND SectionNo=NEW.SectionNo
          AND Semester=NEW.Semester AND AcademicYear=NEW.AcademicYear
          AND RegistrationStatus='Registered';
        IF v_active >= v_capacity THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section is at maximum capacity';
        END IF;
    END IF;
END//

CREATE TRIGGER trg_registration_after_insert
AFTER INSERT ON Registration FOR EACH ROW
BEGIN
    INSERT INTO RegistrationAudit
       (RegistrationID,StudentID,CourseCode,SectionNo,Semester,AcademicYear,
        EventType,NewStatus,NewFinalMark,DatabaseUser,EventTime)
    VALUES (NEW.RegistrationID,NEW.StudentID,NEW.CourseCode,NEW.SectionNo,
        NEW.Semester,NEW.AcademicYear,'REGISTRATION_CREATED',
        NEW.RegistrationStatus,NEW.FinalMark,USER(),NOW());
END//

CREATE TRIGGER trg_registration_after_update
AFTER UPDATE ON Registration FOR EACH ROW
BEGIN
    IF OLD.RegistrationStatus <> NEW.RegistrationStatus THEN
        INSERT INTO RegistrationAudit
          (RegistrationID,StudentID,CourseCode,SectionNo,Semester,AcademicYear,
           EventType,OldStatus,NewStatus,OldFinalMark,NewFinalMark,DatabaseUser,EventTime)
        VALUES (NEW.RegistrationID,NEW.StudentID,NEW.CourseCode,NEW.SectionNo,
          NEW.Semester,NEW.AcademicYear,'REGISTRATION_STATUS_CHANGED',
          OLD.RegistrationStatus,NEW.RegistrationStatus,OLD.FinalMark,NEW.FinalMark,USER(),NOW());
    END IF;
    IF OLD.FinalMark <> NEW.FinalMark
       OR (OLD.FinalMark IS NULL AND NEW.FinalMark IS NOT NULL)
       OR (OLD.FinalMark IS NOT NULL AND NEW.FinalMark IS NULL) THEN
        INSERT INTO RegistrationAudit
          (RegistrationID,StudentID,CourseCode,SectionNo,Semester,AcademicYear,
           EventType,OldStatus,NewStatus,OldFinalMark,NewFinalMark,DatabaseUser,EventTime)
        VALUES (NEW.RegistrationID,NEW.StudentID,NEW.CourseCode,NEW.SectionNo,
          NEW.Semester,NEW.AcademicYear,'FINAL_MARK_CHANGED',
          OLD.RegistrationStatus,NEW.RegistrationStatus,OLD.FinalMark,NEW.FinalMark,USER(),NOW());
    END IF;
END//

CREATE TRIGGER trg_registration_after_delete
AFTER DELETE ON Registration FOR EACH ROW
BEGIN
    INSERT INTO RegistrationAudit
      (RegistrationID,StudentID,CourseCode,SectionNo,Semester,AcademicYear,
       EventType,OldStatus,OldFinalMark,DatabaseUser,EventTime)
    VALUES (OLD.RegistrationID,OLD.StudentID,OLD.CourseCode,OLD.SectionNo,
       OLD.Semester,OLD.AcademicYear,'REGISTRATION_DELETED',
       OLD.RegistrationStatus,OLD.FinalMark,USER(),NOW());
END//
CREATE TRIGGER trg_section_before_update
BEFORE UPDATE ON Section FOR EACH ROW
BEGIN
    DECLARE v_active INT DEFAULT 0;
    IF NEW.MaximumCapacity < OLD.MaximumCapacity THEN
        SELECT COUNT(*) INTO v_active FROM Registration
        WHERE CourseCode=OLD.CourseCode AND SectionNo=OLD.SectionNo
          AND Semester=OLD.Semester AND AcademicYear=OLD.AcademicYear
          AND RegistrationStatus='Registered';
        IF NEW.MaximumCapacity < v_active THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT='Cannot lower section capacity below active enrollment';
        END IF;
    END IF;
END//
DELIMITER ;

CREATE VIEW v_StudentDirectory AS
SELECT s.StudentID, CONCAT(s.FirstName,' ',s.FamilyName) AS StudentName,
       TIMESTAMPDIFF(YEAR,s.DateOfBirth,CURDATE()) AS Age,
       s.Email,s.StudentStatus,s.AdmissionYear,s.DeptCode,d.DeptName,
       s.AdvisorID
FROM Student s JOIN Department d ON s.DeptCode=d.DeptCode;

CREATE VIEW v_RegistrationDetails AS
SELECT r.RegistrationID,r.StudentID,
       CONCAT(st.FirstName,' ',st.FamilyName) AS StudentName,
       d.DeptName AS DepartmentName,
       r.CourseCode,c.CourseTitle,r.SectionNo,r.Semester,r.AcademicYear,
       CONCAT(i.FirstName,' ',i.FamilyName) AS InstructorName,
       r.RegistrationStatus,r.RegistrationDate,r.FinalMark
FROM Registration r JOIN Student st ON r.StudentID=st.StudentID
JOIN Department d ON st.DeptCode=d.DeptCode
JOIN Course c ON r.CourseCode=c.CourseCode
JOIN Section sec ON r.CourseCode=sec.CourseCode AND r.SectionNo=sec.SectionNo
     AND r.Semester=sec.Semester AND r.AcademicYear=sec.AcademicYear
JOIN Instructor i ON sec.InstructorID=i.InstructorID;

CREATE VIEW v_SectionCapacity AS
SELECT sec.CourseCode,c.CourseTitle,sec.SectionNo,sec.Semester,sec.AcademicYear,
       sec.MaximumCapacity,
       COUNT(r.RegistrationID) AS ActiveEnrollment,
       sec.MaximumCapacity-COUNT(r.RegistrationID) AS RemainingSeats
FROM Section sec JOIN Course c ON sec.CourseCode=c.CourseCode
LEFT JOIN Registration r ON sec.CourseCode=r.CourseCode AND sec.SectionNo=r.SectionNo
    AND sec.Semester=r.Semester AND sec.AcademicYear=r.AcademicYear
    AND r.RegistrationStatus='Registered'
GROUP BY sec.CourseCode,c.CourseTitle,sec.SectionNo,sec.Semester,sec.AcademicYear,sec.MaximumCapacity;

DELIMITER //
CREATE PROCEDURE RegisterStudent(
    IN p_student INT, IN p_course VARCHAR(10), IN p_section VARCHAR(5),
    IN p_semester VARCHAR(15), IN p_year INT
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_capacity INT DEFAULT NULL;
    DECLARE v_active INT DEFAULT 0;
    DECLARE v_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;
    START TRANSACTION;
    SELECT COUNT(*) INTO v_exists FROM Student WHERE StudentID=p_student;
    IF v_exists=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Student does not exist';
    END IF;
    -- Lock the parent section first to prevent concurrent overbooking.
    SELECT MaximumCapacity INTO v_capacity FROM Section
      WHERE CourseCode=p_course AND SectionNo=p_section
        AND Semester=p_semester AND AcademicYear=p_year FOR UPDATE;
    IF v_capacity IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Section does not exist';
    END IF;
    SELECT COUNT(*) INTO v_exists FROM Registration
      WHERE StudentID=p_student AND CourseCode=p_course AND SectionNo=p_section
        AND Semester=p_semester AND AcademicYear=p_year;
    IF v_exists>0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Student already registered in this section';
    END IF;
    SELECT COUNT(*) INTO v_active FROM Registration
      WHERE CourseCode=p_course AND SectionNo=p_section
        AND Semester=p_semester AND AcademicYear=p_year
        AND RegistrationStatus='Registered';
    IF v_active>=v_capacity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Section is at maximum capacity';
    END IF;
    INSERT INTO Registration
      (StudentID,CourseCode,SectionNo,Semester,AcademicYear,RegistrationDate,RegistrationStatus,FinalMark)
    VALUES (p_student,p_course,p_section,p_semester,p_year,CURDATE(),'Registered',NULL);
    COMMIT;
    SELECT 'Registration created successfully' AS Message;
END//

CREATE PROCEDURE ChangeRegistrationStatus(IN p_id INT,IN p_status VARCHAR(20))
SQL SECURITY DEFINER
BEGIN
    IF p_status NOT IN ('Registered','Dropped') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use CompleteRegistration to set Completed';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM Registration WHERE RegistrationID=p_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registration not found';
    END IF;
    UPDATE Registration SET RegistrationStatus=p_status WHERE RegistrationID=p_id;
    -- The existence check is done before the UPDATE (no ROW_COUNT needed).
END//

CREATE PROCEDURE SetFinalMark(IN p_id INT,IN p_mark DECIMAL(5,2))
SQL SECURITY DEFINER
BEGIN
    IF p_mark IS NULL OR p_mark<0 OR p_mark>100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Final mark must be between 0 and 100';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM Registration
                  WHERE RegistrationID=p_id AND RegistrationStatus<>'Dropped') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registration not found or is dropped';
    END IF;
    UPDATE Registration SET FinalMark=p_mark WHERE RegistrationID=p_id;
END//

CREATE PROCEDURE CompleteRegistration(IN p_id INT,IN p_mark DECIMAL(5,2))
SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;
    IF p_mark IS NULL OR p_mark<0 OR p_mark>100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Final mark must be between 0 and 100';
    END IF;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM Registration
                  WHERE RegistrationID=p_id AND RegistrationStatus<>'Dropped') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registration not found or is dropped';
    END IF;
    UPDATE Registration SET RegistrationStatus='Completed',FinalMark=p_mark
      WHERE RegistrationID=p_id;
    COMMIT;
END//

-- Lab 6 scalar/correlated subqueries, Lab 5 aggregates, Lab 6 JOIN.
-- Uses only joins, comparison subqueries, COUNT/AVG/MIN/MAX/ROUND.
CREATE PROCEDURE GetSectionPerformanceReport(IN p_semester VARCHAR(15),IN p_year INT)
SQL SECURITY DEFINER
BEGIN
    SELECT sec.CourseCode,c.CourseTitle,d.DeptName AS DepartmentName,
           sec.SectionNo,CONCAT(i.FirstName,' ',i.FamilyName) AS InstructorName,
           sec.MaximumCapacity,
           (SELECT COUNT(*) FROM Registration r
            WHERE r.CourseCode=sec.CourseCode AND r.SectionNo=sec.SectionNo
              AND r.Semester=sec.Semester AND r.AcademicYear=sec.AcademicYear
              AND r.RegistrationStatus='Registered') AS ActiveEnrollment,
           sec.MaximumCapacity-
           (SELECT COUNT(*) FROM Registration r
            WHERE r.CourseCode=sec.CourseCode AND r.SectionNo=sec.SectionNo
              AND r.Semester=sec.Semester AND r.AcademicYear=sec.AcademicYear
              AND r.RegistrationStatus='Registered') AS RemainingSeats,
           (SELECT ROUND(AVG(r.FinalMark),2) FROM Registration r
            WHERE r.CourseCode=sec.CourseCode AND r.SectionNo=sec.SectionNo
              AND r.Semester=sec.Semester AND r.AcademicYear=sec.AcademicYear
              AND r.RegistrationStatus='Completed') AS AverageCompletedMark,
           (SELECT MAX(r.FinalMark) FROM Registration r
            WHERE r.CourseCode=sec.CourseCode AND r.SectionNo=sec.SectionNo
              AND r.Semester=sec.Semester AND r.AcademicYear=sec.AcademicYear
              AND r.RegistrationStatus='Completed') AS HighestFinalMark,
           (SELECT MIN(r.FinalMark) FROM Registration r
            WHERE r.CourseCode=sec.CourseCode AND r.SectionNo=sec.SectionNo
              AND r.Semester=sec.Semester AND r.AcademicYear=sec.AcademicYear
              AND r.RegistrationStatus='Completed') AS LowestFinalMark,
           (SELECT COUNT(*) FROM Registration r
            WHERE r.CourseCode=sec.CourseCode AND r.SectionNo=sec.SectionNo
              AND r.Semester=sec.Semester AND r.AcademicYear=sec.AcademicYear
              AND r.RegistrationStatus='Completed' AND r.FinalMark<60) AS Below60Count
    FROM Section sec JOIN Course c ON sec.CourseCode=c.CourseCode
    JOIN Department d ON c.DeptCode=d.DeptCode
    JOIN Instructor i ON sec.InstructorID=i.InstructorID
    WHERE sec.Semester=p_semester AND sec.AcademicYear=p_year
    AND (
      (SELECT COUNT(*) FROM Registration r
       WHERE r.CourseCode=sec.CourseCode AND r.SectionNo=sec.SectionNo
         AND r.Semester=sec.Semester AND r.AcademicYear=sec.AcademicYear
         AND r.RegistrationStatus='Registered') >
      (SELECT COUNT(*) FROM Registration r
       WHERE r.Semester=p_semester AND r.AcademicYear=p_year
         AND r.RegistrationStatus='Registered') /
      (SELECT COUNT(*) FROM Section s
       WHERE s.Semester=p_semester AND s.AcademicYear=p_year)
      OR
      (SELECT AVG(r.FinalMark) FROM Registration r
       WHERE r.CourseCode=sec.CourseCode AND r.SectionNo=sec.SectionNo
         AND r.Semester=sec.Semester AND r.AcademicYear=sec.AcademicYear
         AND r.RegistrationStatus='Completed') <
      (SELECT AVG(r.FinalMark) FROM Registration r
       WHERE r.Semester=p_semester AND r.AcademicYear=p_year
         AND r.RegistrationStatus='Completed')
    )
    ORDER BY ActiveEnrollment DESC, AverageCompletedMark ASC;
END//
DELIMITER ;

-- BCS 306 PROJECT 1 | Original professor baseline, plus labelled supporting data.
-- Run AFTER 02_logic.sql so all eight original registrations produce audit records.
USE UniversityProject1DB;

-- EXACT professor-provided departments.
INSERT INTO Department (DeptCode,DeptName,Office,ChairID) VALUES
('CS','Computer Science','B-201',201),
('IT','Information Technology','B-203',202),
('CYB','Cybersecurity','C-105',203),
('AI','Artificial Intelligence','C-107',204);

-- EXACT professor-provided instructors. OfficeExtension was not supplied: NULL.
INSERT INTO Instructor
(InstructorID,FirstName,MiddleName,FamilyName,Email,Specialization,OfficeExtension,DeptCode) VALUES
(201,'Sami','H.','Hassan','sami.hassan@uni.edu','Databases',NULL,'CS'),
(202,'Amal','N.','Noor','amal.noor@uni.edu','Networking',NULL,'IT'),
(203,'Noor','S.','Salem','noor.salem@uni.edu','Cybersecurity',NULL,'CYB'),
(204,'Hani','O.','Omar','hani.omar@uni.edu','AI',NULL,'AI'),
(205,'Maha','A.','Ali','maha.ali@uni.edu','Software Engineering',NULL,'CS');

-- Instructor-provided students. Student addresses were not supplied: NULL.
INSERT INTO Student
(StudentID,FirstName,MiddleName,FamilyName,DateOfBirth,Email,AdmissionYear,
 StudentStatus,DeptCode,AdvisorID) VALUES
(101,'Ahmed','M.','Ali','2005-02-14','ahmed.ali@uni.edu',2024,'Active','CS',201),
(102,'Sara','A.','Omar','2004-09-03','sara.omar@uni.edu',2023,'Active','IT',202),
(103,'Khalid','N.','Noor','2005-06-19','khalid.noor@uni.edu',2024,'Active','CS',205),
(104,'Mona','S.','Salem','2004-11-25','mona.salem@uni.edu',2023,'Active','CYB',203),
(105,'Omar','H.','Saeed','2005-01-08','omar.saeed@uni.edu',2024,'Active','IT',NULL),
(106,'Huda','K.','Ali','2004-04-30','huda.ali@uni.edu',2023,'Active','AI',204),
(107,'Noura','R.','Hassan','2005-07-11','noura.hassan@uni.edu',2024,'Active','CYB',203),
(108,'Yousef','A.','Adel','2003-12-22','yousef.adel@uni.edu',2022,'Active','CS',205);

INSERT INTO StudentPhone (StudentID,PhoneNumber) VALUES
(101,'0501111001'),(101,'0561111001'),(102,'0501111002'),
(103,'0501111003'),(104,'0501111004'),(105,'0501111005'),
(106,'0501111006'),(107,'0501111007'),(108,'0501111008');

-- EXACT seven professor-provided courses.
INSERT INTO Course (CourseCode,CourseTitle,Credits,AcademicLevel,CourseStatus,DeptCode) VALUES
('BCS306','Database Management Systems',3,3,'Active','CS'),
('BCS221','Networking Basics',3,2,'Active','IT'),
('CYS321','Security Threats and Risk Analysis',3,3,'Active','CYB'),
('BCS407','Applied Artificial Intelligence',3,4,'Active','AI'),
('BCS301','Operating System Fundamentals',3,3,'Active','CS'),
('NET222','Wireless Networks',3,2,'Active','IT'),
('CYS312','Cryptographic Algorithms and Protocols',3,3,'Active','CYB');

-- SYNTHESIZED SUPPORTING ROW (not in instructor Course data):
-- BCS301 requires BCS210, which is absent from the given Course rows.
-- Title/credits/level/status are illustrative and MUST be labelled in the report.
INSERT INTO Course (CourseCode,CourseTitle,Credits,AcademicLevel,CourseStatus,DeptCode) VALUES
('BCS210','Prerequisite Course (Title Not Provided)',3,2,'Inactive','CS');

-- EXACT professor-provided recursive prerequisite pairs.
INSERT INTO CoursePrerequisite (CourseCode,PrerequisiteCourseCode) VALUES
('BCS301','BCS210'),('NET222','BCS221'),
('CYS321','BCS221'),('CYS312','CYS321');

-- EXACT professor-provided sections; "01" and "02" are STRINGS.
INSERT INTO Section
(CourseCode,SectionNo,Semester,AcademicYear,MaximumCapacity,Classroom,DeliveryMode,InstructorID) VALUES
('BCS306','01','Fall',2026,8,'HUB-101','On-campus',201),
('BCS306','02','Fall',2026,6,'HUB-103','On-campus',205),
('BCS221','01','Fall',2026,10,'HUB-105','On-campus',202),
('CYS321','01','Fall',2026,8,'HUB-107','On-campus',203),
('BCS407','01','Fall',2026,7,'HUB-109','Hybrid',204),
('BCS301','01','Fall',2026,9,'HUB-111','On-campus',205);

-- SYNTHESIZED MEETINGS. No meeting data appeared in the instructor baseline.
INSERT INTO SectionMeeting
(CourseCode,SectionNo,Semester,AcademicYear,MeetingNo,DayOfWeek,StartTime,EndTime,Room) VALUES
('BCS306','01','Fall',2026,1,'Monday','09:00','10:15','HUB-101'),
('BCS306','01','Fall',2026,2,'Wednesday','09:00','10:15','HUB-101'),
('BCS306','02','Fall',2026,1,'Monday','11:00','12:15','HUB-103'),
('BCS306','02','Fall',2026,2,'Wednesday','11:00','12:15','HUB-103'),
('BCS221','01','Fall',2026,1,'Tuesday','09:00','10:15','HUB-105'),
('CYS321','01','Fall',2026,1,'Tuesday','11:00','12:15','HUB-107'),
('BCS407','01','Fall',2026,1,'Thursday','09:00','10:15','HUB-109'),
('BCS301','01','Fall',2026,1,'Tuesday','14:00','15:15','HUB-111');

-- EXACT professor IDs, students, course/section, status, marks.
-- ASSUMPTION: all eight given registrations refer to Fall 2026, since only
-- Fall 2026 sections exist. RegistrationDate was missing and is SYNTHESIZED.
INSERT INTO Registration
(RegistrationID,StudentID,CourseCode,SectionNo,Semester,AcademicYear,
 RegistrationDate,RegistrationStatus,FinalMark) VALUES
(1001,101,'BCS306','01','Fall',2026,'2026-09-01','Completed',88),
(1002,101,'BCS301','01','Fall',2026,'2026-09-01','Registered',NULL),
(1003,102,'BCS221','01','Fall',2026,'2026-09-01','Completed',81),
(1005,103,'BCS306','01','Fall',2026,'2026-09-01','Completed',74),
(1007,104,'CYS321','01','Fall',2026,'2026-09-01','Completed',52),
(1009,105,'BCS221','01','Fall',2026,'2026-09-01','Completed',67),
(1011,106,'BCS407','01','Fall',2026,'2026-09-01','Completed',95),
(1014,108,'BCS306','02','Fall',2026,'2026-09-01','Completed',84);

-- Now enforce mandatory chair and matching-chair-department participation.
-- A composite FK ensures the ChairID is a member of THIS department.
ALTER TABLE Department MODIFY ChairID INT NOT NULL;
ALTER TABLE Department ADD CONSTRAINT FK_Department_Chair
    FOREIGN KEY (ChairID,DeptCode)
    REFERENCES Instructor(InstructorID,DeptCode)
    ON DELETE RESTRICT;

-- Baseline counts: 4 departments, 5 instructors, 8 students, 9 phones,
-- 7 specified courses + 1 labelled supporting course, 4 prerequisites,
-- 6 sections, 8 synthetic meetings, 8 registrations, 8 creation-audit rows.
-- Verification uses separate SELECT statements as in Labs 3-5.
SELECT COUNT(*) AS TotalDepartments FROM Department;
SELECT COUNT(*) AS TotalInstructors FROM Instructor;
SELECT COUNT(*) AS TotalStudents FROM Student;
SELECT COUNT(*) AS TotalPhones FROM StudentPhone;
SELECT COUNT(*) AS TotalCourses FROM Course;
SELECT COUNT(*) AS TotalPrerequisites FROM CoursePrerequisite;
SELECT COUNT(*) AS TotalSections FROM Section;
SELECT COUNT(*) AS TotalMeetings FROM SectionMeeting;
SELECT COUNT(*) AS TotalRegistrations FROM Registration;
SELECT COUNT(*) AS TotalAuditEvents FROM RegistrationAudit;

-- BCS 306 PROJECT 1 | Run as MySQL administrator AFTER schema, logic and seed.
-- CLASSROOM-ONLY demo passwords. CHANGE them before using on a shared server.
USE UniversityProject1DB;

DROP USER IF EXISTS 'p1_registrar'@'localhost';
DROP USER IF EXISTS 'p1_officer'@'localhost';
DROP USER IF EXISTS 'p1_report'@'localhost';
CREATE USER 'p1_registrar'@'localhost' IDENTIFIED BY 'CHANGE_ME_REGISTRAR';
CREATE USER 'p1_officer'@'localhost' IDENTIFIED BY 'CHANGE_ME_OFFICER';
CREATE USER 'p1_report'@'localhost' IDENTIFIED BY 'CHANGE_ME_REPORT';

-- Registrar: operational table DML, but audit records remain read-only.
GRANT SELECT,INSERT,UPDATE,DELETE ON UniversityProject1DB.Department TO 'p1_registrar'@'localhost';
GRANT SELECT,INSERT,UPDATE,DELETE ON UniversityProject1DB.Instructor TO 'p1_registrar'@'localhost';
GRANT SELECT,INSERT,UPDATE,DELETE ON UniversityProject1DB.Student TO 'p1_registrar'@'localhost';
GRANT SELECT,INSERT,UPDATE,DELETE ON UniversityProject1DB.StudentPhone TO 'p1_registrar'@'localhost';
GRANT SELECT,INSERT,UPDATE,DELETE ON UniversityProject1DB.Course TO 'p1_registrar'@'localhost';
GRANT SELECT,INSERT,UPDATE,DELETE ON UniversityProject1DB.CoursePrerequisite TO 'p1_registrar'@'localhost';
GRANT SELECT,INSERT,UPDATE,DELETE ON UniversityProject1DB.Section TO 'p1_registrar'@'localhost';
GRANT SELECT,INSERT,UPDATE,DELETE ON UniversityProject1DB.SectionMeeting TO 'p1_registrar'@'localhost';
GRANT SELECT,INSERT,UPDATE,DELETE ON UniversityProject1DB.Registration TO 'p1_registrar'@'localhost';
GRANT SELECT ON UniversityProject1DB.RegistrationAudit TO 'p1_registrar'@'localhost';
GRANT SELECT ON UniversityProject1DB.v_StudentDirectory TO 'p1_registrar'@'localhost';
GRANT SELECT ON UniversityProject1DB.v_RegistrationDetails TO 'p1_registrar'@'localhost';
GRANT SELECT ON UniversityProject1DB.v_SectionCapacity TO 'p1_registrar'@'localhost';
GRANT EXECUTE ON PROCEDURE UniversityProject1DB.RegisterStudent TO 'p1_registrar'@'localhost';
GRANT EXECUTE ON PROCEDURE UniversityProject1DB.ChangeRegistrationStatus TO 'p1_registrar'@'localhost';
GRANT EXECUTE ON PROCEDURE UniversityProject1DB.SetFinalMark TO 'p1_registrar'@'localhost';
GRANT EXECUTE ON PROCEDURE UniversityProject1DB.CompleteRegistration TO 'p1_registrar'@'localhost';
GRANT EXECUTE ON PROCEDURE UniversityProject1DB.GetSectionPerformanceReport TO 'p1_registrar'@'localhost';

-- Registration Officer: manage students, phones, controlled registration operations.
-- No direct mark UPDATE and no EXECUTE on either mark procedure.
GRANT SELECT ON UniversityProject1DB.Department TO 'p1_officer'@'localhost';
GRANT SELECT ON UniversityProject1DB.Instructor TO 'p1_officer'@'localhost';
GRANT SELECT ON UniversityProject1DB.Course TO 'p1_officer'@'localhost';
GRANT SELECT ON UniversityProject1DB.Section TO 'p1_officer'@'localhost';
GRANT SELECT,INSERT,UPDATE ON UniversityProject1DB.Student TO 'p1_officer'@'localhost';
GRANT SELECT,INSERT,UPDATE,DELETE ON UniversityProject1DB.StudentPhone TO 'p1_officer'@'localhost';
GRANT SELECT ON UniversityProject1DB.Registration TO 'p1_officer'@'localhost';
GRANT SELECT ON UniversityProject1DB.v_StudentDirectory TO 'p1_officer'@'localhost';
GRANT SELECT ON UniversityProject1DB.v_RegistrationDetails TO 'p1_officer'@'localhost';
GRANT SELECT ON UniversityProject1DB.v_SectionCapacity TO 'p1_officer'@'localhost';
GRANT EXECUTE ON PROCEDURE UniversityProject1DB.RegisterStudent TO 'p1_officer'@'localhost';
GRANT EXECUTE ON PROCEDURE UniversityProject1DB.ChangeRegistrationStatus TO 'p1_officer'@'localhost';

-- Report account: only approved read-only views and one report procedure.
GRANT SELECT ON UniversityProject1DB.v_RegistrationDetails TO 'p1_report'@'localhost';
GRANT SELECT ON UniversityProject1DB.v_SectionCapacity TO 'p1_report'@'localhost';
GRANT EXECUTE ON PROCEDURE UniversityProject1DB.GetSectionPerformanceReport TO 'p1_report'@'localhost';

SHOW GRANTS FOR 'p1_registrar'@'localhost';
SHOW GRANTS FOR 'p1_officer'@'localhost';
SHOW GRANTS FOR 'p1_report'@'localhost';

-- BCS 306 PROJECT 1 | Examples of labs 4-10 and the advanced report.
USE UniversityProject1DB;

-- Student query: SELECT, JOIN, derived age, ORDER BY.
SELECT StudentID,StudentName,Age,DeptName,StudentStatus
FROM v_StudentDirectory ORDER BY DeptName,StudentName;

-- More than one phone number (GROUP BY / HAVING).
SELECT s.StudentID,CONCAT(s.FirstName,' ',s.FamilyName) AS StudentName,
       COUNT(p.PhoneNumber) AS PhoneCount
FROM Student s JOIN StudentPhone p ON s.StudentID=p.StudentID
GROUP BY s.StudentID,s.FirstName,s.FamilyName HAVING COUNT(p.PhoneNumber)>1;

-- Course prerequisites (recursive relationship, self join).
SELECT p.CourseCode,c.CourseTitle,p.PrerequisiteCourseCode,
       required.CourseTitle AS PrerequisiteTitle
FROM CoursePrerequisite p JOIN Course c ON p.CourseCode=c.CourseCode
JOIN Course required ON p.PrerequisiteCourseCode=required.CourseCode;

-- Section capacity: reusable view.
SELECT * FROM v_SectionCapacity WHERE Semester='Fall' AND AcademicYear=2026
ORDER BY CourseCode,SectionNo;

-- Registration details reusable view.
SELECT * FROM v_RegistrationDetails
WHERE Semester='Fall' AND AcademicYear=2026 ORDER BY RegistrationID;

-- Subquery: students with at least one completed mark above the global average.
SELECT DISTINCT s.StudentID,s.FirstName,s.FamilyName
FROM Student s JOIN Registration r ON s.StudentID=r.StudentID
WHERE r.RegistrationStatus='Completed'
  AND r.FinalMark > (SELECT AVG(FinalMark) FROM Registration
                     WHERE RegistrationStatus='Completed' AND FinalMark IS NOT NULL);

-- Advanced report exactly as requested; returns qualifying sections for Fall 2026.
CALL GetSectionPerformanceReport('Fall',2026);
