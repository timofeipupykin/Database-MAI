-- Итоги 2025/26 учебного года по группам:
-- средний итоговый балл, сколько студентов сдали всё с первого раза и сколько осталось должников.
--
-- attempts        - исходные данные: все попытки сдачи за учебный год
-- course_outcome  - промежуточные: итог по каждому курсу каждого студента
-- student_summary - промежуточные: итог по студенту
-- group_summary   - агрегация по группам
-- последний SELECT - итоговый отчёт

WITH
-- попытки за год (с 01.09.2025, вместе с осенними пересдачами до 30.09.2026)
-- назначенные и отменённые экзамены не берём
attempts AS (
    SELECT er.student_id, er.course_id, er.grade
    FROM exam_results er
    WHERE er.status IN ('completed', 'absent')
      AND er.exam_date BETWEEN DATE '2025-09-01' AND DATE '2026-09-30'
),

-- по каждому курсу студента: сколько попыток, лучшая оценка,
-- сдан ли курс и сдан ли с первого раза (1 = да, 0 = нет)
course_outcome AS (
    SELECT
        a.student_id,
        a.course_id,
        COUNT(*)                                                     AS attempts_cnt,
        MAX(a.grade)                                                 AS final_grade,
        CASE WHEN MAX(a.grade) >= 3 THEN 1 ELSE 0 END                AS passed,
        CASE WHEN COUNT(*) = 1 AND MAX(a.grade) >= 3 THEN 1 ELSE 0 END AS first_try
    FROM attempts a
    GROUP BY a.student_id, a.course_id
),

-- по каждому студенту: средний балл по сданным курсам, число долгов
-- и всё ли сдано с первого раза (MIN = 1 только если везде 1)
student_summary AS (
    SELECT
        co.student_id,
        AVG(CASE WHEN co.passed = 1 THEN co.final_grade END) AS avg_grade,
        COUNT(*) - SUM(co.passed)                            AS debts,
        MIN(co.first_try)                                    AS all_first_try
    FROM course_outcome co
    GROUP BY co.student_id
),

-- по каждой группе, LEFT JOIN чтобы учесть студентов и группы без экзаменов
group_summary AS (
    SELECT
        g.group_name,
        COUNT(s.student_id)                                  AS students_total,
        COUNT(ss.student_id)                                 AS students_examined,
        ROUND(AVG(ss.avg_grade), 2)                          AS group_avg_grade,
        COUNT(CASE WHEN ss.all_first_try = 1 THEN 1 END)     AS first_try_students,
        COUNT(CASE WHEN ss.debts > 0 THEN 1 END)             AS debtors
    FROM academic_groups g
    LEFT JOIN students s         ON s.group_id    = g.group_id
    LEFT JOIN student_summary ss ON ss.student_id = s.student_id
    GROUP BY g.group_name
)

-- итоговый отчёт, группы без экзаменов в конце
SELECT
    gs.group_name,
    gs.students_total,
    gs.students_examined,
    gs.group_avg_grade,
    gs.first_try_students,
    CASE WHEN gs.students_examined > 0
         THEN ROUND(100.0 * gs.first_try_students / gs.students_examined, 1)
    END                                                      AS first_try_pct,
    gs.debtors
FROM group_summary gs
ORDER BY gs.group_avg_grade DESC NULLS LAST;
