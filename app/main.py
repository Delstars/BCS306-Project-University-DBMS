"""BCS306 Project 1 - Lab 10 style Tkinter/MySQL application.

Simple functions and standard Tkinter widgets instead of an advanced GUI framework.
Tkinter Frame/Text are small standard GUI extensions needed to show report results.
All SQL statements use fixed text and parameter placeholders, as taught in Lab 10.
"""
import tkinter as tk
from tkinter import messagebox
import mysql.connector

DATABASE = "UniversityProject1DB"
connection = None
role = ""
window = tk.Tk()
window.title("BCS306 - University Academic Records")
window.geometry("1000x830")


def clear_window():
    for widget in window.winfo_children():
        widget.destroy()


def query(sql, values=()):
    cursor = connection.cursor()
    try:
        cursor.execute(sql, values)
        columns = cursor.column_names
        rows = cursor.fetchall()
        return columns, rows
    finally:
        cursor.close()


def execute(sql, values=()):
    cursor = connection.cursor()
    try:
        cursor.execute(sql, values)
        connection.commit()
    except mysql.connector.Error:
        connection.rollback()
        raise
    finally:
        cursor.close()


def procedure(name, values):
    cursor = connection.cursor()
    try:
        cursor.callproc(name, values)
        results = []
        columns = []
        for result in cursor.stored_results():
            columns = result.column_names
            results = result.fetchall()
        connection.commit()
        return columns, results
    except mysql.connector.Error:
        connection.rollback()
        raise
    finally:
        cursor.close()


def alert_action(function):
    try:
        function()
        messagebox.showinfo("Success", "MySQL accepted the operation.")
    except (ValueError, mysql.connector.Error) as error:
        messagebox.showerror("Database error", str(error))


def display(text_box, sql, values=()):
    try:
        columns, rows = query(sql, values)
        show_rows(text_box, columns, rows)
    except mysql.connector.Error as error:
        messagebox.showerror("Query failed", str(error))


def show_rows(text_box, columns, rows):
    text_box.delete("1.0", tk.END)
    text_box.insert(tk.END, str(columns) + "\n")
    text_box.insert(tk.END, "-" * 100 + "\n")
    for row in rows:
        text_box.insert(tk.END, str(row) + "\n")
    if not rows:
        text_box.insert(tk.END, "No rows returned.\n")


def screen(title, names):
    clear_window()
    tk.Label(window, text=title, font=("Arial", 18, "bold")).pack(pady=7)
    tk.Button(window, text="Back to menu", command=home).pack(pady=4)
    inputs = {}
    for field in names:
        frame = tk.Frame(window)
        frame.pack()
        tk.Label(frame, text=field, width=20, anchor="e").pack(side="left")
        entry = tk.Entry(frame, width=43)
        entry.pack(side="left", padx=5, pady=2)
        inputs[field] = entry
    action_bar = tk.Frame(window)
    action_bar.pack(pady=6)
    result_box = tk.Text(window, height=15, width=125, wrap="none")
    result_box.pack(padx=6, pady=4, fill="both", expand=True)
    return inputs, action_bar, result_box


def show_login():
    clear_window()
    tk.Label(window, text="University Academic Records", font=("Arial", 19, "bold")).pack(pady=30)
    tk.Label(window, text="Log in with one of the MySQL accounts created in 04_security.sql").pack()
    tk.Label(window, text="Host").pack()
    host = tk.Entry(window, width=35)
    host.insert(0, "localhost")
    host.pack()
    tk.Label(window, text="Username").pack()
    username = tk.Entry(window, width=35)
    username.insert(0, "p1_officer")
    username.pack()
    tk.Label(window, text="Password").pack()
    password = tk.Entry(window, show="*", width=35)
    password.pack()

    def login():
        global connection, role
        user = username.get().strip()
        if user not in ("p1_registrar", "p1_officer", "p1_report"):
            messagebox.showerror("Login error", "Choose one of the three project accounts.")
            return
        try:
            connection = mysql.connector.connect(
                host=host.get().strip(), user=user,
                password=password.get(), database=DATABASE
            )
            role = user
            home()
        except mysql.connector.Error as error:
            messagebox.showerror("Login failed", str(error))

    tk.Button(window, text="Connect to MySQL", command=login).pack(pady=15)


def log_out():
    global connection, role
    if connection is not None and connection.is_connected():
        connection.close()
    connection = None
    role = ""
    show_login()


def home():
    clear_window()
    tk.Label(window, text="BCS306 - University Academic Records", font=("Arial", 18, "bold")).pack(pady=12)
    tk.Label(window, text="Connected as: " + role).pack(pady=4)
    tk.Button(window, text="Section Capacity", width=36, command=capacity_screen).pack(pady=4)
    tk.Button(window, text="Registration Search", width=36, command=registrations_screen).pack(pady=4)
    if role != "p1_report":
        tk.Button(window, text="Student Maintenance", width=36, command=students_screen).pack(pady=4)
        tk.Button(window, text="Telephone Numbers", width=36, command=phone_screen).pack(pady=4)
        tk.Button(window, text="Register Student / Change Status", width=36, command=registration_operations).pack(pady=4)
    if role == "p1_registrar":
        tk.Button(window, text="Sections and Meetings", width=36, command=sections_screen).pack(pady=4)
        tk.Button(window, text="Academic Results", width=36, command=marks_screen).pack(pady=4)
        tk.Button(window, text="Audit History", width=36, command=audit_screen).pack(pady=4)
    if role == "p1_registrar" or role == "p1_report":
        tk.Button(window, text="Academic Section Performance Report", width=36, command=report_screen).pack(pady=4)
    tk.Button(window, text="Log out", command=log_out).pack(pady=18)


def students_screen():
    fields = ("StudentID", "FirstName", "MiddleName", "FamilyName",
              "DateOfBirth", "Email", "AdmissionYear", "StudentStatus",
              "DeptCode", "AdvisorID")
    entries, bar, output = screen("Student Maintenance", fields)
    entries["StudentStatus"].insert(0, "Active")
    def add():
        values = (
            int(entries["StudentID"].get()), entries["FirstName"].get(),
            entries["MiddleName"].get() or None, entries["FamilyName"].get(),
            entries["DateOfBirth"].get(), entries["Email"].get(),
            int(entries["AdmissionYear"].get()), entries["StudentStatus"].get(),
            entries["DeptCode"].get(), int(entries["AdvisorID"].get()) if entries["AdvisorID"].get() else None
        )
        execute("""INSERT INTO Student
            (StudentID,FirstName,MiddleName,FamilyName,DateOfBirth,Email,
             AdmissionYear,StudentStatus,DeptCode,AdvisorID)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""", values)
    def update():
        execute("""UPDATE Student SET FirstName=%s,MiddleName=%s,FamilyName=%s,
           DateOfBirth=%s,Email=%s,AdmissionYear=%s,StudentStatus=%s,
           DeptCode=%s,AdvisorID=%s WHERE StudentID=%s""",
           (entries["FirstName"].get(), entries["MiddleName"].get() or None,
            entries["FamilyName"].get(), entries["DateOfBirth"].get(),
            entries["Email"].get(), int(entries["AdmissionYear"].get()),
            entries["StudentStatus"].get(), entries["DeptCode"].get(),
            int(entries["AdvisorID"].get()) if entries["AdvisorID"].get() else None,
            int(entries["StudentID"].get())))
    def search():
        value = entries["StudentID"].get().strip()
        if value:
            display(output, "SELECT * FROM Student WHERE StudentID=%s", (int(value),))
        else:
            display(output, "SELECT * FROM Student ORDER BY StudentID")
    def delete():
        if role != "p1_registrar":
            messagebox.showerror("Permission denied", "Registrar only.")
            return
        if messagebox.askyesno("Confirm", "Delete this student?"):
            alert_action(lambda_delete)
    def lambda_delete():
        execute("DELETE FROM Student WHERE StudentID=%s", (int(entries["StudentID"].get()),))
    tk.Button(bar, text="Show / Search", command=search).pack(side="left", padx=4)
    tk.Button(bar, text="Add", command=lambda_add).pack(side="left", padx=4)
    tk.Button(bar, text="Update", command=lambda_update).pack(side="left", padx=4)
    if role == "p1_registrar":
        tk.Button(bar, text="Delete", command=delete).pack(side="left", padx=4)
    def lambda_add():
        alert_action(add)
    def lambda_update():
        alert_action(update)
    search()


def phone_screen():
    entries, bar, output = screen("Student Telephone Numbers", ("StudentID", "PhoneNumber"))
    def show():
        display(output, "SELECT * FROM StudentPhone WHERE StudentID=%s",
                (int(entries["StudentID"].get()),))
    def add():
        execute("INSERT INTO StudentPhone (StudentID,PhoneNumber) VALUES (%s,%s)",
                (int(entries["StudentID"].get()), entries["PhoneNumber"].get()))
    def delete():
        execute("DELETE FROM StudentPhone WHERE StudentID=%s AND PhoneNumber=%s",
                (int(entries["StudentID"].get()), entries["PhoneNumber"].get()))
    def add_click():
        alert_action(add)
    def delete_click():
        alert_action(delete)
    tk.Button(bar, text="Show Phones", command=show).pack(side="left", padx=4)
    tk.Button(bar, text="Add Phone", command=add_click).pack(side="left", padx=4)
    tk.Button(bar, text="Delete Phone", command=delete_click).pack(side="left", padx=4)


def capacity_screen():
    entries, bar, output = screen("Section Capacity", ())
    def show():
        display(output, "SELECT * FROM v_SectionCapacity ORDER BY CourseCode,SectionNo")
    tk.Button(bar, text="Refresh", command=show).pack()
    show()


def registrations_screen():
    entries, bar, output = screen("Registration Search", ("StudentID",))
    def show():
        value = entries["StudentID"].get().strip()
        if value:
            display(output, "SELECT * FROM v_RegistrationDetails WHERE StudentID=%s ORDER BY RegistrationID",
                    (int(value),))
        else:
            display(output, "SELECT * FROM v_RegistrationDetails ORDER BY RegistrationID")
    tk.Button(bar, text="Show Registrations", command=show).pack()
    show()


def registration_operations():
    names = ("RegistrationID", "StudentID", "CourseCode", "SectionNo", "Semester", "AcademicYear", "NewStatus")
    entries, bar, output = screen("Register Student / Change Status", names)
    entries["Semester"].insert(0, "Fall")
    entries["AcademicYear"].insert(0, "2026")
    entries["NewStatus"].insert(0, "Dropped")
    def register():
        procedure("RegisterStudent", [
            int(entries["StudentID"].get()), entries["CourseCode"].get(),
            entries["SectionNo"].get(), entries["Semester"].get(),
            int(entries["AcademicYear"].get())])
    def status():
        procedure("ChangeRegistrationStatus", [
            int(entries["RegistrationID"].get()), entries["NewStatus"].get()])
    def delete():
        execute("DELETE FROM Registration WHERE RegistrationID=%s",
                (int(entries["RegistrationID"].get()),))
    def add_click():
        alert_action(register)
    def status_click():
        alert_action(status)
    def delete_click():
        if messagebox.askyesno("Confirm", "Delete registration and retain its audit history?"):
            alert_action(delete)
    def show():
        display(output, "SELECT * FROM v_RegistrationDetails ORDER BY RegistrationID")
    tk.Button(bar, text="Register", command=add_click).pack(side="left", padx=4)
    tk.Button(bar, text="Change Status", command=status_click).pack(side="left", padx=4)
    if role == "p1_registrar":
        tk.Button(bar, text="Delete", command=delete_click).pack(side="left", padx=4)
    tk.Button(bar, text="Refresh", command=show).pack(side="left", padx=4)
    show()


def sections_screen():
    names = ("CourseCode", "SectionNo", "Semester", "AcademicYear", "MaximumCapacity",
             "Classroom", "DeliveryMode", "InstructorID", "MeetingNo",
             "DayOfWeek", "StartTime", "EndTime", "Room")
    entries, bar, output = screen("Sections and Meeting Management", names)
    entries["Semester"].insert(0, "Fall")
    entries["AcademicYear"].insert(0, "2026")
    entries["DeliveryMode"].insert(0, "On-campus")
    def add_section():
        execute("""INSERT INTO Section
           (CourseCode,SectionNo,Semester,AcademicYear,MaximumCapacity,Classroom,DeliveryMode,InstructorID)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
           (entries["CourseCode"].get(),entries["SectionNo"].get(),
            entries["Semester"].get(),int(entries["AcademicYear"].get()),
            int(entries["MaximumCapacity"].get()),entries["Classroom"].get(),
            entries["DeliveryMode"].get(),int(entries["InstructorID"].get())))
    def add_meeting():
        execute("""INSERT INTO SectionMeeting
          (CourseCode,SectionNo,Semester,AcademicYear,MeetingNo,DayOfWeek,StartTime,EndTime,Room)
          VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
          (entries["CourseCode"].get(),entries["SectionNo"].get(),
           entries["Semester"].get(),int(entries["AcademicYear"].get()),
           int(entries["MeetingNo"].get()),entries["DayOfWeek"].get(),
           entries["StartTime"].get(),entries["EndTime"].get(),entries["Room"].get()))
    def add_click():
        alert_action(add_section)
    def meeting_click():
        alert_action(add_meeting)
    def show():
        display(output, "SELECT * FROM Section ORDER BY AcademicYear,CourseCode,SectionNo")
    tk.Button(bar, text="Create Section", command=add_click).pack(side="left", padx=4)
    tk.Button(bar, text="Add Meeting", command=meeting_click).pack(side="left", padx=4)
    tk.Button(bar, text="Refresh", command=show).pack(side="left", padx=4)
    show()


def marks_screen():
    entries, bar, output = screen("Academic Results (Registrar only)", ("RegistrationID", "FinalMark"))
    def change_mark():
        procedure("SetFinalMark", [int(entries["RegistrationID"].get()),
                                    float(entries["FinalMark"].get())])
    def complete():
        procedure("CompleteRegistration", [int(entries["RegistrationID"].get()),
                                            float(entries["FinalMark"].get())])
    def mark_click():
        alert_action(change_mark)
    def complete_click():
        alert_action(complete)
    def show():
        display(output, "SELECT * FROM v_RegistrationDetails ORDER BY RegistrationID")
    tk.Button(bar, text="Set / Correct Mark", command=mark_click).pack(side="left", padx=4)
    tk.Button(bar, text="Complete Registration", command=complete_click).pack(side="left", padx=4)
    tk.Button(bar, text="Refresh", command=show).pack(side="left", padx=4)
    show()


def audit_screen():
    entries, bar, output = screen("Registration Audit History", ())
    def show():
        display(output, "SELECT * FROM RegistrationAudit ORDER BY AuditID DESC LIMIT 100")
    tk.Button(bar, text="Refresh Audit", command=show).pack()
    show()


def report_screen():
    entries, bar, output = screen("Academic Section Performance and Capacity Report",
                                  ("Semester", "AcademicYear"))
    entries["Semester"].insert(0, "Fall")
    entries["AcademicYear"].insert(0, "2026")
    def run():
        try:
            columns, rows = procedure("GetSectionPerformanceReport",
                                       [entries["Semester"].get(),
                                        int(entries["AcademicYear"].get())])
            show_rows(output, columns, rows)
        except (ValueError, mysql.connector.Error) as error:
            messagebox.showerror("Report failed", str(error))
    tk.Button(bar, text="Generate Report", command=run).pack()
    run()


show_login()
window.mainloop()
