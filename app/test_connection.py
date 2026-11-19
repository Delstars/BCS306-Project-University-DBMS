"""Optional Lab 10-style test of the real MySQL credentials and database."""
import getpass
from db import Database

host = input('Host [localhost]: ').strip() or 'localhost'
username = input('MySQL username: ').strip()
password = getpass.getpass('MySQL password: ')
connection = None
try:
    connection = Database(host, username, password)
    result = connection.query('SELECT DATABASE() AS CurrentDatabase')
    print('Connected successfully to', result[0]['CurrentDatabase'])
except Exception as error:
    print('Connection failed:', error)
finally:
    if connection is not None:
        connection.close()
