-- 2.1.1 ведомость зимней сессии: кто, из какой группы, что сдавал, у кого и с каким результатом
-- к преподавателям LEFT JOIN, иначе пропадут экзамены по Философии (у неё нет преподавателя)
SELECT
    g.group_name,
    s.last_name || ' ' || s.first_name                       AS student,
    c.course_name,
    COALESCE(p.last_name || ' ' || p.first_name, 'не назначен') AS professor,
    er.exam_date,
    er.status,
    er.grade
FROM exam_results er
JOIN students        s ON s.student_id   = er.student_id
JOIN academic_groups g ON g.group_id     = s.group_id
JOIN courses         c ON c.course_id    = er.course_id
LEFT JOIN professors p ON p.professor_id = c.professor_id
WHERE er.exam_date BETWEEN DATE '2025-12-01' AND DATE '2026-03-31'
ORDER BY g.group_name, student, er.exam_date;


-- 2.1.2 студенты, у которых нет ни одного экзамена
-- если пары в exam_results не нашлось, LEFT JOIN подставит NULL, их и оставляем
SELECT
    g.group_name,
    g.enrollment_year,
    s.last_name || ' ' || s.first_name AS student,
    s.email
FROM academic_groups g
JOIN students s           ON s.group_id   = g.group_id
LEFT JOIN exam_results er ON er.student_id = s.student_id
WHERE er.student_id IS NULL
ORDER BY g.group_name, student;


-- 2.1.3 студенты набора 2024 года, получившие 5 в летнюю сессию
-- по курсам кафедры вычислительной математики и программирования
SELECT
    g.group_name,
    s.last_name || ' ' || s.first_name AS student,
    c.course_name,
    p.last_name AS professor,
    er.exam_date
FROM exam_results er
JOIN students        s ON s.student_id   = er.student_id
JOIN academic_groups g ON g.group_id     = s.group_id
JOIN courses         c ON c.course_id    = er.course_id
JOIN professors      p ON p.professor_id = c.professor_id
WHERE g.enrollment_year = 2024
  AND p.department = 'Кафедра вычислительной математики и программирования'
  AND er.status = 'completed'
  AND er.grade = 5
  AND er.exam_date BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'
ORDER BY g.group_name, student;
