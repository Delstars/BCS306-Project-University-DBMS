"""Lab 10-style Python/MySQL connection test. Run python app/test_connection.py."""
import mysql.connector

host = input("Host [localhost]: ")
if host == "":
    host = "localhost"
username = input("MySQL username: ")
password = input("MySQL password: ")

connection = None
try:
    connection = mysql.connector.connect(
        host=host, user=username, password=password,
        database="UniversityProject1DB"
    )
    if connection.is_connected():
        print("Connected successfully to MySQL")
    cursor = connection.cursor()
    cursor.execute("SELECT DATABASE()")
    print("Selected database:", cursor.fetchone()[0])
    cursor.close()
except mysql.connector.Error as error:
    print("Connection failed:", error)
finally:
    if connection is not None and connection.is_connected():
        connection.close()
