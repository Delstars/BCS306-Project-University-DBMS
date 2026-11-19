-- BCS 306 PROJECT 1 | Tests to run individually in Workbench.
-- Use the appropriate MySQL accounts. Changes below are commented out.
USE UniversityProject1DB;

-- BASELINE CHECKS (safe)
SELECT COUNT(*) AS TotalRegistrations FROM Registration;
SELECT EventType, COUNT(*) AS Events FROM RegistrationAudit GROUP BY EventType;
SELECT * FROM v_SectionCapacity ORDER BY CourseCode, SectionNo;
CALL GetSectionPerformanceReport('Fall',2026);

-- POSITIVE TEST (run as p1_officer or p1_registrar)
-- CALL RegisterStudent(107,'BCS306','02','Fall',2026);
-- SELECT * FROM v_RegistrationDetails WHERE StudentID=107;

-- NEGATIVE: duplicate registration
-- CALL RegisterStudent(101,'BCS306','01','Fall',2026);
-- NEGATIVE: nonexistent section
-- CALL RegisterStudent(101,'BCS306','99','Fall',2026);
-- NEGATIVE: invalid mark
-- CALL SetFinalMark(1001,120);
-- NEGATIVE: officer must NOT update marks directly
-- UPDATE Registration SET FinalMark=90 WHERE RegistrationID=1001;
-- NEGATIVE: report account cannot insert students
-- INSERT INTO Student (StudentID,FirstName,FamilyName,DateOfBirth,Email,
--     AdmissionYear,StudentStatus,DeptCode)
-- VALUES (999,'Test','User','2005-01-01','test999@uni.edu',2026,'Active','CS');

-- SENSITIVE-CHANGE AUDIT TESTS (registrar)
-- CALL SetFinalMark(1001,89);
-- CALL ChangeRegistrationStatus(1002,'Dropped');
-- CALL CompleteRegistration(1002,85); -- should fail while dropped
-- CALL ChangeRegistrationStatus(1002,'Registered');
-- CALL CompleteRegistration(1002,85);
-- SELECT * FROM RegistrationAudit ORDER BY AuditID DESC LIMIT 15;

-- DELETE AUDIT TEST (registrar; changes baseline)
-- DELETE FROM Registration WHERE RegistrationID=1014;
-- SELECT * FROM RegistrationAudit WHERE RegistrationID=1014 ORDER BY AuditID DESC;

-- TRANSACTION ROLLBACK TEST
-- START TRANSACTION;
-- UPDATE Student SET StudentStatus='Inactive' WHERE StudentID=101;
-- SELECT StudentID,StudentStatus FROM Student WHERE StudentID=101;
-- ROLLBACK;
-- SELECT StudentID,StudentStatus FROM Student WHERE StudentID=101;
