# BCS306 Project 1 — Lab 1–10 Syntax Audit

Checked against the **nine** uploaded lab documents (Labs 1, 2, 3, 4, 5, 6, 7, 9 and 10). Lab 8 was not provided.

## Core topics taken from the supplied labs

| Repository feature | Closest supplied lab |
|---|---|
| CREATE/DROP DATABASE and CREATE/ALTER TABLE | Lab 3 |
| PRIMARY KEY, FOREIGN KEY, UNIQUE, NOT NULL, CHECK, DEFAULT | Lab 3 and Lab 7 |
| INSERT/UPDATE/DELETE, SELECT, WHERE, LIKE and ORDER BY | Labs 3–4 |
| COUNT, AVG, MAX, MIN, ROUND and GROUP BY | Lab 5 |
| JOIN, LEFT JOIN and scalar subqueries | Lab 6 |
| Composite PKs, multivalued attributes and FK referential actions | Lab 7 |
| TIMESTAMPDIFF for derived student age | Lab 7 |
| START TRANSACTION, COMMIT, ROLLBACK, BEFORE/AFTER triggers, NEW/OLD, SIGNAL, NOW() | Lab 9 |
| Basic stored procedures with IN parameters, views, GRANT/SHOW GRANTS | Lab 10 |
| mysql.connector, %s placeholders, cursor.execute, cursor.callproc, commit/rollback and Tkinter | Lab 10 |

The source originally included a CTE-based advanced report, CASE WHEN, CROSS JOIN, CONCAT_WS, null-safe equality, LAST_INSERT_ID and ROW_COUNT. The revised source removes those forms. The report now uses Lab 5 aggregates and Lab 6-style scalar subqueries.

The Python GUI was rewritten as an ordinary procedural application. It no longer uses a class-based app, ttk.Notebook or ttk.Treeview, and uses no lambda callbacks, f-strings or dynamic SQL-generated column names. It retains the required MySQL credential login, role-sensitive screens, students, phones, sections, registrations, marks, audit browsing and advanced report.

## Remaining extensions not explicitly demonstrated in the uploaded labs

**These should not be misrepresented as syntax covered by the labs.** They are deliberately retained to satisfy Project 1's extra requirements:

1. `SELECT ... FOR UPDATE` inside the registration logic locks the section while checking capacity. This helps prevent concurrent registration requests from both taking the last seat; a normal SELECT does not provide this guarantee. The registration procedure now obtains this lock **before** any ordinary SELECT to avoid an old repeatable-read snapshot.
2. `RESIGNAL` in the SQL exception handler re-raises the actual error after ROLLBACK. Lab 9's optional Stay Ahead section demonstrates an EXIT HANDLER, but not RESIGNAL. Omitting it would risk reporting an unsuccessful registration as a success or hide the real error.
3. `USER()` in audit triggers captures the MySQL account responsible for a registration change, as explicitly required by Project 1.
4. `DROP USER IF EXISTS` is used only in administrator setup to rebuild demonstration accounts cleanly. The labs teach CREATE USER/GRANT and the related DROP/IF EXISTS concepts, but do not explicitly demonstrate that combined user-removal command.
5. `tk.Frame` and `tk.Text` are standard Tkinter widgets for grouping controls and displaying the required multi-column report. Lab 10 directly demonstrates Tk, Label, Entry, Button and messagebox, but does not directly demonstrate those two additional widgets.
6. Correlated aggregate subqueries in SELECT are a composition of Lab 5 aggregate functions and Lab 6 scalar subqueries. The supplied examples teach those component ideas but not the exact advanced report query.
7. The GUI uses `cursor.stored_results()` to retrieve a result set from `callproc`; Lab 10 teaches `callproc` itself but not this retrieval method. It is needed to show the required report on screen.

There is **no honest way to claim every remaining syntax form appeared verbatim in the uploaded labs** while also implementing the concurrency, audit attribution, and advanced report requirements safely.

## What was corrected

- Removed CTE/CASE/CROSS JOIN from the report.
- Removed a mistaken README claim of verified live MySQL execution.
- Fixed RegistrationAudit EventTime after switching to a lab-friendly NOT NULL column: all four audit INSERT paths now supply `NOW()`.
- Used explicit `RegistrationDate` on seed data and stored-procedure INSERTs rather than a MySQL default expression.
- Simplified schema types and verification SELECTs.
- Switched report-side names to Lab 5 `CONCAT` and kept Lab 7 `TIMESTAMPDIFF`.
- Simplified Student status/mark procedure existence checks using `COUNT(*)`.
- Rebuilt `ALL_IN_ONE_SETUP.sql` from the current separate SQL files so setup paths match.
- Replaced the original class/ttk GUI with a simple Lab 10-style procedural Tkinter GUI.
- Removed the unused class-based DB helper and simplified the connection-test script.
- Kept SQL user password placeholders in public code.

## Local tests still required (do not claim these passed yet)

1. In MySQL Workbench on MySQL 8, replace `CHANGE_ME_*` passwords in `ALL_IN_ONE_SETUP.sql`, then run the entire script as administrator in a disposable local database.
2. Run `sql/07_assert_baseline.sql` before making GUI changes.
3. Run `CALL GetSectionPerformanceReport('Fall', 2026);` and compare its three expected rows with `docs/EXPECTED_BASELINE_REPORT.csv` (a prediction, not a screenshot).
4. Check `SHOW GRANTS` for p1_registrar, p1_officer and p1_report; log in separately using the same credentials in the GUI.
   Run `python -m py_compile app/main.py app/test_connection.py` from the project root to check current Python syntax.
5. Test a successful and duplicate registration, a missing section, a completed mark update, audit events, and unauthorized updates.
6. Check capacity enforcement when two MySQL sessions attempt registration at the same time; ordinary single-session testing is insufficient to verify concurrency behavior.

**Status:** Source reviewed, **not** independently verified running against a live MySQL database in this conversation. The GitHub README and project report should include screenshots only after local execution.
