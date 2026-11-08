-- попытка = экзамен со статусом completed или absent (неявка тоже считается)
-- курс сдан = есть оценка 3 и выше

-- 3.1 студенты, у которых средний балл выше, чем средний балл по их группе
SELECT
    g.group_name,
    s.last_name || ' ' || s.first_name AS student,
    ROUND(AVG(er.grade), 2)            AS student_avg
FROM students s
JOIN academic_groups g ON g.group_id   = s.group_id
JOIN exam_results er   ON er.student_id = s.student_id
WHERE er.status = 'completed'
GROUP BY g.group_id, g.group_name, s.student_id, s.last_name, s.first_name
HAVING AVG(er.grade) > (
    -- средний балл всей группы этого студента
    SELECT AVG(er2.grade)
    FROM exam_results er2
    JOIN students s2 ON s2.student_id = er2.student_id
    WHERE s2.group_id = g.group_id
      AND er2.status = 'completed'
)
ORDER BY g.group_name, student_avg DESC;


-- 3.2 двойки, которые студент потом пересдал (есть более поздняя оценка 3+ по тому же курсу)
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


-- 3.3 текущие долги: студент уже пытался сдать курс (двойка или неявка),
-- но положительной оценки по нему так и нет
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
GROUP BY g.group_name, s.student_id, s.last_name, s.first_name, c.course_name
ORDER BY g.group_name, student;


-- 3.4 карточка каждого студента: попытки, средний балл, сколько курсов сдано, ближайший экзамен
-- каждый подзапрос считается для текущего студента s
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
