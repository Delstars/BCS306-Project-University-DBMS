-- BCS306 Project 1 | Baseline checks to run immediately after setup.
USE UniversityProject1DB;
DROP PROCEDURE IF EXISTS AssertProjectBaseline;
DELIMITER //
CREATE PROCEDURE AssertProjectBaseline()
BEGIN
    IF (SELECT COUNT(*) FROM Department)<>4 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Department count mismatch';
    END IF;
    IF (SELECT COUNT(*) FROM Instructor)<>5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Instructor count mismatch';
    END IF;
    IF (SELECT COUNT(*) FROM Student)<>8 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Student count mismatch';
    END IF;
    IF (SELECT COUNT(*) FROM StudentPhone)<>9 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='StudentPhone count mismatch';
    END IF;
    IF (SELECT COUNT(*) FROM Course)<>8 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Course count mismatch (includes supporting BCS210)';
    END IF;
    IF (SELECT COUNT(*) FROM CoursePrerequisite)<>4 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Prerequisite count mismatch';
    END IF;
    IF (SELECT COUNT(*) FROM Section)<>6 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Section count mismatch';
    END IF;
    IF (SELECT COUNT(*) FROM SectionMeeting)<>8 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='SectionMeeting count mismatch';
    END IF;
    IF (SELECT COUNT(*) FROM Registration)<>8 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registration count mismatch';
    END IF;
    IF (SELECT COUNT(*) FROM RegistrationAudit WHERE EventType='REGISTRATION_CREATED')<>8 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registration audit count mismatch';
    END IF;
    IF (SELECT COUNT(*) FROM Registration WHERE RegistrationID=1002
        AND RegistrationStatus='Registered' AND FinalMark IS NULL)<>1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Professor registration 1002 does not match';
    END IF;
    IF (SELECT COUNT(*) FROM Department d JOIN Instructor i
        ON d.ChairID=i.InstructorID AND d.DeptCode=i.DeptCode)<>4 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Chair/department relationship mismatch';
    END IF;
END//
DELIMITER ;
CALL AssertProjectBaseline();
DROP PROCEDURE AssertProjectBaseline;
SELECT 'PASS: all baseline assertions returned without error' AS BaselineCheck;
