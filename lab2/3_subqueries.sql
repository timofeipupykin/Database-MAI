-- ЛР 2. Часть 3. Подзапросы и поиск нетривиальных ситуаций.
-- «Состоявшаяся попытка» = status 'completed' или 'absent' (неявка тоже считается попыткой).
-- «Курс сдан» = есть запись 'completed' с оценкой >= 3.

-- 3.1. Сравнение с вычисляемым показателем:
-- студенты, чей средний балл выше среднего балла их собственной группы.
WITH student_avg AS (
    SELECT s.student_id, s.group_id, AVG(er.grade) AS avg_grade
    FROM students s
    JOIN exam_results er ON er.student_id = s.student_id
    WHERE er.status = 'completed'
    GROUP BY s.student_id, s.group_id
)
SELECT
    g.group_name,
    s.last_name || ' ' || s.first_name AS student,
    ROUND(sa.avg_grade, 2)             AS student_avg,
    ROUND(ga.avg_grade, 2)             AS group_avg
FROM student_avg sa
JOIN (   -- подзапрос: средний балл по каждой группе (группа сравнения)
    SELECT s2.group_id, AVG(er2.grade) AS avg_grade
    FROM exam_results er2
    JOIN students s2 ON s2.student_id = er2.student_id
    WHERE er2.status = 'completed'
    GROUP BY s2.group_id
) ga ON ga.group_id = sa.group_id
JOIN students        s ON s.student_id = sa.student_id
JOIN academic_groups g ON g.group_id   = sa.group_id
WHERE sa.avg_grade > ga.avg_grade
ORDER BY g.group_name, student_avg DESC;


-- 3.2. EXISTS: студенты, у которых была хотя бы одна «двойка»,
-- но этот же курс впоследствии был ими пересдан (закрытая задолженность).
SELECT
    s.last_name || ' ' || s.first_name AS student,
    c.course_name,
    er.exam_date                       AS failed_on
FROM exam_results er
JOIN students s ON s.student_id = er.student_id
JOIN courses  c ON c.course_id  = er.course_id
WHERE er.grade = 2
  AND EXISTS (
      SELECT 1
      FROM exam_results r
      WHERE r.student_id = er.student_id
        AND r.course_id  = er.course_id
        AND r.exam_date  > er.exam_date
        AND r.status = 'completed'
        AND r.grade >= 3
  )
ORDER BY student, failed_on;


-- 3.3. NOT EXISTS: текущие академические задолженности.
-- Студент уже пытался сдать курс (была состоявшаяся попытка: «двойка» или неявка),
-- но положительной оценки по этому курсу у него НЕТ.
-- Отсутствие события «курс сдан» здесь означает долг, который нужно закрыть.
SELECT
    g.group_name,
    s.last_name || ' ' || s.first_name AS student,
    c.course_name,
    MAX(er.exam_date)                  AS last_attempt,
    COUNT(*)                           AS attempts
FROM exam_results er
JOIN students        s ON s.student_id = er.student_id
JOIN academic_groups g ON g.group_id   = s.group_id
JOIN courses         c ON c.course_id  = er.course_id
WHERE er.status IN ('completed', 'absent')
  AND NOT EXISTS (
      SELECT 1
      FROM exam_results r
      WHERE r.student_id = er.student_id
        AND r.course_id  = er.course_id
        AND r.status = 'completed'
        AND r.grade >= 3
  )
GROUP BY g.group_name, student, c.course_name
ORDER BY g.group_name, student;


-- 3.4. Коррелированный подзапрос: индивидуальные показатели каждого студента.
-- Каждый подзапрос в SELECT выполняется для текущей строки s (s.student_id).
SELECT
    s.last_name || ' ' || s.first_name AS student,
    g.group_name,
    (SELECT COUNT(*)
     FROM exam_results er
     WHERE er.student_id = s.student_id
       AND er.status IN ('completed', 'absent'))            AS attempts,
    (SELECT ROUND(AVG(er.grade), 2)
     FROM exam_results er
     WHERE er.student_id = s.student_id
       AND er.status = 'completed')                         AS avg_grade,
    (SELECT COUNT(DISTINCT er.course_id)
     FROM exam_results er
     WHERE er.student_id = s.student_id
       AND er.status = 'completed' AND er.grade >= 3)       AS courses_passed,
    (SELECT MIN(er.exam_date)
     FROM exam_results er
     WHERE er.student_id = s.student_id
       AND er.status = 'scheduled')                         AS next_exam
FROM students s
JOIN academic_groups g ON g.group_id = s.group_id
ORDER BY g.group_name, student;
