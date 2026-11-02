CREATE TABLE academic_groups (
    group_id SERIAL PRIMARY KEY,
    group_name VARCHAR(20) NOT NULL UNIQUE,
    enrollment_year INT NOT NULL CHECK (enrollment_year >= 2020 AND enrollment_year <= 2100)
);

CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    group_id INT NOT NULL REFERENCES academic_groups(group_id) ON DELETE CASCADE,
    birth_date DATE NOT NULL CHECK (birth_date < CURRENT_DATE)
);

CREATE TABLE professors (
    professor_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    department VARCHAR(100) NOT NULL
);

CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL,
    credits INT NOT NULL CHECK (credits > 0 AND credits <= 10),
    professor_id INT REFERENCES professors(professor_id) ON DELETE SET NULL
);

CREATE TABLE exam_results (
    student_id INT REFERENCES students(student_id) ON DELETE CASCADE,
    course_id INT REFERENCES courses(course_id) ON DELETE CASCADE,
    exam_date DATE NOT NULL,
    grade INT NOT NULL CHECK (grade >= 2 AND grade <= 5),
    PRIMARY KEY (student_id, course_id, exam_date)
);