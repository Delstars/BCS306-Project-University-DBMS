-- BCS 306 PROJECT 1 | Rules, audit triggers, views, and procedures.
-- Run after 01_schema.sql and BEFORE 03_seed.sql (seed events are audited).
USE UniversityProject1DB;

DELIMITER //
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
        EventType,NewStatus,NewFinalMark,DatabaseUser)
    VALUES (NEW.RegistrationID,NEW.StudentID,NEW.CourseCode,NEW.SectionNo,
        NEW.Semester,NEW.AcademicYear,'REGISTRATION_CREATED',
        NEW.RegistrationStatus,NEW.FinalMark,USER());
END//

CREATE TRIGGER trg_registration_after_update
AFTER UPDATE ON Registration FOR EACH ROW
BEGIN
    IF NOT(OLD.RegistrationStatus <=> NEW.RegistrationStatus) THEN
        INSERT INTO RegistrationAudit
          (RegistrationID,StudentID,CourseCode,SectionNo,Semester,AcademicYear,
           EventType,OldStatus,NewStatus,OldFinalMark,NewFinalMark,DatabaseUser)
        VALUES (NEW.RegistrationID,NEW.StudentID,NEW.CourseCode,NEW.SectionNo,
          NEW.Semester,NEW.AcademicYear,'REGISTRATION_STATUS_CHANGED',
          OLD.RegistrationStatus,NEW.RegistrationStatus,OLD.FinalMark,NEW.FinalMark,USER());
    END IF;
    IF NOT(OLD.FinalMark <=> NEW.FinalMark) THEN
        INSERT INTO RegistrationAudit
          (RegistrationID,StudentID,CourseCode,SectionNo,Semester,AcademicYear,
           EventType,OldStatus,NewStatus,OldFinalMark,NewFinalMark,DatabaseUser)
        VALUES (NEW.RegistrationID,NEW.StudentID,NEW.CourseCode,NEW.SectionNo,
          NEW.Semester,NEW.AcademicYear,'FINAL_MARK_CHANGED',
          OLD.RegistrationStatus,NEW.RegistrationStatus,OLD.FinalMark,NEW.FinalMark,USER());
    END IF;
END//

CREATE TRIGGER trg_registration_after_delete
AFTER DELETE ON Registration FOR EACH ROW
BEGIN
    INSERT INTO RegistrationAudit
      (RegistrationID,StudentID,CourseCode,SectionNo,Semester,AcademicYear,
       EventType,OldStatus,OldFinalMark,DatabaseUser)
    VALUES (OLD.RegistrationID,OLD.StudentID,OLD.CourseCode,OLD.SectionNo,
       OLD.Semester,OLD.AcademicYear,'REGISTRATION_DELETED',
       OLD.RegistrationStatus,OLD.FinalMark,USER());
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
SELECT s.StudentID, CONCAT_WS(' ',s.FirstName,s.MiddleName,s.FamilyName) AS StudentName,
       TIMESTAMPDIFF(YEAR,s.DateOfBirth,CURDATE()) AS Age,
       s.Email,s.StudentStatus,s.AdmissionYear,s.DeptCode,d.DeptName,
       s.AdvisorID
FROM Student s JOIN Department d ON s.DeptCode=d.DeptCode;

CREATE VIEW v_RegistrationDetails AS
SELECT r.RegistrationID,r.StudentID,
       CONCAT_WS(' ',st.FirstName,st.MiddleName,st.FamilyName) AS StudentName,
       d.DeptName AS DepartmentName,
       r.CourseCode,c.CourseTitle,r.SectionNo,r.Semester,r.AcademicYear,
       CONCAT_WS(' ',i.FirstName,i.MiddleName,i.FamilyName) AS InstructorName,
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
       SUM(CASE WHEN r.RegistrationStatus='Registered' THEN 1 ELSE 0 END) AS ActiveEnrollment,
       sec.MaximumCapacity-SUM(CASE WHEN r.RegistrationStatus='Registered' THEN 1 ELSE 0 END) AS RemainingSeats
FROM Section sec JOIN Course c ON sec.CourseCode=c.CourseCode
LEFT JOIN Registration r ON sec.CourseCode=r.CourseCode AND sec.SectionNo=r.SectionNo
    AND sec.Semester=r.Semester AND sec.AcademicYear=r.AcademicYear
GROUP BY sec.CourseCode,c.CourseTitle,sec.SectionNo,sec.Semester,sec.AcademicYear,sec.MaximumCapacity;

DELIMITER //
CREATE PROCEDURE RegisterStudent(
    IN p_student INT, IN p_course VARCHAR(10), IN p_section VARCHAR(5),
    IN p_semester VARCHAR(15), IN p_year SMALLINT
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
    SELECT LAST_INSERT_ID() AS NewRegistrationID;
END//

CREATE PROCEDURE ChangeRegistrationStatus(IN p_id INT,IN p_status VARCHAR(20))
SQL SECURITY DEFINER
BEGIN
    IF p_status NOT IN ('Registered','Dropped') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use CompleteRegistration to set Completed';
    END IF;
    UPDATE Registration SET RegistrationStatus=p_status WHERE RegistrationID=p_id;
    IF ROW_COUNT()=0 THEN
        -- ROW_COUNT can be zero if the value is unchanged; check existence.
        IF NOT EXISTS(SELECT 1 FROM Registration WHERE RegistrationID=p_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registration not found';
        END IF;
    END IF;
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

CREATE PROCEDURE GetSectionPerformanceReport(IN p_semester VARCHAR(15),IN p_year SMALLINT)
SQL SECURITY DEFINER
BEGIN
    WITH SectionStats AS (
        SELECT sec.CourseCode,c.CourseTitle,d.DeptName AS DepartmentName,
               sec.SectionNo,sec.Semester,sec.AcademicYear,
               CONCAT_WS(' ',i.FirstName,i.MiddleName,i.FamilyName) AS InstructorName,
               sec.MaximumCapacity,
               SUM(CASE WHEN r.RegistrationStatus='Registered' THEN 1 ELSE 0 END) AS ActiveEnrollment,
               sec.MaximumCapacity-SUM(CASE WHEN r.RegistrationStatus='Registered' THEN 1 ELSE 0 END) AS RemainingSeats,
               ROUND(AVG(CASE WHEN r.RegistrationStatus='Completed' THEN r.FinalMark END),2) AS AverageCompletedMark,
               MAX(CASE WHEN r.RegistrationStatus='Completed' THEN r.FinalMark END) AS HighestFinalMark,
               MIN(CASE WHEN r.RegistrationStatus='Completed' THEN r.FinalMark END) AS LowestFinalMark,
               SUM(CASE WHEN r.RegistrationStatus='Completed' AND r.FinalMark<60 THEN 1 ELSE 0 END) AS Below60Count
        FROM Section sec JOIN Course c ON sec.CourseCode=c.CourseCode
        JOIN Department d ON c.DeptCode=d.DeptCode
        JOIN Instructor i ON sec.InstructorID=i.InstructorID
        LEFT JOIN Registration r ON sec.CourseCode=r.CourseCode AND sec.SectionNo=r.SectionNo
            AND sec.Semester=r.Semester AND sec.AcademicYear=r.AcademicYear
        WHERE sec.Semester=p_semester AND sec.AcademicYear=p_year
        GROUP BY sec.CourseCode,c.CourseTitle,d.DeptName,sec.SectionNo,sec.Semester,
             sec.AcademicYear,i.FirstName,i.MiddleName,i.FamilyName,sec.MaximumCapacity
    ), Benchmarks AS (
        SELECT (SELECT AVG(ActiveEnrollment) FROM SectionStats) AS AvgActiveEnrollment,
               (SELECT AVG(FinalMark) FROM Registration
                  WHERE Semester=p_semester AND AcademicYear=p_year
                    AND RegistrationStatus='Completed' AND FinalMark IS NOT NULL) AS AvgCompletedMark
    )
    SELECT s.CourseCode,s.CourseTitle,s.DepartmentName,s.SectionNo,s.InstructorName,
           s.MaximumCapacity,s.ActiveEnrollment,s.RemainingSeats,
           s.AverageCompletedMark,s.HighestFinalMark,s.LowestFinalMark,s.Below60Count
    FROM SectionStats s CROSS JOIN Benchmarks b
    WHERE s.ActiveEnrollment>b.AvgActiveEnrollment
       OR (s.AverageCompletedMark IS NOT NULL AND s.AverageCompletedMark<b.AvgCompletedMark)
    ORDER BY s.ActiveEnrollment DESC,s.AverageCompletedMark ASC;
END//
DELIMITER ;
