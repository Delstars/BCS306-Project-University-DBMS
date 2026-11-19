# BCS306 — Project 1: University Course Registration, Academic Records, and Reporting System

A complete **MySQL 8 + Python 3/Tkinter** classroom implementation based on the **Project 1** scenario in `BCS306_All_Projects.docx` and the approaches demonstrated in the **supplied Labs 1–7 and 9–10**. **Lab 8 was not included among the uploaded files.**


## GitHub publishing

The repository can be made public. See **[PUBLISH_TO_GITHUB.md](PUBLISH_TO_GITHUB.md)** for the GitHub creation and first-push instructions. The `.gitignore` prevents publishing local virtual environments, secret configuration files, and temporary data. The public SQL scripts use **password placeholders**, not working passwords. Replace each `CHANGE_ME_*` value with a strong password before executing SQL account creation.

## Quick start (Windows + MySQL Workbench + Visual Studio / Python)

**Requirements:** MySQL Server **8.0.16+** (8.0.34 or newer preferred), MySQL Workbench, Python 3.10+ with Tkinter.

1. Open **MySQL Workbench** and connect as your **local administrator/root** account **only to set up the database**.
2. Open **`sql/ALL_IN_ONE_SETUP.sql`** in Workbench and run **the entire file**. This creates a separate `UniversityProject1DB`, loads the baseline dataset, installs the database logic, and creates three restricted MySQL users. **Important: this reset script DROPS `UniversityProject1DB`, deleting any earlier project data.** Never run it against real data.
3. Verify the final result with `SELECT * FROM UniversityProject1DB.v_RegistrationDetails;` and `CALL UniversityProject1DB.GetSectionPerformanceReport('Fall',2026);`.
4. In your terminal, in the project folder, run:

   ```powershell
   py -m venv .venv
   .\.venv\Scripts\Activate.ps1
   python -m pip install -r requirements.txt
   python app/main.py
   ```

5. Log in using the **actual MySQL username and password** of one of the three classroom accounts below. The Python application **does not connect as root** and does not have a hard-coded password. Use **host `localhost`, port `3306`** by default.

| MySQL username | Demo password (change on a shared server) | Allowed functions |
|---|---|---|
| `p1_registrar` | `CHANGE_ME_REGISTRAR` | Student/section management, registration and approved mark updates, audits, report |
| `p1_officer` | `CHANGE_ME_OFFICER` | Student management, phone numbers, controlled registrations and status updates |
| `p1_report` | `CHANGE_ME_REPORT` | Approved registration/capacity views and advanced report only |

**Security note:** These values are **placeholders**, not actual account passwords. Choose replacements and use those same passwords on the GUI login screen. The app's tab visibility is for usability; **MySQL GRANT/REVOKE permissions** are the true security boundary.

## Alternative: run separate SQL files in order

The single setup file is built from the first five scripts. **Before running either setup method, replace `CHANGE_ME_REGISTRAR`, `CHANGE_ME_OFFICER`, and `CHANGE_ME_REPORT` in the setup/security SQL with passwords of your choosing.**

1. `01_schema.sql` — creates the normalized tables, keys, and constraints; **drops and recreates only `UniversityProject1DB`**.
2. `02_logic.sql` — creates prerequisite, registration, capacity, and audit triggers, three views, and five stored procedures.
3. `03_seed.sql` — loads all professor-provided sample records and the explicitly documented additions below. The eight inserted registrations generate audit events automatically.
4. `04_security.sql` — creates and grants least-privilege MySQL accounts.
5. `05_queries.sql` — reusable demonstrations and the advanced report.
6. `06_demo_tests.sql` — examples of valid/invalid queries; the **mutation tests are commented out** so running the file does not silently change your baseline.
7. `07_assert_baseline.sql` — checks baseline counts and requirements; run **before making modifications through the GUI**.

**Do not accidentally run `01_schema.sql` again after your testing** unless you want to reset the project.

## Dummy data provenance (important for your report)

The source document contains **4 departments, 5 instructors, 8 students, 9 telephone entries, 7 courses, 4 prerequisite pairs, 6 sections, and 8 registrations**. These source rows are reproduced in `03_seed.sql` without changing their supplied field values.

The source omits some attributes needed by the full scenario: student addresses, instructor phone extensions, section meeting times, registration dates, and the semester/year on registration records. This solution therefore:

- Leaves absent addresses and office extensions as `NULL`, **not fabricated**.
- Assigns **Fall 2026** to the eight supplied registrations because every supplied section is Fall 2026; this is a documented assumption.
- Uses **`2026-09-01`** as a clearly labelled synthesized registration date, not an instructor-supplied date.
- Adds one clearly labelled supporting **`BCS210` course record** because the specified `BCS301 -> BCS210` prerequisite references a course missing from the course list. Its title, credits, level and status are illustrative, not instructor-supplied.
- Adds eight **synthetic SectionMeeting records** for a realistic demonstration of existence-dependent meetings.

Every other added value is marked in `03_seed.sql`. Reset by rerunning the setup file if you want the unchanged reference baseline.

## Program files

| File | Purpose |
|---|---|
| `app/main.py` | Tkinter login, tabs, forms, lists, search, reports, and error dialogs |
| `app/db.py` | `mysql.connector` connection, parameterized SQL, `callproc`, commit/rollback |
| `app/test_connection.py` | Lab 10-style credential/connection test |
| `docs/ERD.md` + `docs/ERD.dot` | GitHub-renderable Mermaid overview and detailed Graphviz source (`dot -Tpng docs/ERD.dot -o ERD.png`) |
| `docs/PROJECT_TASKS_1_TO_5.md` | Model analysis, 3NF design, implementation, evaluation, and report content |
| `docs/EXPECTED_BASELINE_REPORT.csv` | **Predicted** report rows computed from seed data (not a captured MySQL output) |

## Key database rules

- Section identity is `(CourseCode, SectionNo, Semester, AcademicYear)`; "01" remains a string.
- Student-to-Section is many-to-many via Registration. An additional UNIQUE constraint prevents a student from being registered twice in the same section, even after dropping.
- **Only `Registered` counts as active enrollment.** `Dropped` and `Completed` remain historical registrations but do not occupy active seats. This interpretation is documented because the source does not specify another formula.
- Before insertion, database trigger and stored procedure check section existence and available places; the stored procedure locks the section for concurrent requests. The UNIQUE and FK constraints also protect direct SQL inserts.
- A `Completed` registration must have a valid mark. A Registrar can enter a mark before completion, and can later correct a completed mark. Completed registration statuses are treated as final.
- MySQL automatically audits four events: `REGISTRATION_CREATED`, `REGISTRATION_STATUS_CHANGED`, `FINAL_MARK_CHANGED`, `REGISTRATION_DELETED`. It records `USER()` to preserve the account that connected even when a procedure runs as its definer.
- `RegistrationAudit` intentionally has no FK to Registration so audit history survives deletion. Only the Registrar gets SELECT on audit; none of the application accounts receives UPDATE/DELETE on it.
- The chair must belong to the department they chair, and each department must have exactly one chair, enforced by a composite FK plus `NOT NULL` and `UNIQUE`. Because of the circular relationship, the chair FK is added **after initial seed data is inserted**.

## How to demonstrate the three roles

**Registrar**: add student, register someone, set or complete a final mark, and view audit history. The GUI also supports section creation and adding section meetings.

**Registration Officer**: add student, add phone number, register a student and change a registration status. Try a duplicate registration: a database error appears. The Results and Audit tabs are not available.

**Report User**: view approved registration details and capacity, then run `Fall / 2026` advanced performance report. No write tabs are available. An attempted direct MySQL `INSERT` must be refused by grants.

For marking, rerun a fresh setup, take screenshot evidence **before modifying data**, and then perform the controlled test scenarios in `06_demo_tests.sql`. Never state that a test passed unless you actually ran it against your MySQL instance.

## Limitations / design decisions to explain

- **Prerequisite completion enforcement is not implemented** because the scenario specifically requires representing prerequisites and explicitly validates section existence, uniqueness, and capacity at registration; additionally, the supplied baseline registers student 101 in BCS301 without a completed BCS210. Adding prerequisite checking without exceptions would reject instructor-provided data.
- The database does not implement a comprehensive timetable-clash detection system or generalized administrative user management. They are sensible extensions, not explicit business operations in the brief.
- This is a classroom desktop implementation; use dedicated restricted accounts, rotate passwords, and implement secure deployment practices before any real-world usage.
- The complex report assumes MySQL 8.0 because it uses common table expressions (CTEs).
- GUI validation improves feedback, but **all essential integrity checks are in MySQL**, so MySQL rejects forbidden actions outside Python too.

## What has and has not been verified here

The Python files have passed **syntax compilation**, the original seed rows have been cross-checked against the supplied document, and the ERD source is provided as Graphviz DOT. Both SQL setup paths, the baseline checks, and the Fall 2026 report passed on MySQL 8.0.46. Capture Workbench and GUI test evidence for submission.