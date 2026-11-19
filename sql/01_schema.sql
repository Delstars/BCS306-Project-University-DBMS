-- BCS 306 PROJECT 1 | Execute using a local administrator in MySQL Workbench.
-- WARNING: This script RESETS ONLY the dedicated UniversityProject1DB database.
-- Do not run against an existing database containing work you need to keep.
DROP DATABASE IF EXISTS UniversityProject1DB;
CREATE DATABASE UniversityProject1DB CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE UniversityProject1DB;

-- ChairID FK is added after initial data is loaded because of the circular
-- relationship: Department has a chair, and Instructor belongs to Department.
CREATE TABLE Department (
    DeptCode VARCHAR(10) PRIMARY KEY,
    DeptName VARCHAR(100) NOT NULL UNIQUE,
    Office VARCHAR(30) NOT NULL,
    ChairID INT UNIQUE
) ENGINE=InnoDB;

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
) ENGINE=InnoDB;

CREATE TABLE Student (
    StudentID INT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    MiddleName VARCHAR(50),
    FamilyName VARCHAR(50) NOT NULL,
    DateOfBirth DATE NOT NULL,
    Email VARCHAR(120) NOT NULL UNIQUE,
    AdmissionYear SMALLINT NOT NULL,
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
) ENGINE=InnoDB;

CREATE TABLE StudentPhone (
    StudentID INT NOT NULL,
    PhoneNumber VARCHAR(20) NOT NULL,
    CONSTRAINT PK_StudentPhone PRIMARY KEY (StudentID, PhoneNumber),
    CONSTRAINT FK_StudentPhone_Student FOREIGN KEY (StudentID)
        REFERENCES Student(StudentID) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Course (
    CourseCode VARCHAR(10) PRIMARY KEY,
    CourseTitle VARCHAR(150) NOT NULL,
    Credits TINYINT NOT NULL,
    AcademicLevel TINYINT NOT NULL,
    CourseStatus VARCHAR(20) NOT NULL DEFAULT 'Active',
    DeptCode VARCHAR(10) NOT NULL,
    CONSTRAINT CHK_Course_Credits CHECK (Credits BETWEEN 1 AND 6),
    CONSTRAINT CHK_Course_Level CHECK (AcademicLevel BETWEEN 1 AND 8),
    CONSTRAINT CHK_Course_Status CHECK (CourseStatus IN ('Active', 'Inactive')),
    CONSTRAINT FK_Course_Department FOREIGN KEY (DeptCode)
        REFERENCES Department(DeptCode) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE CoursePrerequisite (
    CourseCode VARCHAR(10) NOT NULL,
    PrerequisiteCourseCode VARCHAR(10) NOT NULL,
    CONSTRAINT PK_CoursePrerequisite PRIMARY KEY (CourseCode, PrerequisiteCourseCode),
    CONSTRAINT FK_Prereq_Course FOREIGN KEY (CourseCode)
        REFERENCES Course(CourseCode) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_Prereq_Required FOREIGN KEY (PrerequisiteCourseCode)
        REFERENCES Course(CourseCode) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Section (
    CourseCode VARCHAR(10) NOT NULL,
    SectionNo VARCHAR(5) NOT NULL,
    Semester VARCHAR(15) NOT NULL,
    AcademicYear SMALLINT NOT NULL,
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
) ENGINE=InnoDB;

-- MeetingNo is meaningful only within its parent Section (weak entity).
CREATE TABLE SectionMeeting (
    CourseCode VARCHAR(10) NOT NULL,
    SectionNo VARCHAR(5) NOT NULL,
    Semester VARCHAR(15) NOT NULL,
    AcademicYear SMALLINT NOT NULL,
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
) ENGINE=InnoDB;

CREATE TABLE Registration (
    RegistrationID INT AUTO_INCREMENT PRIMARY KEY,
    StudentID INT NOT NULL,
    CourseCode VARCHAR(10) NOT NULL,
    SectionNo VARCHAR(5) NOT NULL,
    Semester VARCHAR(15) NOT NULL,
    AcademicYear SMALLINT NOT NULL,
    RegistrationDate DATE NOT NULL DEFAULT (CURRENT_DATE),
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
) ENGINE=InnoDB;

-- Keep a historical snapshot; intentionally NO FK to Registration, since
-- registration deletion must not delete its audit history.
CREATE TABLE RegistrationAudit (
    AuditID BIGINT AUTO_INCREMENT PRIMARY KEY,
    RegistrationID INT NOT NULL,
    StudentID INT NOT NULL,
    CourseCode VARCHAR(10) NOT NULL,
    SectionNo VARCHAR(5) NOT NULL,
    Semester VARCHAR(15) NOT NULL,
    AcademicYear SMALLINT NOT NULL,
    EventType VARCHAR(40) NOT NULL,
    OldStatus VARCHAR(20),
    NewStatus VARCHAR(20),
    OldFinalMark DECIMAL(5,2),
    NewFinalMark DECIMAL(5,2),
    DatabaseUser VARCHAR(288) NOT NULL,
    EventTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_Audit_Event CHECK (EventType IN (
        'REGISTRATION_CREATED', 'REGISTRATION_STATUS_CHANGED',
        'FINAL_MARK_CHANGED', 'REGISTRATION_DELETED'))
) ENGINE=InnoDB;

SHOW TABLES;
