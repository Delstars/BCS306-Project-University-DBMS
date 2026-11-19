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
BEGIN
    DECLARE v_capacity INT DEFAULT NULL;
    DECLARE v_active INT DEFAULT 0;
    DECLARE v_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;
    START TRANSACTION;
    -- Lock the section before any regular SELECT establishes a read snapshot.
    -- Otherwise a competing registration could commit while this call waits.
    SELECT MaximumCapacity INTO v_capacity FROM Section
      WHERE CourseCode=p_course AND SectionNo=p_section
        AND Semester=p_semester AND AcademicYear=p_year FOR UPDATE;
    IF v_capacity IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Section does not exist';
    END IF;
    SELECT COUNT(*) INTO v_exists FROM Student WHERE StudentID=p_student;
    IF v_exists=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Student does not exist';
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
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;
    IF p_status NOT IN ('Registered','Dropped') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use CompleteRegistration to set Completed';
    END IF;
    START TRANSACTION;
    -- UPDATE invokes the capacity-checking trigger first; there is no
    -- earlier ordinary SELECT that could establish a stale snapshot.
    UPDATE Registration SET RegistrationStatus=p_status WHERE RegistrationID=p_id;
    SELECT COUNT(*) INTO v_exists FROM Registration WHERE RegistrationID=p_id;
    IF v_exists=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registration not found';
    END IF;
    COMMIT;
END//

CREATE PROCEDURE SetFinalMark(IN p_id INT,IN p_mark DECIMAL(5,2))
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    IF p_mark IS NULL OR p_mark<0 OR p_mark>100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Final mark must be between 0 and 100';
    END IF;
    SELECT COUNT(*) INTO v_exists FROM Registration
    WHERE RegistrationID=p_id AND RegistrationStatus<>'Dropped';
    IF v_exists=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registration not found or is dropped';
    END IF;
    UPDATE Registration SET FinalMark=p_mark WHERE RegistrationID=p_id;
END//

CREATE PROCEDURE CompleteRegistration(IN p_id INT,IN p_mark DECIMAL(5,2))
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;
    IF p_mark IS NULL OR p_mark<0 OR p_mark>100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Final mark must be between 0 and 100';
    END IF;
    START TRANSACTION;
    SELECT COUNT(*) INTO v_exists FROM Registration
    WHERE RegistrationID=p_id AND RegistrationStatus<>'Dropped';
    IF v_exists=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registration not found or is dropped';
    END IF;
    UPDATE Registration SET RegistrationStatus='Completed',FinalMark=p_mark
      WHERE RegistrationID=p_id;
    COMMIT;
END//

-- Lab 6 scalar/correlated subqueries, Lab 5 aggregates, Lab 6 JOIN.
-- Uses only joins, comparison subqueries, COUNT/AVG/MIN/MAX/ROUND.
CREATE PROCEDURE GetSectionPerformanceReport(IN p_semester VARCHAR(15),IN p_year INT)
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
