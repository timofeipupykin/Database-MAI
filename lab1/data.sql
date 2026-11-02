INSERT INTO academic_groups (group_name, enrollment_year) VALUES 
('ПМИ-306', 2024),
('ПМИ-307', 2024);

INSERT INTO students (first_name, last_name, email, group_id, birth_date) VALUES 
('Тимофей', 'Пупыкин', 'tim.pup@example.com', 1, '2006-05-15'),
('Джон', 'Смит', 'john.smit@example.com', 1, '2005-11-20'),
('Иван', 'Иванов', 'ivan.iv@example.com', 2, '2006-02-10');

INSERT INTO professors (first_name, last_name, department) VALUES 
('Никита', 'Макаров', 'Кафедра вычислительной математики и программирования'),
('Юрий', 'Битюков', 'Кафедра математического анализа');

INSERT INTO courses (course_name, credits, professor_id) VALUES 
('Алгоритмы и структуры данных', 6, 1),
('Математический анализ', 7, 2),
('Дискретный Анализ', 5, 1);

INSERT INTO exam_results (student_id, course_id, exam_date, grade) VALUES 
(1, 1, '2026-01-15', 5),
(1, 2, '2026-01-20', 4),
(2, 1, '2026-01-15', 3),
(3, 2, '2026-01-20', 5);