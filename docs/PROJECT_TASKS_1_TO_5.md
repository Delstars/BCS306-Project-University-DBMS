# BCS 306 — Project 1 Technical Analysis and Documentation

**Project scenario:** University Course Registration, Academic Records, and Reporting System  
**Technology:** MySQL 8.0, MySQL Workbench, Python 3, `mysql-connector-python`, Tkinter  
**Scope:** Tasks 1–5 from the supplied Project 1 brief. This document is an implementation-based draft; add group names, **real test screenshots**, actual result captures, and conclusions based on running your system before submission.

## Task 1 — Database Modeling Analysis and Written Communication (5 marks)

### Entities and strengths

| Entity | Role | Key and dependency |
|---|---|---|
| Department | Strong | `DeptCode` identifies an academic department. |
| Instructor | Strong | `InstructorID` is the unique identifier; each instructor belongs to a department. |
| Student | Strong | `StudentID` identifies the student; each student belongs to one department. |
| Course | Strong | `CourseCode` identifies a course. |
| StudentPhone | Existence-dependent | Has no meaning without its Student. Composite key `(StudentID, PhoneNumber)`; implements a multivalued attribute. |
| CoursePrerequisite | Associative / recursive | Composite key `(CourseCode, PrerequisiteCourseCode)` associates two roles of the Course entity. |
| Section | Existence-dependent | SectionNo alone is not unique. Composite identifying key `(CourseCode, SectionNo, Semester, AcademicYear)`. |
| SectionMeeting | Weak / existence-dependent | `MeetingNo` is only meaningful inside a section. Key is the full Section key plus MeetingNo. |
| Registration | Associative relationship with attributes | `RegistrationID` is a surrogate PK, and unique `(StudentID, Section composite key)` prevents repeated student/section pairings. RegistrationDate, status and FinalMark describe the relationship. |
| RegistrationAudit | Historical / event entity | `AuditID` is an independent PK; keeps snapshots even after a registration is removed. |

### Attribute classification

- **Simple:** DeptCode, DeptName, Email, AdmissionYear, MaximumCapacity, FinalMark, and Room.
- **Composite:** Instructor and student FullName decomposes into FirstName, MiddleName, FamilyName. Student postal address decomposes into Street, City, Emirate, PostalCode.
- **Multivalued:** Student telephone numbers; modeled as StudentPhone, not comma-separated values in Student.
- **Derived:** Age is calculated from DateOfBirth with `TIMESTAMPDIFF(YEAR, DateOfBirth, CURDATE())` in `v_StudentDirectory`. RemainingSeats is calculated from MaximumCapacity minus active registrations in `v_SectionCapacity`.
- **Keys:** DeptCode, InstructorID, StudentID, CourseCode, RegistrationID, and AuditID are simple primary keys. Section and SectionMeeting use composite primary keys.
- **Optional attributes:** MiddleName, AdvisorID, FinalMark until assessment is completed, address fields, and OfficeExtension (not provided in baseline).

### Relationship degrees, cardinalities, and participation

| Relationship | Degree | Cardinality | Participation / rule |
|---|---|---|---|
| Department–Instructor employs | Binary | One to many | Instructor must belong to exactly one department; department can employ many. |
| Department–Instructor chair | Binary | One-to-one | Every department has one chair, each instructor chairs at most one. Chair must be an instructor **within that department**. |
| Department–Student | Binary | One to many | Student belongs to exactly one department. |
| Instructor–Student advises | Binary | One to many | Advisor is optional for students; advisor must exist in Instructor. |
| Department–Course | Binary | One to many | Every course is offered by one department. |
| Course–Course prerequisite | Recursive binary | Many to many | A course may require several other courses and itself may be required by others. A self-reference is disallowed. |
| Course–Section | Binary / identifying | One to many | Section depends on the course and its section/term identity. |
| Instructor–Section teaches | Binary | One to many | Every section has one responsible instructor. |
| Section–SectionMeeting | Binary / identifying | One to many | A meeting cannot exist without its Section. |
| Student–Section registration | M:N relationship via Registration | Many to many | Registration stores RegistrationDate, RegistrationStatus, FinalMark. One student can register in many sections; a section has many students. No duplicate student-section pair. |
| Registration–Audit | Historical association | One to many | Audit snapshots are retained without a formal foreign key to support deleted registrations. |

The scenario contains **binary**, **recursive**, **identifying**, and **associative** relationships. The composite section identifier is necessary because Section 01 appears multiple times with different courses and terms. Participation is enforced using `NOT NULL` for mandatory references and nullable `AdvisorID` for optional advising.

![Relational ERD](ERD.png)

*Figure 1 — Project 1 relational ERD. Blue: principal entities; yellow: existence-dependent/associative structures; green: Registration; pink: historical audit.*

## Task 2 — Database Schema Design, Conversion and 3NF (4 marks)

### Relational schema

**Notation:** `PK(...)`, `FK(Column → Parent.Column)`, and `UQ(...)` are implemented in `sql/01_schema.sql`.

```text
DEPARTMENT(DeptCode PK, DeptName UQ, Office, ChairID UQ NOT NULL)
INSTRUCTOR(InstructorID PK, FirstName, MiddleName, FamilyName,
           Email UQ, Specialization, OfficeExtension, DeptCode FK)
STUDENT(StudentID PK, FirstName, MiddleName, FamilyName, DateOfBirth,
        Email UQ, AdmissionYear, StudentStatus, Street, City, Emirate,
        PostalCode, DeptCode FK, AdvisorID FK NULL)
STUDENTPHONE(StudentID FK, PhoneNumber, PK(StudentID, PhoneNumber))
COURSE(CourseCode PK, CourseTitle, Credits, AcademicLevel, CourseStatus, DeptCode FK)
COURSEPREREQUISITE(CourseCode FK, PrerequisiteCourseCode FK,
                   PK(CourseCode, PrerequisiteCourseCode))
SECTION(CourseCode FK, SectionNo, Semester, AcademicYear,
        MaximumCapacity, Classroom, DeliveryMode, InstructorID FK,
        PK(CourseCode, SectionNo, Semester, AcademicYear))
SECTIONMEETING(CourseCode FK, SectionNo, Semester, AcademicYear,
               MeetingNo, DayOfWeek, StartTime, EndTime, Room,
               PK(CourseCode, SectionNo, Semester, AcademicYear, MeetingNo))
REGISTRATION(RegistrationID PK, StudentID FK, CourseCode FK,
             SectionNo, Semester, AcademicYear, RegistrationDate,
             RegistrationStatus, FinalMark,
             UQ(StudentID, CourseCode, SectionNo, Semester, AcademicYear))
REGISTRATIONAUDIT(AuditID PK, RegistrationID snapshot, StudentID snapshot,
                  section snapshots, EventType, OldStatus, NewStatus,
                  OldFinalMark, NewFinalMark, DatabaseUser, EventTime)
```

**Special constraint:** `Department(ChairID, DeptCode) → Instructor(InstructorID, DeptCode)` verifies that the department's chair is a member of that department. `ChairID` is `UNIQUE NOT NULL` to satisfy 1:1 cardinality. The FK is added after populating the circular Department/Instructor references.

### Normalization explanation

**1NF:** All fields are atomic. The repeating collection of student phone numbers is separated into StudentPhone; section meetings receive their own rows. Composite student names and postal addresses are represented by individual scalar columns.

**2NF:** Non-key attributes depend on the *whole* key in relations with composite keys. For Section, MaximumCapacity, Classroom and DeliveryMode depend on `(CourseCode, SectionNo, Semester, AcademicYear)`, not just `SectionNo`. For SectionMeeting, DayOfWeek, StartTime, EndTime and Room depend on the entire section key plus `MeetingNo`.

**3NF:** Attributes such as DeptName appear in Department, not duplicated in Student and Course; CourseTitle appears in Course, not repeated in each Section or Registration; student/instructor names are stored in their base tables and combined through joins. Derived age and remaining seats are calculated via views. Thus non-key data does not redundantly depend on other non-key attributes within operational relations. RegistrationAudit intentionally stores historical snapshots because auditing requires immutable past values, not the current state of parent records.

Functional dependency examples: `StudentID → FirstName, MiddleName, FamilyName, DateOfBirth, Email, ...`; `CourseCode → CourseTitle, Credits, AcademicLevel, CourseStatus, DeptCode`; `Section composite key → MaximumCapacity, Classroom, DeliveryMode, InstructorID`; `(Section key, MeetingNo) → DayOfWeek, StartTime, EndTime, Room`.

**Referential actions:** Phone and SectionMeeting rows cascade-delete with their parent. An advisor becoming unavailable sets Student.AdvisorID to NULL. Deleting a course, student, or section with active dependent registrations is restricted. Department and instructor references use restricted deletion; the chair's same-department rule is enforced in MySQL.

## Task 3 — Database and Application Implementation (6 marks)

### Schema / integrity

`01_schema.sql` defines the 10 principal tables. Mandatory fields, primary and foreign keys, unique email constraints, positive capacity, legal semester/mode/status values, `FinalMark` 0–100, and the composite Section identity are handled by MySQL rather than relying on Tkinter.

### Transactions and stored procedures

`RegisterStudent(StudentID, CourseCode, SectionNo, Semester, AcademicYear)` starts a transaction, verifies the student and section, obtains a **row lock on Section** using `FOR UPDATE`, checks for duplicate registration and capacity, inserts the registration, commits on success, and rolls back on a SQL exception. `trg_registration_before_insert` duplicates essential database-side safety checks for direct SQL insertion. `ChangeRegistrationStatus`, `SetFinalMark`, and `CompleteRegistration` implement other controlled mutations. `CompleteRegistration` changes status and mark atomically. `GetSectionPerformanceReport` generates the advanced report for parameters supplied by the GUI.

### Triggers and audit events

| Event | SQL trigger |
|---|---|
| `REGISTRATION_CREATED` | `trg_registration_after_insert` |
| `REGISTRATION_STATUS_CHANGED` | `trg_registration_after_update` (conditional) |
| `FINAL_MARK_CHANGED` | `trg_registration_after_update` (NULL-safe comparison) |
| `REGISTRATION_DELETED` | `trg_registration_after_delete` |

The two validation triggers prevent illegal registration creation and invalid status reactivation. A separate Section trigger rejects reducing MaximumCapacity below existing active enrollment. A database user is recorded with `USER()`, while `OLD` and `NEW` preserve sensitive prior/current values. The audit table cannot be edited by the three application users.

### Views

- `v_StudentDirectory` — names, department, and dynamically calculated age.
- `v_RegistrationDetails` — joins student, department, registration, course, section and instructor for operations.
- `v_SectionCapacity` — maximum capacity, active registrations, and remaining seats.

### Users and privilege enforcement

The database has three MySQL accounts for demonstration. Registrar has operational SELECT/INSERT/UPDATE/DELETE rights on relevant tables and access to marks/audit/report. Officer has controlled student operations and EXECUTE on registration/status procedures but **no permission to update FinalMark**. Report User can only read two approved views and EXECUTE the report procedure. No application account has DDL privileges or audit rewrite access.

### Desktop application

`app/main.py` starts with a MySQL username/password login, creates a connection using the submitted credentials, and shows only menu actions relevant to each MySQL role. It uses simple function-based Tkinter forms, Label/Entry/Button/Text widgets, parameterized `cursor.execute(sql, params)` queries, `cursor.callproc`, error dialogs, and commit/rollback consistent with Lab 10. `tk.Text` and `tk.Frame` are standard display/container widgets added to show larger result sets. Student maintenance, student phone entries, capacity browsing, section creation, enrollment, controlled status changes, mark entry/completion, audit viewing, and advanced reporting are available as authorized.

### Advanced Academic Section Performance and Capacity Report

For **a selected Semester and AcademicYear**, the report returns per section CourseCode, CourseTitle, DepartmentName, SectionNo, InstructorName, MaximumCapacity, active count, remaining seats, mean completed final mark, high/low marks, and number below 60. It filters using:

`ActiveEnrollment > average active enrollment for all sections in the selected term` **OR** `AverageCompletedMark < overall mean of completed final marks for the selected term`.

It sorts active enrollment **descending**, then average completed mark **ascending**, using Lab 5 aggregates and Lab 6 scalar subqueries instead of CTEs. A section without completed marks has NULL mean and cannot qualify through the mark condition alone.

**Expected baseline, calculated from the instructor dataset (not actual MySQL evidence):**

| CourseCode | SectionNo | Active | Capacity | Avg completed mark | Below 60 | Reason included |
|---|---:|---:|---:|---:|---:|---|
| BCS301 | 01 | 1 | 9 | NULL | 0 | Above average active count (1 vs 0.167) |
| CYS321 | 01 | 0 | 8 | 52 | 1 | Below overall completed average (77.29) |
| BCS221 | 01 | 0 | 10 | 74 | 0 | Below overall completed average (77.29) |

The baseline overall completed-mark mean is approximately **77.29** (seven completed records); the mean active enrollment across six sections is about **0.167**. The actual output must be captured by running `CALL GetSectionPerformanceReport('Fall',2026);` in MySQL Workbench and the GUI.

## Task 4 — Evaluation and Demonstration (5 marks)

### Test plan / expected outcomes — pending actual MySQL execution

| Test | Action | Expected database behavior | Evidence to capture |
|---|---|---|---|
| Valid login | Login as p1_officer with correct password | Success; allowed tabs displayed | Login and tabs screenshot |
| Wrong password | Invalid MySQL password | MySQL access denied | Error dialog screenshot |
| Valid registration | Register student 107 in BCS306 section 02 | New registration and creation audit; capacity decrements by 1 | Registration view and audit |
| Duplicate registration | Register student 101 in BCS306 section 01 | SQLSTATE 45000; unchanged rows | DBMS rejection |
| Unknown section | Register BCS306 section 99 | SQLSTATE 45000; no partial registration | Error and count checks |
| Invalid final mark | Set a mark of 120 | SQLSTATE 45000 / CHECK violation | Error message |
| Officer writes mark | Run unauthorized UPDATE using p1_officer | Access denied by MySQL privileges | Workbench error |
| Report user edits student | Run INSERT using p1_report | Access denied by MySQL privileges | Workbench error |
| Mark change audit | Registrar changes mark 88 to 89 | OldMark=88, NewMark=89; recorded user and time | Audit row |
| Status change audit | Registrar drops RegistrationID 1002 | OldStatus=Registered; NewStatus=Dropped | Audit row |
| Delete audit | Registrar deletes one registration | Registration removed, historical audit remains | Audit before/after |
| Rollback | Update student in transaction, then ROLLBACK | Original value restored | Before, during, after SELECT |
| Report | Run Fall 2026 performance report | Three expected qualifying sections before changes | Actual result screenshot |

### Design evaluation and trade-offs

- **Normalization:** avoids duplicate person/department/course details and update anomalies; requires JOINs, addressed by reusable views.
- **Composite keys:** retain the original meaning of section identity and weak meetings; more verbose FK declarations are necessary.
- **Referential actions:** parent-delete restriction protects academic history; cascading only for truly dependent phone/meeting records reduces orphan records.
- **Transactions:** preserve atomic registration behavior. Row locking prevents oversubscription in concurrent registration attempts, at the cost of temporarily serializing enrollments for the same section.
- **Triggers:** enforce essential checks for direct SQL operations and generate audit events automatically; triggers also increase hidden database logic and therefore need thorough testing/documentation.
- **Stored procedures:** centralize controlled operations and enable EXECUTE-only access for officers. They increase reliance on database-side code, which should be version-controlled.
- **Views:** simplify the multi-table SQL required by the GUI and reporting users; view definitions must be maintained when base tables change.
- **Privileges:** role-specific DB credentials limit unauthorized operations even if the GUI is bypassed. The public SQL uses password placeholders; choose local demo passwords before setup.
- **DB validation vs GUI validation:** basic Tkinter input validation improves user experience; the database remains authoritative for foreign keys, unique registrations, marks, capacities, and permissions.

### Recommended extensions

Add enforced prerequisite completion with an explicit academic override policy, timetable conflict validation, batch enrollment operations, a dedicated DBA-controlled password/account management process, query indexes and performance measurement for much larger data volumes, and an integration test suite connected to a disposable MySQL database.

## Task 5 — Technical Report and Computing Documentation (5 marks)

Suggested submission order: cover page; abstract; requirements and assumptions; Task 1 modeling analysis; conceptual ERD Figure 1; Task 2 schema/3NF tables and dependency explanations; Task 3 implementation with SQL extracts and GUI screenshots; Task 4 controlled testing and screenshots; advanced report SQL/output; constraints and security evidence; evaluation and recommendations; conclusions; appendix with SQL code and repository/file organization.

**Required live evidence to capture:** table counts after `03_seed.sql`, `SHOW CREATE TABLE` for Section and Registration, `SHOW GRANTS` for each user, views, successful and failed `CALL RegisterStudent`, mark/status/delete audit entries, login and role-specific menus, output of `GetSectionPerformanceReport` and the displayed GUI report, and a rollback test. Label each screenshot with figure number, source, and a one-sentence explanation.

**Final accuracy note:** This report describes the reviewed source code and **predicted** outcomes, not an executed MySQL verification. Replace the prediction with actual measured results once the local database and GUI are run.