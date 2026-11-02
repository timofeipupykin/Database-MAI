-- ЛР 2. Задание 2.2. Агрегация и группировка.
-- Используются агрегаты COUNT, SUM, AVG, MIN, MAX.

-- 2.2.1. Количественные показатели по группам:
-- сколько студентов, сколько состоявшихся экзаменов, неявок и «двоек».
-- LEFT JOIN, чтобы в отчёт попали группы и студенты без экзаменов.
SELECT
    g.group_name,
    COUNT(DISTINCT s.student_id)                                    AS students,
    COUNT(er.student_id) FILTER (WHERE er.status = 'completed')     AS exams_taken,
    COUNT(er.student_id) FILTER (WHERE er.status = 'absent')        AS absences,
    COUNT(er.student_id) FILTER (WHERE er.grade = 2)                AS fails,
    COUNT(er.student_id) FILTER (WHERE er.status = 'scheduled')     AS scheduled
FROM academic_groups g
LEFT JOIN students s      ON s.group_id    = g.group_id
LEFT JOIN exam_results er ON er.student_id = s.student_id
GROUP BY g.group_name
ORDER BY g.group_name;


-- 2.2.2. Средние показатели с фильтрацией групп через HAVING:
-- «проблемные» курсы - средний балл по состоявшимся экзаменам ниже 4,
-- при этом по курсу было не меньше 5 экзаменов (чтобы статистика была значимой).
SELECT
    c.course_name,
    COUNT(*)                                         AS exams_taken,
    ROUND(AVG(er.grade), 2)                          AS avg_grade,
    MIN(er.grade)                                    AS min_grade,
    MAX(er.grade)                                    AS max_grade,
    SUM(CASE WHEN er.grade = 2 THEN 1 ELSE 0 END)    AS fails
FROM courses c
JOIN exam_results er ON er.course_id = c.course_id
WHERE er.status = 'completed'
GROUP BY c.course_name
HAVING COUNT(*) >= 5
   AND AVG(er.grade) < 4
ORDER BY avg_grade;


-- 2.2.3. Сравнение показателей между временными периодами:
-- зимняя сессия (с пересдачами) против летней (с пересдачами).
-- Для каждой сессии: число попыток, средний балл, доля неуспешных попыток.
SELECT
    CASE
        WHEN er.exam_date BETWEEN DATE '2025-12-01' AND DATE '2026-03-31' THEN '1. Зима 2025/26'
        WHEN er.exam_date BETWEEN DATE '2026-06-01' AND DATE '2026-09-30' THEN '2. Лето 2026'
    END                                                                AS session,
    COUNT(*)                                                           AS attempts,
    COUNT(*) FILTER (WHERE er.status = 'completed')                    AS exams_taken,
    ROUND(AVG(er.grade), 2)                                            AS avg_grade,
    SUM(CASE WHEN er.grade = 5 THEN 1 ELSE 0 END)                      AS excellent,
    ROUND(100.0 * COUNT(*) FILTER (WHERE er.grade = 2 OR er.status = 'absent')
          / COUNT(*), 1)                                               AS fail_pct
FROM exam_results er
WHERE er.status IN ('completed', 'absent')   -- только состоявшиеся попытки
  AND (er.exam_date BETWEEN DATE '2025-12-01' AND DATE '2026-03-31'
    OR er.exam_date BETWEEN DATE '2026-06-01' AND DATE '2026-09-30')
GROUP BY session
ORDER BY session;
