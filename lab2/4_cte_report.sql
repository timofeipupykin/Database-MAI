-- ЛР 2. Часть 4. Комплексный аналитический отчёт с использованием CTE.
--
-- Вопрос руководителя (замдекана по учебной работе):
-- «Как каждая группа прошла сессии 2025/26 учебного года: каков средний итоговый
--  балл, сколько студентов сдали всё с первого раза, сколько остаются должниками
--  и кто лучший студент группы?»
--
-- Схема вычислений:
--   attempts        (исходные данные)        - состоявшиеся попытки сдачи за учебный год
--   course_outcome  (промежуточные показатели) - итог по паре «студент-курс»
--   student_summary (промежуточные показатели) - итог по студенту
--   group_summary   (агрегация)              - показатели по группе
--   best_student    (агрегация)              - лучший студент в каждой группе
--   финальный SELECT (итоговый отчёт)        - все группы + рейтинг

WITH
-- 1. Исходные данные: только состоявшиеся попытки (оценка или неявка)
--    за 2025/26 учебный год, включая осенние пересдачи до 30.09.2026.
attempts AS (
    SELECT er.student_id, er.course_id, er.exam_date, er.grade, er.status
    FROM exam_results er
    WHERE er.status IN ('completed', 'absent')
      AND er.exam_date BETWEEN DATE '2025-09-01' AND DATE '2026-09-30'
),

-- 2. Итог по каждому курсу каждого студента:
--    число попыток, лучшая оценка, сдан ли курс и сдан ли с первой попытки.
course_outcome AS (
    SELECT
        a.student_id,
        a.course_id,
        COUNT(*)                                       AS attempts_cnt,
        MAX(a.grade)                                   AS final_grade,   -- NULL, если были только неявки
        COALESCE(MAX(a.grade), 0) >= 3                 AS is_passed,
        COUNT(*) = 1 AND COALESCE(MAX(a.grade), 0) >= 3 AS passed_first_try
    FROM attempts a
    GROUP BY a.student_id, a.course_id
),

-- 3. Итог по студенту: средний итоговый балл по сданным курсам,
--    количество долгов, все ли курсы сданы с первого раза.
student_summary AS (
    SELECT
        co.student_id,
        COUNT(*)                                       AS courses_cnt,
        AVG(co.final_grade) FILTER (WHERE co.is_passed) AS avg_final_grade,
        COUNT(*) FILTER (WHERE NOT co.is_passed)       AS debts_cnt,
        BOOL_AND(co.passed_first_try)                  AS all_first_try,
        SUM(co.attempts_cnt)                           AS attempts_cnt
    FROM course_outcome co
    GROUP BY co.student_id
),

-- 4. Агрегация по группам. LEFT JOIN - чтобы учесть студентов без экзаменов.
group_summary AS (
    SELECT
        g.group_id,
        g.group_name,
        COUNT(s.student_id)                                    AS students_total,
        COUNT(ss.student_id)                                   AS students_examined,
        ROUND(AVG(ss.avg_final_grade), 2)                      AS group_avg_grade,
        COUNT(*) FILTER (WHERE ss.all_first_try)               AS first_try_students,
        COUNT(*) FILTER (WHERE ss.debts_cnt > 0)               AS debtors,
        COALESCE(SUM(ss.debts_cnt), 0)                         AS debts_total,
        ROUND(AVG(ss.attempts_cnt::numeric / ss.courses_cnt), 2) AS attempts_per_course
    FROM academic_groups g
    LEFT JOIN students s         ON s.group_id    = g.group_id
    LEFT JOIN student_summary ss ON ss.student_id = s.student_id
    GROUP BY g.group_id, g.group_name
),

-- 5. Лучший студент группы: максимальный средний балл, без долгов.
best_student AS (
    SELECT DISTINCT ON (s.group_id)
        s.group_id,
        s.last_name || ' ' || s.first_name || ' (' || ROUND(ss.avg_final_grade, 2) || ')' AS best_student
    FROM student_summary ss
    JOIN students s ON s.student_id = ss.student_id
    WHERE ss.debts_cnt = 0
    ORDER BY s.group_id, ss.avg_final_grade DESC, s.last_name
)

-- 6. Итоговый отчёт
SELECT
    RANK() OVER (ORDER BY gs.group_avg_grade DESC NULLS LAST) AS rating,
    gs.group_name,
    gs.students_total,
    gs.students_examined,
    gs.group_avg_grade,
    gs.first_try_students,
    ROUND(100.0 * gs.first_try_students / NULLIF(gs.students_examined, 0), 1) AS first_try_pct,
    gs.debtors,
    gs.debts_total,
    gs.attempts_per_course,
    COALESCE(bs.best_student, '-')                             AS best_student
FROM group_summary gs
LEFT JOIN best_student bs ON bs.group_id = gs.group_id
ORDER BY rating, gs.group_name;
