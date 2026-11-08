BEGIN;

-- 1 в ПМИ-307 перевёлся новый студент, сразу назначаем ему два экзамена
INSERT INTO students (first_name, last_name, email, group_id, birth_date)
VALUES ('Илья', 'Смирнов', 'ilya.smirnov@example.com',
        (SELECT group_id FROM academic_groups WHERE group_name = 'ПМИ-307'),
        '2006-10-03');

INSERT INTO exam_results (student_id, course_id, exam_date, grade, status)
VALUES
    ((SELECT student_id FROM students WHERE email = 'ilya.smirnov@example.com'),
     (SELECT course_id FROM courses WHERE course_name = 'Базы данных'),
     '2026-10-20', NULL, 'scheduled'),
    ((SELECT student_id FROM students WHERE email = 'ilya.smirnov@example.com'),
     (SELECT course_id FROM courses WHERE course_name = 'Операционные системы'),
     '2027-01-15', NULL, 'scheduled');

-- проверяем, что студент и его экзамены добавились
SELECT s.last_name, c.course_name, er.exam_date, er.grade, er.status
FROM exam_results er
JOIN students s ON s.student_id = er.student_id
JOIN courses  c ON c.course_id  = er.course_id
WHERE s.email = 'ilya.smirnov@example.com';


-- 2 экзамен по БД у Смирнова прошёл: меняем статус и ставим оценку
UPDATE exam_results
SET status = 'completed',
    grade  = 4
WHERE student_id = (SELECT student_id FROM students WHERE email = 'ilya.smirnov@example.com')
  AND course_id  = (SELECT course_id FROM courses WHERE course_name = 'Базы данных')
  AND status = 'scheduled';


-- 3 Кузнецова на больничном, все ещё не прошедшие экзамены по её курсам переносим на неделю
UPDATE exam_results
SET exam_date = exam_date + INTERVAL '7' DAY
WHERE status = 'scheduled'
  AND course_id IN (SELECT c.course_id
                    FROM courses c
                    JOIN professors p ON p.professor_id = c.professor_id
                    WHERE p.last_name = 'Кузнецова');

-- смотрим, какие экзамены теперь назначены
SELECT s.last_name, c.course_name, er.exam_date, er.status
FROM exam_results er
JOIN students s ON s.student_id = er.student_id
JOIN courses  c ON c.course_id  = er.course_id
WHERE er.status = 'scheduled'
ORDER BY er.exam_date;


-- 4 экзамен по ОС Смирнову назначили по ошибке (это курс 4-го года), удаляем его
DELETE FROM exam_results
WHERE student_id = (SELECT student_id FROM students WHERE email = 'ilya.smirnov@example.com')
  AND course_id  = (SELECT course_id FROM courses WHERE course_name = 'Операционные системы');

COMMIT;



-- 5 демонстрация ROLLBACK
BEGIN;

-- количество студентов, результатов и курсов без преподавателя до изменений
SELECT
    (SELECT COUNT(*) FROM students)                       AS students_cnt,
    (SELECT COUNT(*) FROM exam_results)                   AS results_cnt,
    (SELECT COUNT(*) FROM courses WHERE professor_id IS NULL) AS courses_without_prof;

-- отчисляем Баранова: его результаты удалятся каскадно (ON DELETE CASCADE)
DELETE FROM students WHERE email = 'gleb.baranov@example.com';

-- увольняем Соколова, у его курсов professor_id станет NULL (ON DELETE SET NULL)
DELETE FROM professors WHERE last_name = 'Соколов';

-- внутри транзакции изменения видны
SELECT
    (SELECT COUNT(*) FROM students)                       AS students_cnt,
    (SELECT COUNT(*) FROM exam_results)                   AS results_cnt,
    (SELECT COUNT(*) FROM courses WHERE professor_id IS NULL) AS courses_without_prof;

ROLLBACK;

-- после отката всё как было
SELECT
    (SELECT COUNT(*) FROM students)                       AS students_cnt,
    (SELECT COUNT(*) FROM exam_results)                   AS results_cnt,
    (SELECT COUNT(*) FROM courses WHERE professor_id IS NULL) AS courses_without_prof;
