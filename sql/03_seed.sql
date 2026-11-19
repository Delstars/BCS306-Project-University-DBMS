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
