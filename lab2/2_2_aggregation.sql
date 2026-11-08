-- 2.2.1 сводка по группам: студенты, сданные экзамены, неявки, двойки, назначенные экзамены
-- LEFT JOIN, чтобы ПМИ-108 (без экзаменов) тоже попала в результат с нулями
SELECT
    g.group_name,
    COUNT(DISTINCT s.student_id)                               AS students,
    SUM(CASE WHEN er.status = 'completed' THEN 1 ELSE 0 END)   AS exams_taken,
    SUM(CASE WHEN er.status = 'absent'    THEN 1 ELSE 0 END)   AS absences,
    SUM(CASE WHEN er.grade = 2            THEN 1 ELSE 0 END)   AS fails,
    SUM(CASE WHEN er.status = 'scheduled' THEN 1 ELSE 0 END)   AS scheduled
FROM academic_groups g
LEFT JOIN students s      ON s.group_id    = g.group_id
LEFT JOIN exam_results er ON er.student_id = s.student_id
GROUP BY g.group_name
ORDER BY g.group_name;


-- 2.2.2 «трудные» курсы: средний балл ниже 4, и экзаменов по курсу было хотя бы 5
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


-- 2.2.3 сравнение по месяцам: сколько было попыток, средний балл, сколько пятёрок и неудач
-- неудача = двойка или неявка, назначенные и отменённые экзамены не считаем
SELECT
    EXTRACT(YEAR FROM er.exam_date)                                    AS year,
    EXTRACT(MONTH FROM er.exam_date)                                   AS month,
    COUNT(*)                                                           AS attempts,
    ROUND(AVG(er.grade), 2)                                            AS avg_grade,
    SUM(CASE WHEN er.grade = 5 THEN 1 ELSE 0 END)                      AS excellent,
    SUM(CASE WHEN er.grade = 2 OR er.status = 'absent' THEN 1 ELSE 0 END) AS fails,
    ROUND(100.0 * SUM(CASE WHEN er.grade = 2 OR er.status = 'absent' THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                               AS fail_pct
FROM exam_results er
WHERE er.status IN ('completed', 'absent')
GROUP BY EXTRACT(YEAR FROM er.exam_date), EXTRACT(MONTH FROM er.exam_date)
ORDER BY year, month;
