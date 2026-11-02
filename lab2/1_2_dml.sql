-- ЛР 2. Задание 1.2. Операции изменения данных.
-- Шаги 1-4 выполняются в одной транзакции и фиксируются (COMMIT).
-- Шаг 5 демонстрирует отмену изменений (ROLLBACK).

BEGIN;

-- 1. INSERT: в группу ПМИ-307 переведён новый студент; ему сразу назначены
--    два экзамена. CTE с RETURNING передаёт новый student_id во второй INSERT.
WITH new_student AS (
    INSERT INTO students (first_name, last_name, email, group_id, birth_date)
    VALUES ('Илья', 'Смирнов', 'ilya.smirnov@example.com',
            (SELECT group_id FROM academic_groups WHERE group_name = 'ПМИ-307'),
            '2006-10-03')
    RETURNING student_id
)
INSERT INTO exam_results (student_id, course_id, exam_date, grade, status)
SELECT ns.student_id, c.course_id, v.exam_date::date, NULL, 'scheduled'
FROM new_student ns
CROSS JOIN (VALUES
    ('Базы данных',           '2026-10-20'),
    ('Операционные системы',  '2027-01-15')
) AS v(course_name, exam_date)
JOIN courses c ON c.course_name = v.course_name;

SELECT s.last_name, c.course_name, er.exam_date, er.grade, er.status
FROM exam_results er
JOIN students s ON s.student_id = er.student_id
JOIN courses  c ON c.course_id  = er.course_id
WHERE s.email = 'ilya.smirnov@example.com';

-- 2. UPDATE состояния операции: экзамен по БД у Смирнова состоялся,
--    статус scheduled -> completed, выставлена оценка.
UPDATE exam_results
SET status = 'completed',
    grade  = 4
WHERE student_id = (SELECT student_id FROM students WHERE email = 'ilya.smirnov@example.com')
  AND course_id  = (SELECT course_id FROM courses WHERE course_name = 'Базы данных')
  AND status = 'scheduled';

-- 3. Массовое UPDATE: преподаватель Кузнецова уходит на больничный, поэтому
--    все ещё не состоявшиеся (scheduled) экзамены по её курсам переносятся на неделю.
UPDATE exam_results er
SET exam_date = er.exam_date + 7
FROM courses c
JOIN professors p ON p.professor_id = c.professor_id
WHERE er.course_id = c.course_id
  AND p.last_name = 'Кузнецова'
  AND er.status = 'scheduled';

SELECT s.last_name, c.course_name, er.exam_date, er.status
FROM exam_results er
JOIN students s ON s.student_id = er.student_id
JOIN courses  c ON c.course_id  = er.course_id
WHERE er.status = 'scheduled'
ORDER BY er.exam_date;

-- 4. DELETE с учётом ограничений целостности: удаляем ошибочно назначенный
--    экзамен по «Операционным системам» у Смирнова (курс 4-го года обучения).
--    Удаление из exam_results ни на что не влияет; при удалении же студента
--    его результаты удалились бы каскадно (ON DELETE CASCADE) - см. шаг 5.
DELETE FROM exam_results
WHERE student_id = (SELECT student_id FROM students WHERE email = 'ilya.smirnov@example.com')
  AND course_id  = (SELECT course_id FROM courses WHERE course_name = 'Операционные системы');

COMMIT;


-- 5. ROLLBACK: демонстрация отмены изменений.
BEGIN;

-- до изменений
SELECT
    (SELECT COUNT(*) FROM students)                       AS students_cnt,
    (SELECT COUNT(*) FROM exam_results)                   AS results_cnt,
    (SELECT COUNT(*) FROM courses WHERE professor_id IS NULL) AS courses_without_prof;

-- отчисляем студента Баранова: его результаты удаляются каскадно (ON DELETE CASCADE)
DELETE FROM students WHERE email = 'gleb.baranov@example.com';

-- увольняем преподавателя Соколова: его курсы остаются без преподавателя (ON DELETE SET NULL)
DELETE FROM professors WHERE last_name = 'Соколов';

-- внутри транзакции изменения видны
SELECT
    (SELECT COUNT(*) FROM students)                       AS students_cnt,
    (SELECT COUNT(*) FROM exam_results)                   AS results_cnt,
    (SELECT COUNT(*) FROM courses WHERE professor_id IS NULL) AS courses_without_prof;

ROLLBACK;

-- после ROLLBACK данные вернулись в исходное состояние
SELECT
    (SELECT COUNT(*) FROM students)                       AS students_cnt,
    (SELECT COUNT(*) FROM exam_results)                   AS results_cnt,
    (SELECT COUNT(*) FROM courses WHERE professor_id IS NULL) AS courses_without_prof;
