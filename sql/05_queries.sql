-- BCS 306 PROJECT 1 | Examples of labs 4-10 and the advanced report.
USE UniversityProject1DB;

-- Student query: SELECT, JOIN, derived age, ORDER BY.
SELECT StudentID,StudentName,Age,DeptName,StudentStatus
FROM v_StudentDirectory ORDER BY DeptName,StudentName;

-- More than one phone number (GROUP BY / HAVING).
SELECT s.StudentID,CONCAT_WS(' ',s.FirstName,s.FamilyName) AS StudentName,
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
