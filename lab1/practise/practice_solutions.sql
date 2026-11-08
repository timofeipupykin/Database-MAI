-- Решения к PRACTICE.md. Сначала попробуй сам!
-- Запуск: psql -U postgres -h localhost -d lab1 -f practice_solutions.sql


-- ============================================================
-- Задание 1. Сложность курсов относительно своей кафедры
-- ============================================================
WITH course_stats AS (
    SELECT
        c.course_id,
        c.course_name,
        COALESCE(p.department, 'Без кафедры')                       AS department,
        COUNT(*)                                                     AS attempts,
        ROUND(AVG(er.grade), 2)                                      AS course_avg,
        ROUND(100.0 * SUM(CASE WHEN er.grade = 2 OR er.status = 'absent'
                               THEN 1 ELSE 0 END) / COUNT(*), 1)     AS fail_pct
    FROM courses c
    LEFT JOIN professors p ON p.professor_id = c.professor_id      -- у Философии нет преподавателя
    JOIN exam_results er   ON er.course_id   = c.course_id
    WHERE er.status IN ('completed', 'absent')
    GROUP BY c.course_id, c.course_name, p.department
    HAVING COUNT(*) >= 3
),
dept_avg AS (
    -- среднее по ВСЕМ оценкам кафедры, а не среднее из средних курсов
    SELECT
        COALESCE(p.department, 'Без кафедры') AS department,
        ROUND(AVG(er.grade), 2)               AS dept_avg
    FROM exam_results er
    JOIN courses c         ON c.course_id    = er.course_id
    LEFT JOIN professors p ON p.professor_id = c.professor_id
    WHERE er.status = 'completed'
    GROUP BY COALESCE(p.department, 'Без кафедры')
)
SELECT
    cs.department,
    cs.course_name,
    cs.attempts,
    cs.course_avg,
    d.dept_avg,
    cs.course_avg - d.dept_avg AS deviation,
    cs.fail_pct,
    CASE
        WHEN cs.course_avg - d.dept_avg <= -0.1 THEN 'сложнее кафедры'
        WHEN cs.course_avg - d.dept_avg >=  0.1 THEN 'проще кафедры'
        ELSE 'как по кафедре'
    END                         AS verdict
FROM course_stats cs
JOIN dept_avg d ON d.department = cs.department
ORDER BY cs.department, deviation;


-- ============================================================
-- Задание 2. Нагрузка преподавателей
-- ============================================================
WITH course_avg AS (
    SELECT c.professor_id, c.course_name, AVG(er.grade) AS avg_grade
    FROM courses c
    JOIN exam_results er ON er.course_id = c.course_id
    WHERE er.status = 'completed'
    GROUP BY c.professor_id, c.course_id, c.course_name
),
hardest AS (
    -- курс с минимальным средним среди курсов этого же преподавателя
    SELECT ca.professor_id, ca.course_name
    FROM course_avg ca
    WHERE ca.avg_grade = (SELECT MIN(ca2.avg_grade)
                          FROM course_avg ca2
                          WHERE ca2.professor_id = ca.professor_id)
),
prof_stats AS (
    SELECT
        p.professor_id,
        p.last_name || ' ' || p.first_name                AS professor,
        p.department,
        COUNT(DISTINCT c.course_id)                       AS courses_cnt,
        COUNT(er.grade)                                   AS exams_taken,
        COUNT(DISTINCT er.student_id)                     AS students_cnt,
        ROUND(AVG(er.grade), 2)                           AS avg_given,
        SUM(CASE WHEN er.grade = 2 THEN 1 ELSE 0 END)     AS twos
    FROM professors p
    LEFT JOIN courses c       ON c.professor_id = p.professor_id
    -- фильтр статуса в ON, а не в WHERE: иначе WHERE выкинет Волкову (у неё er.status = NULL)
    LEFT JOIN exam_results er ON er.course_id   = c.course_id
                             AND er.status      = 'completed'
    GROUP BY p.professor_id, p.last_name, p.first_name, p.department
)
SELECT
    ps.professor,
    ps.department,
    ps.courses_cnt,
    ps.exams_taken,
    ps.students_cnt,
    ps.avg_given,
    CASE WHEN ps.exams_taken > 0
         THEN ROUND(100.0 * ps.twos / ps.exams_taken, 1)
    END                                    AS twos_pct,
    COALESCE(h.course_name, '—')           AS hardest_course
FROM prof_stats ps
LEFT JOIN hardest h ON h.professor_id = ps.professor_id
ORDER BY ps.exams_taken DESC, ps.professor;


-- ============================================================
-- Задание 3. Зимняя сессия против летней по группам
-- ============================================================
WITH tagged AS (
    SELECT
        er.student_id,
        er.grade,
        er.status,
        CASE
            WHEN er.exam_date BETWEEN DATE '2025-12-01' AND DATE '2026-03-31' THEN 'winter'
            WHEN er.exam_date BETWEEN DATE '2026-06-01' AND DATE '2026-10-31' THEN 'summer'
        END AS season
    FROM exam_results er
    WHERE er.status IN ('completed', 'absent')
),
group_season AS (
    SELECT
        g.group_name,
        ROUND(AVG(CASE WHEN t.season = 'winter' THEN t.grade END), 2)          AS winter_avg,
        ROUND(AVG(CASE WHEN t.season = 'summer' THEN t.grade END), 2)          AS summer_avg,
        SUM(CASE WHEN t.season = 'winter'
                  AND (t.grade = 2 OR t.status = 'absent') THEN 1 ELSE 0 END)  AS winter_fails,
        SUM(CASE WHEN t.season = 'summer'
                  AND (t.grade = 2 OR t.status = 'absent') THEN 1 ELSE 0 END)  AS summer_fails
    FROM academic_groups g
    LEFT JOIN students s ON s.group_id   = g.group_id
    LEFT JOIN tagged t   ON t.student_id = s.student_id
    GROUP BY g.group_name
)
SELECT
    gs.*,
    gs.summer_avg - gs.winter_avg AS delta,
    CASE
        WHEN gs.winter_avg IS NULL OR gs.summer_avg IS NULL THEN 'нет данных'
        WHEN gs.summer_avg > gs.winter_avg THEN 'лучше'
        WHEN gs.summer_avg < gs.winter_avg THEN 'хуже'
        ELSE 'так же'
    END                           AS trend
FROM group_season gs
ORDER BY delta DESC NULLS LAST;


-- ============================================================
-- Задание 4. Неудачи студентов: что закрыто, что висит
-- ============================================================
WITH failures AS (
    -- одна строка = пара (студент, курс), где была хоть одна неудача
    SELECT
        er.student_id,
        er.course_id,
        COUNT(*)          AS fail_cnt,
        MAX(er.exam_date) AS last_fail
    FROM exam_results er
    WHERE er.grade = 2 OR er.status = 'absent'
    GROUP BY er.student_id, er.course_id
)
SELECT
    g.group_name,
    s.last_name || ' ' || s.first_name                     AS student,
    COUNT(*)                                               AS failed_courses,
    SUM(CASE WHEN EXISTS (
            SELECT 1
            FROM exam_results r
            WHERE r.student_id = f.student_id
              AND r.course_id  = f.course_id
              AND r.exam_date  > f.last_fail
              AND r.grade >= 3
        ) THEN 1 ELSE 0 END)                               AS closed,
    SUM(CASE WHEN NOT EXISTS (
            SELECT 1
            FROM exam_results r
            WHERE r.student_id = f.student_id
              AND r.course_id  = f.course_id
              AND r.exam_date  > f.last_fail
              AND r.grade >= 3
        ) THEN 1 ELSE 0 END)                               AS still_open,
    SUM(f.fail_cnt)                                        AS wasted_attempts,
    MAX(f.last_fail)                                       AS last_fail
FROM failures f
JOIN students s        ON s.student_id = f.student_id
JOIN academic_groups g ON g.group_id   = s.group_id
GROUP BY g.group_name, s.student_id, s.last_name, s.first_name
ORDER BY still_open DESC, wasted_attempts DESC, student;


-- ============================================================
-- Задание 5. Взвешенный по кредитам средний балл
-- ============================================================
WITH final_grades AS (
    SELECT er.student_id, er.course_id, MAX(er.grade) AS final_grade
    FROM exam_results er
    WHERE er.status = 'completed'
    GROUP BY er.student_id, er.course_id
    HAVING MAX(er.grade) >= 3
),
student_gpa AS (
    SELECT
        fg.student_id,
        COUNT(*)                                                       AS courses_passed,
        SUM(c.credits)                                                 AS credits_earned,
        ROUND(AVG(fg.final_grade), 2)                                  AS simple_avg,
        ROUND(1.0 * SUM(fg.final_grade * c.credits) / SUM(c.credits), 2) AS weighted_avg
    FROM final_grades fg
    JOIN courses c ON c.course_id = fg.course_id
    GROUP BY fg.student_id
)
SELECT
    g.group_name,
    s.last_name || ' ' || s.first_name   AS student,
    sg.courses_passed,
    sg.credits_earned,
    sg.simple_avg,
    sg.weighted_avg,
    sg.weighted_avg - sg.simple_avg      AS diff
FROM student_gpa sg
JOIN students s        ON s.student_id = sg.student_id
JOIN academic_groups g ON g.group_id   = s.group_id
WHERE ABS(sg.weighted_avg - sg.simple_avg) >= 0.1
ORDER BY ABS(sg.weighted_avg - sg.simple_avg) DESC, student;


-- ============================================================
-- Оконное 1. Накопительный итог по месяцам
-- ============================================================
WITH monthly AS (
    SELECT
        EXTRACT(YEAR  FROM er.exam_date)                  AS y,
        EXTRACT(MONTH FROM er.exam_date)                  AS m,
        COUNT(*)                                          AS exams,
        SUM(CASE WHEN er.grade >= 3 THEN 1 ELSE 0 END)    AS passed,
        SUM(er.grade)                                     AS grade_sum
    FROM exam_results er
    WHERE er.status = 'completed'
    GROUP BY EXTRACT(YEAR FROM er.exam_date), EXTRACT(MONTH FROM er.exam_date)
)
SELECT
    y, m, exams, passed,
    SUM(passed) OVER (ORDER BY y, m)                                   AS passed_running,
    ROUND(100.0 * SUM(passed) OVER (ORDER BY y, m)
                / SUM(exams)  OVER (ORDER BY y, m), 1)                 AS pass_pct_running,
    ROUND(1.0 * SUM(grade_sum) OVER (ORDER BY y, m)
              / SUM(exams)     OVER (ORDER BY y, m), 2)                AS avg_running
FROM monthly
ORDER BY y, m;


-- ============================================================
-- Оконное 2. Накопленные кредиты студента
-- ============================================================
-- (а) хронология закрытия курсов
WITH closed AS (
    -- дата закрытия курса = первая положительная оценка
    SELECT er.student_id, er.course_id, MIN(er.exam_date) AS closed_on
    FROM exam_results er
    WHERE er.grade >= 3
    GROUP BY er.student_id, er.course_id
),
progress AS (
    SELECT
        cl.student_id,
        c.course_name,
        cl.closed_on,
        c.credits,
        ROW_NUMBER() OVER (PARTITION BY cl.student_id
                           ORDER BY cl.closed_on, c.course_name)        AS n,
        SUM(c.credits) OVER (PARTITION BY cl.student_id
                             ORDER BY cl.closed_on, c.course_name
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS credits_total
    FROM closed cl
    JOIN courses c ON c.course_id = cl.course_id
)
SELECT s.last_name || ' ' || s.first_name AS student, p.n, p.course_name, p.closed_on, p.credits, p.credits_total
FROM progress p
JOIN students s ON s.student_id = p.student_id
ORDER BY student, p.n;

-- (б) когда каждый студент перешагнул 15 кредитов
WITH closed AS (
    SELECT er.student_id, er.course_id, MIN(er.exam_date) AS closed_on
    FROM exam_results er
    WHERE er.grade >= 3
    GROUP BY er.student_id, er.course_id
),
progress AS (
    SELECT
        cl.student_id,
        cl.closed_on,
        SUM(c.credits) OVER (PARTITION BY cl.student_id
                             ORDER BY cl.closed_on, c.course_name
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS credits_total
    FROM closed cl
    JOIN courses c ON c.course_id = cl.course_id
)
SELECT
    g.group_name,
    s.last_name || ' ' || s.first_name AS student,
    MIN(p.closed_on)                   AS reached_15_on
FROM progress p
JOIN students s        ON s.student_id = p.student_id
JOIN academic_groups g ON g.group_id   = s.group_id
WHERE p.credits_total >= 15            -- окно уже посчитано в CTE, поэтому тут фильтровать можно
GROUP BY g.group_name, s.student_id, s.last_name, s.first_name
ORDER BY reached_15_on, student;


-- ============================================================
-- Оконное 3. Топ-3 каждой группы
-- ============================================================
WITH student_avg AS (
    SELECT
        g.group_name,
        s.last_name || ' ' || s.first_name AS student,
        ROUND(AVG(er.grade), 2)            AS avg_grade
    FROM students s
    JOIN academic_groups g ON g.group_id   = s.group_id
    JOIN exam_results er   ON er.student_id = s.student_id
    WHERE er.status = 'completed'
    GROUP BY g.group_name, s.student_id, s.last_name, s.first_name
),
ranked AS (
    SELECT
        sa.*,
        DENSE_RANK() OVER (PARTITION BY sa.group_name ORDER BY sa.avg_grade DESC)          AS place,
        MAX(sa.avg_grade) OVER (PARTITION BY sa.group_name) - sa.avg_grade                AS behind_leader,
        LAG(sa.avg_grade) OVER (PARTITION BY sa.group_name
                                ORDER BY sa.avg_grade DESC, sa.student) - sa.avg_grade    AS behind_prev
    FROM student_avg sa
)
SELECT group_name, place, student, avg_grade, behind_leader, behind_prev
FROM ranked
WHERE place <= 3
ORDER BY group_name, place, student;


-- ============================================================
-- Оконное 4. История попыток
-- ============================================================
WITH tries AS (
    SELECT
        er.student_id,
        er.course_id,
        er.exam_date,
        er.grade,
        ROW_NUMBER() OVER (PARTITION BY er.student_id, er.course_id ORDER BY er.exam_date) AS try_no,
        COUNT(*)     OVER (PARTITION BY er.student_id, er.course_id)                       AS tries_total,
        LAG(er.grade) OVER (PARTITION BY er.student_id, er.course_id ORDER BY er.exam_date) AS prev_grade
    FROM exam_results er
    WHERE er.status IN ('completed', 'absent')
)
SELECT
    s.last_name || ' ' || s.first_name                  AS student,
    c.course_name,
    t.try_no || ' из ' || t.tries_total                 AS try,
    t.exam_date,
    COALESCE(CAST(t.grade AS VARCHAR), 'неявка')        AS result,
    CASE
        WHEN t.try_no = 1                     THEN 'первая попытка'
        WHEN t.grade IS NULL                  THEN 'не пришёл'
        WHEN t.prev_grade IS NULL             THEN 'пришёл после неявки'
        WHEN t.grade > t.prev_grade           THEN 'лучше'
        WHEN t.grade < t.prev_grade           THEN 'хуже'
        ELSE 'так же'
    END                                                 AS dynamics
FROM tries t
JOIN students s ON s.student_id = t.student_id
JOIN courses  c ON c.course_id  = t.course_id
WHERE t.tries_total > 1
ORDER BY student, c.course_name, t.try_no;


-- ============================================================
-- Оконное 5 (бонус). Задание 3.1 без коррелированного подзапроса
-- ============================================================
WITH per_student AS (
    SELECT
        g.group_name,
        s.last_name || ' ' || s.first_name                AS student,
        AVG(er.grade)                                     AS student_avg,
        -- среднее по всем оценкам группы = сумма оценок группы / их количество
        1.0 * SUM(SUM(er.grade))   OVER (PARTITION BY g.group_id)
            / SUM(COUNT(er.grade)) OVER (PARTITION BY g.group_id) AS group_avg
    FROM students s
    JOIN academic_groups g ON g.group_id   = s.group_id
    JOIN exam_results er   ON er.student_id = s.student_id
    WHERE er.status = 'completed'
    GROUP BY g.group_id, g.group_name, s.student_id, s.last_name, s.first_name
)
SELECT group_name, student, ROUND(student_avg, 2) AS student_avg, ROUND(group_avg, 2) AS group_avg
FROM per_student
WHERE student_avg > group_avg
ORDER BY group_name, student_avg DESC;
