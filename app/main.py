"""BCS306 Project 1: simple Tkinter + MySQL university records system.

Course techniques: frames, widgets, mysql.connector, parameterized queries,
transactions/procedures, error handling, and database-enforced user grants.
"""
import tkinter as tk
from tkinter import ttk, messagebox

import mysql.connector
from db import Database

ROLE_NAMES = {
    'p1_registrar': 'Registrar',
    'p1_officer': 'Registration Officer',
    'p1_report': 'Report User',
}
STUDENT_COLUMNS = (
    'StudentID', 'FirstName', 'MiddleName', 'FamilyName', 'DateOfBirth',
    'Email', 'AdmissionYear', 'StudentStatus', 'DeptCode', 'AdvisorID',
    'Street', 'City', 'Emirate', 'PostalCode'
)


class ProjectApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('BCS306 | University Academic Records')
        self.geometry('1170x750')
        self.minsize(950, 620)
        self.db = None
        self.role = None
        self.views = {}
        self.configure(padx=12, pady=12)
        self.protocol('WM_DELETE_WINDOW', self.exit_app)
        self.style = ttk.Style()
        try:
            self.style.theme_use('clam')
        except tk.TclError:
            pass
        self.style.configure('Treeview', rowheight=26)
        self.show_login()

    def reset_window(self):
        for child in self.winfo_children():
            child.destroy()

    def show_login(self):
        self.reset_window()
        self.title('BCS306 Project 1 | MySQL Login')
        box = ttk.Frame(self, padding=28)
        box.pack(expand=True)
        ttk.Label(box, text='University Academic Records', font=('Segoe UI', 21, 'bold')).grid(
            row=0, column=0, columnspan=2, pady=(0, 8))
        ttk.Label(box, text='Login using your MySQL user account, not root.').grid(
            row=1, column=0, columnspan=2, pady=(0, 22))
        defaults = [('Host', 'localhost'), ('Port', '3306'),
                    ('Username', 'p1_officer'), ('Password', '')]
        self.login_vars = {}
        for i, (name, initial) in enumerate(defaults, 2):
            ttk.Label(box, text=name).grid(row=i, column=0, sticky='e', padx=9, pady=7)
            var = tk.StringVar(value=initial)
            self.login_vars[name] = var
            entry = ttk.Entry(box, textvariable=var, width=32,
                              show='*' if name == 'Password' else '')
            entry.grid(row=i, column=1, pady=7)
            if name == 'Password':
                entry.bind('<Return>', lambda _event: self.login())
                entry.focus_set()
        ttk.Button(box, text='Connect to MySQL', command=self.login).grid(
            row=6, column=0, columnspan=2, pady=22)
        ttk.Label(box, text='Roles: p1_registrar · p1_officer · p1_report').grid(
            row=7, column=0, columnspan=2)

    def login(self):
        user = self.login_vars['Username'].get().strip()
        if user not in ROLE_NAMES:
            messagebox.showerror('Role not configured', 'Use one of the three project MySQL accounts.')
            return
        try:
            self.db = Database(
                self.login_vars['Host'].get().strip(), user,
                self.login_vars['Password'].get(), self.login_vars['Port'].get().strip())
            # Connection success means MySQL accepted the actual username/password.
            self.db.query('SELECT DATABASE() AS CurrentDatabase')
        except (mysql.connector.Error, ValueError) as err:
            messagebox.showerror('MySQL login failed', str(err))
            return
        self.role = ROLE_NAMES[user]
        self.show_main()

    def exit_app(self):
        if self.db is not None:
            self.db.close()
        self.destroy()

    def logout(self):
        if self.db is not None:
            self.db.close()
            self.db = None
        self.role = None
        self.show_login()

    def run_action(self, function, refresh=None, success='Operation completed.'):
        try:
            function()
            messagebox.showinfo('Success', success)
            if refresh:
                refresh()
        except (mysql.connector.Error, ValueError, TypeError) as err:
            messagebox.showerror('Database operation rejected', str(err))

    def show_main(self):
        self.reset_window()
        self.title(f'BCS306 Project 1 | {self.role}')
        top = ttk.Frame(self)
        top.pack(fill='x', pady=(0, 12))
        ttk.Label(top, text='University Course Registration & Academic Records',
                  font=('Segoe UI', 17, 'bold')).pack(side='left')
        ttk.Button(top, text='Log out', command=self.logout).pack(side='right')
        ttk.Label(top, text=f'Logged in: {self.db.user}  |  {self.role}').pack(side='right', padx=16)
        self.notebook = ttk.Notebook(self)
        self.notebook.pack(fill='both', expand=True)
        self.capacity_tab()
        if self.role != 'Report User':
            self.students_tab()
            self.registration_tab()
            if self.role == 'Registrar':
                self.section_admin_tab()
                self.marks_tab()
                self.audit_tab()
        else:
            self.registration_view_tab()
        if self.role in ('Registrar', 'Report User'):
            self.report_tab()

    def add_tab(self, title):
        frame = ttk.Frame(self.notebook, padding=10)
        self.notebook.add(frame, text=title)
        return frame

    def make_table(self, parent, height=14):
        holder = ttk.Frame(parent)
        holder.pack(fill='both', expand=True, pady=8)
        tree = ttk.Treeview(holder, show='headings', height=height)
        yscroll = ttk.Scrollbar(holder, orient='vertical', command=tree.yview)
        xscroll = ttk.Scrollbar(holder, orient='horizontal', command=tree.xview)
        tree.configure(yscrollcommand=yscroll.set, xscrollcommand=xscroll.set)
        tree.grid(row=0, column=0, sticky='nsew')
        yscroll.grid(row=0, column=1, sticky='ns')
        xscroll.grid(row=1, column=0, sticky='ew')
        holder.rowconfigure(0, weight=1)
        holder.columnconfigure(0, weight=1)
        return tree

    @staticmethod
    def populate(tree, rows, columns=None):
        if columns is None:
            columns = list(rows[0].keys()) if rows else []
        tree['columns'] = columns
        for col in columns:
            tree.heading(col, text=col)
            tree.column(col, anchor='w', width=max(100, min(210, len(col) * 12 + 30)))
        for item in tree.get_children():
            tree.delete(item)
        for row in rows:
            tree.insert('', 'end', values=[str(row.get(col, '')) if row.get(col) is not None else ''
                                            for col in columns])

    @staticmethod
    def selected_id(tree):
        selected = tree.selection()
        if not selected:
            raise ValueError('Select a row in the table first.')
        return int(tree.item(selected[0], 'values')[0])

    @staticmethod
    def form(parent, fields, columns=4):
        frm = ttk.LabelFrame(parent, text='Form', padding=10)
        frm.pack(fill='x', pady=6)
        vars_ = {}
        for i, field in enumerate(fields):
            group = i // (columns // 2)
            col = (i % (columns // 2)) * 2
            ttk.Label(frm, text=field).grid(row=group, column=col, sticky='e', padx=5, pady=4)
            var = tk.StringVar()
            ttk.Entry(frm, textvariable=var, width=20).grid(
                row=group, column=col + 1, sticky='ew', padx=5, pady=4)
            vars_[field] = var
        return frm, vars_

    def capacity_tab(self):
        frame = self.add_tab('Section Capacity')
        bar = ttk.Frame(frame)
        bar.pack(fill='x')
        ttk.Label(bar, text='Live registered seats (Completed and Dropped are not active)').pack(side='left')
        tree = self.make_table(frame)

        def refresh():
            rows = self.db.query('SELECT * FROM v_SectionCapacity ORDER BY Semester,AcademicYear,CourseCode,SectionNo')
            self.populate(tree, rows, ['CourseCode', 'CourseTitle', 'SectionNo', 'Semester',
                                       'AcademicYear', 'MaximumCapacity', 'ActiveEnrollment', 'RemainingSeats'])
        ttk.Button(bar, text='Refresh', command=lambda: self.safe_refresh(refresh)).pack(side='right')
        self.safe_refresh(refresh)

    def safe_refresh(self, callback):
        try:
            callback()
        except (mysql.connector.Error, ValueError) as err:
            messagebox.showerror('Query failed', str(err))

    def students_tab(self):
        frame = self.add_tab('Students')
        searchrow = ttk.Frame(frame)
        searchrow.pack(fill='x')
        ttk.Label(searchrow, text='Search name / ID').pack(side='left')
        search = tk.StringVar()
        ttk.Entry(searchrow, textvariable=search, width=26).pack(side='left', padx=8)
        frm, fields = self.form(frame, STUDENT_COLUMNS)
        buttons = ttk.Frame(frm)
        buttons.grid(row=8, column=0, columnspan=4, pady=6)
        tree = self.make_table(frame, height=11)
        student_cache = {}

        def refresh():
            pattern = '%' + search.get().strip() + '%'
            rows = self.db.query('''SELECT * FROM Student
                 WHERE CAST(StudentID AS CHAR) LIKE %s
                    OR CONCAT_WS(' ',FirstName,MiddleName,FamilyName) LIKE %s
                 ORDER BY StudentID''', (pattern, pattern))
            student_cache.clear()
            for row in rows:
                student_cache[row['StudentID']] = row
            self.populate(tree, rows, ['StudentID','FirstName','MiddleName','FamilyName',
                                      'Email','StudentStatus','DeptCode','AdvisorID'])

        def select_student(_event=None):
            if not tree.selection():
                return
            record = student_cache.get(self.selected_id(tree))
            if record:
                for name in STUDENT_COLUMNS:
                    fields[name].set('' if record[name] is None else str(record[name]))

        def values():
            raw = {k: fields[k].get().strip() for k in STUDENT_COLUMNS}
            raw['StudentID'] = int(raw['StudentID'])
            raw['AdmissionYear'] = int(raw['AdmissionYear'])
            raw['AdvisorID'] = int(raw['AdvisorID']) if raw['AdvisorID'] else None
            for key in ('MiddleName','Street','City','Emirate','PostalCode'):
                raw[key] = raw[key] or None
            for key in ('FirstName','FamilyName','DateOfBirth','Email','StudentStatus','DeptCode'):
                if not raw[key]:
                    raise ValueError(f'{key} is required')
            return raw

        def create():
            record = values()
            columns = ','.join(STUDENT_COLUMNS)
            placeholders = ','.join(['%s'] * len(STUDENT_COLUMNS))
            self.db.execute(f'INSERT INTO Student ({columns}) VALUES ({placeholders})',
                            tuple(record[c] for c in STUDENT_COLUMNS))

        def update():
            record = values()
            up_cols = [c for c in STUDENT_COLUMNS if c != 'StudentID']
            assigns = ','.join(c + '=%s' for c in up_cols)
            self.db.execute(f'UPDATE Student SET {assigns} WHERE StudentID=%s',
                            tuple(record[c] for c in up_cols) + (record['StudentID'],))

        ttk.Button(buttons, text='Add Student', command=lambda: self.run_action(create,refresh,'Student added.')).pack(side='left', padx=4)
        ttk.Button(buttons, text='Update Student', command=lambda: self.run_action(update,refresh,'Student updated.')).pack(side='left', padx=4)
        if self.role == 'Registrar':
            def delete():
                sid = int(fields['StudentID'].get())
                if not messagebox.askyesno('Confirm', f'Delete student {sid}? Restricted if registered.'):
                    return
                self.db.execute('DELETE FROM Student WHERE StudentID=%s', (sid,))
            ttk.Button(buttons, text='Delete Student', command=lambda: self.run_action(delete,refresh,'Student deleted.')).pack(side='left', padx=4)
        ttk.Button(buttons, text='Clear Form', command=lambda: [v.set('') for v in fields.values()]).pack(side='left', padx=4)
        ttk.Button(searchrow, text='Find / Refresh', command=lambda: self.safe_refresh(refresh)).pack(side='left')
        tree.bind('<<TreeviewSelect>>', select_student)
        phones = ttk.Frame(frame)
        phones.pack(fill='x', pady=4)
        ttk.Label(phones, text='Phone for StudentID:').pack(side='left')
        phone_sid = tk.StringVar()
        phone_no = tk.StringVar()
        ttk.Entry(phones, textvariable=phone_sid, width=10).pack(side='left', padx=5)
        ttk.Label(phones, text='Phone number:').pack(side='left')
        ttk.Entry(phones, textvariable=phone_no, width=18).pack(side='left', padx=5)
        ttk.Button(phones, text='Add Phone', command=lambda: self.run_action(
            lambda: self.db.execute('INSERT INTO StudentPhone (StudentID,PhoneNumber) VALUES (%s,%s)',
                                    (int(phone_sid.get()),phone_no.get().strip())),
            success='Phone number added.')).pack(side='left', padx=4)
        ttk.Button(phones, text='View Phones', command=lambda: self.show_phones(phone_sid.get())).pack(side='left')
        self.safe_refresh(refresh)

    def show_phones(self, sid):
        try:
            rows = self.db.query('SELECT PhoneNumber FROM StudentPhone WHERE StudentID=%s ORDER BY PhoneNumber', (int(sid),))
            messagebox.showinfo('Telephone Numbers', '\n'.join(r['PhoneNumber'] for r in rows) or 'No numbers')
        except (ValueError, mysql.connector.Error) as err:
            messagebox.showerror('Error', str(err))

    def registration_view_tab(self):
        frame = self.add_tab('Registrations')
        tree = self.make_table(frame)
        def refresh():
            self.populate(tree, self.db.query('SELECT * FROM v_RegistrationDetails ORDER BY RegistrationID'))
        ttk.Button(frame, text='Refresh registration records',
                   command=lambda: self.safe_refresh(refresh)).pack()
        self.safe_refresh(refresh)

    def registration_tab(self):
        frame = self.add_tab('Registrations')
        frm, vars_ = self.form(frame, ('StudentID','CourseCode','SectionNo','Semester','AcademicYear'), columns=4)
        vars_['Semester'].set('Fall')
        vars_['AcademicYear'].set('2026')
        toolbar = ttk.Frame(frm)
        toolbar.grid(row=3,column=0,columnspan=4,pady=6)
        tree = self.make_table(frame, height=14)
        status_frame = ttk.Frame(frame)
        status_frame.pack(fill='x', pady=4)
        ttk.Label(status_frame, text='Selected registration status:').pack(side='left')
        status_var = tk.StringVar(value='Dropped')
        ttk.Combobox(status_frame,textvariable=status_var,
                     values=('Dropped','Registered'),state='readonly',width=16).pack(side='left',padx=6)

        def refresh():
            self.populate(tree,self.db.query('SELECT * FROM v_RegistrationDetails ORDER BY RegistrationID'))

        def add():
            self.db.call('RegisterStudent',[
                int(vars_['StudentID'].get()),vars_['CourseCode'].get().strip().upper(),
                vars_['SectionNo'].get().strip(),vars_['Semester'].get().strip(),
                int(vars_['AcademicYear'].get())])

        def change_status():
            self.db.call('ChangeRegistrationStatus',[self.selected_id(tree),status_var.get()])

        ttk.Button(toolbar,text='Register Student',command=lambda: self.run_action(
            add,refresh,'Registered if capacity and uniqueness checks passed.')).pack(side='left',padx=4)
        ttk.Button(status_frame,text='Change Status',command=lambda: self.run_action(
            change_status,refresh,'Registration status updated.')).pack(side='left',padx=4)
        ttk.Button(status_frame,text='Refresh',command=lambda: self.safe_refresh(refresh)).pack(side='left',padx=4)
        if self.role == 'Registrar':
            def delete():
                regid=self.selected_id(tree)
                if messagebox.askyesno('Confirm deletion',f'Delete registration {regid}? Audit is preserved.'):
                    self.db.execute('DELETE FROM Registration WHERE RegistrationID=%s',(regid,))
            ttk.Button(status_frame,text='Delete Registration',command=lambda: self.run_action(
                delete,refresh,'Registration deleted; audit retained.')).pack(side='left',padx=4)
        self.safe_refresh(refresh)

    def section_admin_tab(self):
        frame = self.add_tab('Manage Sections')
        fields = ('CourseCode','SectionNo','Semester','AcademicYear','MaximumCapacity',
                  'Classroom','DeliveryMode','InstructorID')
        frm, vars_ = self.form(frame,fields)
        vars_['Semester'].set('Fall')
        vars_['AcademicYear'].set('2026')
        vars_['DeliveryMode'].set('On-campus')
        tree = self.make_table(frame)

        def refresh():
            self.populate(tree,self.db.query('''SELECT CourseCode,SectionNo,Semester,AcademicYear,
                      MaximumCapacity,Classroom,DeliveryMode,InstructorID FROM Section
                      ORDER BY AcademicYear,Semester,CourseCode,SectionNo'''))

        def add():
            vals = [vars_[field].get().strip() for field in fields]
            vals[3],vals[4],vals[7] = int(vals[3]),int(vals[4]),int(vals[7])
            self.db.execute('''INSERT INTO Section
                 (CourseCode,SectionNo,Semester,AcademicYear,MaximumCapacity,Classroom,DeliveryMode,InstructorID)
                 VALUES (%s,%s,%s,%s,%s,%s,%s,%s)''',tuple(vals))

        def add_meeting():
            prompt=tk.Toplevel(self)
            prompt.title('Add Section Meeting')
            entries={}
            for n,field in enumerate(('MeetingNo','DayOfWeek','StartTime','EndTime','Room')):
                ttk.Label(prompt,text=field).grid(row=n,column=0,padx=8,pady=6)
                v=tk.StringVar(value='1' if field=='MeetingNo' else '')
                ttk.Entry(prompt,textvariable=v).grid(row=n,column=1,padx=8,pady=6)
                entries[field]=v
            def save():
                self.db.execute('''INSERT INTO SectionMeeting
                   (CourseCode,SectionNo,Semester,AcademicYear,MeetingNo,DayOfWeek,StartTime,EndTime,Room)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)''',(
                   vars_['CourseCode'].get().strip(),vars_['SectionNo'].get().strip(),
                   vars_['Semester'].get().strip(),int(vars_['AcademicYear'].get()),
                   int(entries['MeetingNo'].get()),entries['DayOfWeek'].get().strip(),
                   entries['StartTime'].get().strip(),entries['EndTime'].get().strip(),
                   entries['Room'].get().strip()))
                prompt.destroy()
            ttk.Button(prompt,text='Save meeting',command=lambda: self.run_action(
                save,success='Meeting added.')).grid(row=5,column=0,columnspan=2,pady=10)

        actions=ttk.Frame(frm)
        actions.grid(row=5,column=0,columnspan=4,pady=6)
        ttk.Button(actions,text='Create Section',command=lambda: self.run_action(
            add,refresh,'Section added.')).pack(side='left',padx=4)
        ttk.Button(actions,text='Add Meeting',command=add_meeting).pack(side='left',padx=4)
        ttk.Button(actions,text='Refresh',command=lambda: self.safe_refresh(refresh)).pack(side='left',padx=4)
        self.safe_refresh(refresh)

    def marks_tab(self):
        frame=self.add_tab('Academic Results')
        ttk.Label(frame,text='Only Registrar can enter or change protected academic marks.').pack(anchor='w')
        toolbar=ttk.Frame(frame)
        toolbar.pack(fill='x',pady=9)
        ttk.Label(toolbar,text='RegistrationID:').pack(side='left')
        regid=tk.StringVar()
        ttk.Entry(toolbar,textvariable=regid,width=13).pack(side='left',padx=6)
        ttk.Label(toolbar,text='Final mark (0-100):').pack(side='left')
        mark=tk.StringVar()
        ttk.Entry(toolbar,textvariable=mark,width=12).pack(side='left',padx=6)
        tree=self.make_table(frame)

        def refresh():
            self.populate(tree,self.db.query('SELECT * FROM v_RegistrationDetails ORDER BY RegistrationID'))

        def on_select(_event=None):
            if tree.selection():
                regid.set(str(self.selected_id(tree)))

        ttk.Button(toolbar,text='Set / Change Mark',command=lambda: self.run_action(
            lambda: self.db.call('SetFinalMark',[int(regid.get()),float(mark.get())]),
            refresh,'Mark saved and audited.')).pack(side='left',padx=4)
        ttk.Button(toolbar,text='Complete With Mark',command=lambda: self.run_action(
            lambda: self.db.call('CompleteRegistration',[int(regid.get()),float(mark.get())]),
            refresh,'Registration completed and audited.')).pack(side='left',padx=4)
        tree.bind('<<TreeviewSelect>>',on_select)
        self.safe_refresh(refresh)

    def audit_tab(self):
        frame=self.add_tab('Audit History')
        tree=self.make_table(frame)
        def refresh():
            self.populate(tree,self.db.query('''SELECT AuditID,RegistrationID,StudentID,EventType,
                 OldStatus,NewStatus,OldFinalMark,NewFinalMark,DatabaseUser,EventTime
                 FROM RegistrationAudit ORDER BY AuditID DESC LIMIT 300'''))
        ttk.Button(frame,text='Refresh Audit Events',command=lambda: self.safe_refresh(refresh)).pack()
        self.safe_refresh(refresh)

    def report_tab(self):
        frame=self.add_tab('Performance Report')
        controls=ttk.Frame(frame)
        controls.pack(fill='x',pady=8)
        ttk.Label(controls,text='Semester:').pack(side='left')
        semester=tk.StringVar(value='Fall')
        ttk.Combobox(controls,textvariable=semester,
                     values=('Fall','Spring','Summer'),state='readonly',width=14).pack(side='left',padx=8)
        ttk.Label(controls,text='Academic year:').pack(side='left')
        year=tk.StringVar(value='2026')
        ttk.Entry(controls,textvariable=year,width=12).pack(side='left',padx=8)
        tree=self.make_table(frame)
        columns=['CourseCode','CourseTitle','DepartmentName','SectionNo','InstructorName',
                 'MaximumCapacity','ActiveEnrollment','RemainingSeats','AverageCompletedMark',
                 'HighestFinalMark','LowestFinalMark','Below60Count']
        self.populate(tree,[],columns)
        ttk.Label(frame,text='Filter: above-average active enrollment OR below-average completed mark.').pack(anchor='w')
        def refresh():
            results=self.db.call('GetSectionPerformanceReport',[semester.get(),int(year.get())])
            self.populate(tree,results,columns)
            if not results:
                messagebox.showinfo('Report','No sections meet the report filter for this period.')
        ttk.Button(controls,text='Generate Report',command=lambda: self.safe_refresh(refresh)).pack(side='left',padx=10)
        self.safe_refresh(refresh)


if __name__ == '__main__':
    ProjectApp().mainloop()