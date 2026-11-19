# University Project 1 — Entity Relationship Diagram

This is a GitHub-renderable overview of the relationships. The more detailed entity attributes, including composite primary keys and constraints, appear in [ERD.dot](ERD.dot) and [01_schema.sql](../sql/01_schema.sql).

```mermaid
erDiagram
    DEPARTMENT ||--o{ INSTRUCTOR : employs
    DEPARTMENT ||--o{ STUDENT : contains
    DEPARTMENT ||--o{ COURSE : offers
    INSTRUCTOR o|--|| DEPARTMENT : chairs
    INSTRUCTOR o|--o{ STUDENT : advises
    INSTRUCTOR ||--o{ SECTION : teaches
    STUDENT ||--o{ STUDENT_PHONE : has
    COURSE ||--o{ SECTION : offers
    COURSE ||--o{ COURSE_PREREQUISITE : requires
    COURSE ||--o{ COURSE_PREREQUISITE : prerequisite_of
    SECTION ||--o{ SECTION_MEETING : has
    STUDENT ||--o{ REGISTRATION : submits
    SECTION ||--o{ REGISTRATION : receives
    REGISTRATION ||--o{ REGISTRATION_AUDIT : generates

    DEPARTMENT {
      varchar DeptCode PK
      varchar DeptName UK
      varchar Office
      int ChairID FK
    }
    INSTRUCTOR {
      int InstructorID PK
      varchar DeptCode FK
      varchar Email UK
    }
    STUDENT {
      int StudentID PK
      varchar DeptCode FK
      int AdvisorID FK
      date DateOfBirth
    }
    STUDENT_PHONE {
      int StudentID PK,FK
      varchar PhoneNumber PK
    }
    COURSE {
      varchar CourseCode PK
      varchar DeptCode FK
    }
    COURSE_PREREQUISITE {
      varchar CourseCode PK,FK
      varchar PrerequisiteCourseCode PK,FK
    }
    SECTION {
      varchar CourseCode PK,FK
      varchar SectionNo PK
      varchar Semester PK
      int AcademicYear PK
      int InstructorID FK
    }
    SECTION_MEETING {
      varchar CourseCode PK,FK
      varchar SectionNo PK,FK
      varchar Semester PK,FK
      int AcademicYear PK,FK
      int MeetingNo PK
    }
    REGISTRATION {
      int RegistrationID PK
      int StudentID FK
      varchar CourseCode FK
      varchar SectionNo FK
      varchar Semester FK
      int AcademicYear FK
      decimal FinalMark
    }
    REGISTRATION_AUDIT {
      int AuditID PK
      int RegistrationID
      varchar EventType
      datetime EventTime
    }
```

> **Modeling note:** The audit connection is a historical/logical relationship, not an enforced foreign key. Audits survive registration deletion. The section identity is the composite key (CourseCode, SectionNo, Semester, AcademicYear). The SectionMeeting key includes the section composite key plus MeetingNo.
