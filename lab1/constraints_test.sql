INSERT INTO academic_groups (group_name, enrollment_year) 
VALUES ('ПМИ-206', 2025);

INSERT INTO academic_groups (group_name, enrollment_year) 
VALUES ('ПМИ-210', 2010);

INSERT INTO students (first_name, last_name, email, group_id, birth_date) 
VALUES ('Алексей', 'Петров', 'tim.pup@example.com', 2, '2005-01-01');

INSERT INTO exam_results (student_id, course_id, exam_date, grade) 
VALUES (1, 3, '2026-01-25', 6);

INSERT INTO exam_results (student_id, course_id, exam_date, grade) 
VALUES (1, 1, '2026-01-15', 4);