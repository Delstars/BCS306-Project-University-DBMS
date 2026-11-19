"""Database helper; follows Lab 10: mysql.connector, %s parameters and callproc."""
import mysql.connector

DB_NAME = "UniversityProject1DB"


class Database:
    def __init__(self, host, user, password, port=3306):
        # Never use a shared root password. Credentials come from the login form.
        self.connection = mysql.connector.connect(
            host=host, port=int(port), user=user, password=password,
            database=DB_NAME, autocommit=True, connection_timeout=8
        )
        self.user = user

    def query(self, sql, params=()):
        cursor = self.connection.cursor(dictionary=True)
        try:
            cursor.execute(sql, params)
            return cursor.fetchall()
        finally:
            cursor.close()

    def execute(self, sql, params=()):
        cursor = self.connection.cursor()
        try:
            cursor.execute(sql, params)
            self.connection.commit()
            return cursor.rowcount
        except mysql.connector.Error:
            self.connection.rollback()
            raise
        finally:
            cursor.close()

    def call(self, procedure, args):
        allowed = {
            'RegisterStudent', 'ChangeRegistrationStatus', 'SetFinalMark',
            'CompleteRegistration', 'GetSectionPerformanceReport'
        }
        if procedure not in allowed:
            raise ValueError("Unknown stored procedure")
        cursor = self.connection.cursor()
        try:
            cursor.callproc(procedure, args)
            rows = []
            for result in cursor.stored_results():
                columns = result.column_names
                for row in result.fetchall():
                    rows.append(dict(zip(columns, row)))
            self.connection.commit()
            return rows
        except mysql.connector.Error:
            self.connection.rollback()
            raise
        finally:
            cursor.close()

    def close(self):
        if self.connection.is_connected():
            self.connection.close()
