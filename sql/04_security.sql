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
