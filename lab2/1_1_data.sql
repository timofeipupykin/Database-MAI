-- ЛР 2. Задание 1.1. Дополнение базы содержательным набором данных.
-- Ссылки на группы/студентов/курсы ищутся по естественным ключам
-- (group_name, email, course_name), а не по числовым id: после неудачных
-- INSERT из constraints_test.sql счётчики SERIAL могли «сдвинуться».

-- ---------- Группы ----------
-- ПМИ-108 - первокурсники 2026 г.: экзаменов у них ещё не было (нет связанных операций)
INSERT INTO academic_groups (group_name, enrollment_year) VALUES
('ПМИ-206', 2025),
('ПМИ-406', 2023),
('ПМИ-108', 2026)
ON CONFLICT (group_name) DO NOTHING;

-- ---------- Преподаватели ----------
-- Волкова пока не ведёт ни одного курса
INSERT INTO professors (first_name, last_name, department) VALUES
('Ольга', 'Кузнецова', 'Кафедра вычислительной математики и программирования'),
('Андрей', 'Соколов', 'Кафедра теории вероятностей'),
('Мария', 'Волкова', 'Кафедра иностранных языков');

-- ---------- Курсы ----------
-- «Философия» без преподавателя (professor_id = NULL), минимальные кредиты;
-- «Машинное обучение» - курс, по которому ещё не было экзаменов
INSERT INTO courses (course_name, credits, professor_id) VALUES
('Базы данных',          5, (SELECT professor_id FROM professors WHERE last_name = 'Кузнецова')),
('Теория вероятностей',  6, (SELECT professor_id FROM professors WHERE last_name = 'Соколов')),
('Линейная алгебра',     5, (SELECT professor_id FROM professors WHERE last_name = 'Битюков')),
('Операционные системы', 4, (SELECT professor_id FROM professors WHERE last_name = 'Кузнецова')),
('Философия',            1, NULL),
('Машинное обучение',    4, (SELECT professor_id FROM professors WHERE last_name = 'Соколов'));

-- ---------- Студенты ----------
INSERT INTO students (first_name, last_name, email, group_id, birth_date)
SELECT v.first_name, v.last_name, v.email, g.group_id, v.birth_date::date
FROM (VALUES
    ('Анна',     'Орлова',     'anna.orlova@example.com',        'ПМИ-306', '2006-03-12'),
    ('Дмитрий',  'Козлов',     'dmitry.kozlov@example.com',      'ПМИ-306', '2005-09-30'),
    ('Елена',    'Морозова',   'elena.morozova@example.com',     'ПМИ-306', '2006-07-04'),
    ('Сергей',   'Новиков',    'sergey.novikov@example.com',     'ПМИ-306', '2005-12-01'),
    ('Ксения',   'Лебедева',   'ksenia.lebedeva@example.com',    'ПМИ-306', '2006-01-19'), -- переведена, экзаменов нет
    ('Мария',    'Павлова',    'maria.pavlova@example.com',      'ПМИ-307', '2006-04-22'),
    ('Артём',    'Семёнов',    'artem.semenov@example.com',      'ПМИ-307', '2005-10-15'),
    ('Ольга',    'Фёдорова',   'olga.fedorova@example.com',      'ПМИ-307', '2006-08-09'),
    ('Никита',   'Егоров',     'nikita.egorov@example.com',      'ПМИ-307', '2006-02-27'),
    ('Полина',   'Николаева',  'polina.nikolaeva@example.com',   'ПМИ-307', '2006-06-13'),
    ('Алексей',  'Петров',     'alexey.petrov@example.com',      'ПМИ-206', '2007-01-01'),
    ('Виктория', 'Соловьёва',  'victoria.solovyova@example.com', 'ПМИ-206', '2007-05-18'),
    ('Максим',   'Васильев',   'maxim.vasiliev@example.com',     'ПМИ-206', '2006-11-11'),
    ('Дарья',    'Зайцева',    'darya.zaitseva@example.com',     'ПМИ-206', '2007-03-03'),
    ('Кирилл',   'Михайлов',   'kirill.mikhailov@example.com',   'ПМИ-206', '2007-02-14'),
    ('Софья',    'Белова',     'sofya.belova@example.com',       'ПМИ-206', '2007-07-21'),
    ('Роман',    'Григорьев',  'roman.grigoriev@example.com',    'ПМИ-406', '2005-04-05'),
    ('Алина',    'Романова',   'alina.romanova@example.com',     'ПМИ-406', '2005-08-28'),
    ('Павел',    'Тихонов',    'pavel.tikhonov@example.com',     'ПМИ-406', '2004-12-17'),
    ('Юлия',     'Кудрявцева', 'yulia.kudryavtseva@example.com', 'ПМИ-406', '2005-06-06'),
    ('Глеб',     'Баранов',    'gleb.baranov@example.com',       'ПМИ-406', '2005-01-25'),
    ('Ева',      'Киселёва',   'eva.kiseleva@example.com',       'ПМИ-108', '2008-02-02'),
    ('Марк',     'Андреев',    'mark.andreev@example.com',       'ПМИ-108', '2008-09-10'),
    ('Вера',     'Захарова',   'vera.zakharova@example.com',     'ПМИ-108', '2008-05-30')
) AS v(first_name, last_name, email, group_name, birth_date)
JOIN academic_groups g ON g.group_name = v.group_name;

-- ---------- Результаты экзаменов ----------
-- Сессии: досрочная сдача (декабрь 2025), зимняя (январь 2026), пересдачи
-- (февраль-март 2026), летняя (июнь 2026), осенние пересдачи (сентябрь 2026),
-- назначенные экзамены (ноябрь 2026 - январь 2027).
INSERT INTO exam_results (student_id, course_id, exam_date, grade, status)
SELECT s.student_id, c.course_id, v.exam_date::date, v.grade, v.status
FROM (VALUES
    -- ПМИ-306
    ('tim.pup@example.com',        'Дискретный Анализ',            '2025-12-25', 5,    'completed'),
    ('tim.pup@example.com',        'Базы данных',                  '2026-06-15', 5,    'completed'),
    ('tim.pup@example.com',        'Теория вероятностей',          '2026-06-20', 4,    'completed'),
    ('tim.pup@example.com',        'Операционные системы',         '2027-01-15', NULL, 'scheduled'),

    ('john.smit@example.com',      'Математический анализ',        '2026-01-20', 2,    'completed'),
    ('john.smit@example.com',      'Математический анализ',        '2026-02-10', NULL, 'absent'),
    ('john.smit@example.com',      'Математический анализ',        '2026-02-20', 3,    'completed'),
    ('john.smit@example.com',      'Дискретный Анализ',            '2026-01-25', 4,    'completed'),
    ('john.smit@example.com',      'Базы данных',                  '2026-06-15', 3,    'completed'),
    ('john.smit@example.com',      'Теория вероятностей',          '2026-06-20', NULL, 'absent'),
    ('john.smit@example.com',      'Теория вероятностей',          '2026-09-15', 3,    'completed'),

    ('anna.orlova@example.com',    'Алгоритмы и структуры данных', '2026-01-15', 5,    'completed'),
    ('anna.orlova@example.com',    'Математический анализ',        '2026-01-20', 5,    'completed'),
    ('anna.orlova@example.com',    'Дискретный Анализ',            '2026-01-25', 5,    'completed'),
    ('anna.orlova@example.com',    'Базы данных',                  '2026-06-15', 5,    'completed'),
    ('anna.orlova@example.com',    'Теория вероятностей',          '2026-06-20', 5,    'completed'),
    ('anna.orlova@example.com',    'Операционные системы',         '2027-01-15', NULL, 'scheduled'),

    ('dmitry.kozlov@example.com',  'Алгоритмы и структуры данных', '2026-01-15', 2,    'completed'),
    ('dmitry.kozlov@example.com',  'Алгоритмы и структуры данных', '2026-02-10', 2,    'completed'),
    ('dmitry.kozlov@example.com',  'Алгоритмы и структуры данных', '2026-02-20', 3,    'completed'),
    ('dmitry.kozlov@example.com',  'Математический анализ',        '2026-01-20', 3,    'completed'),
    ('dmitry.kozlov@example.com',  'Дискретный Анализ',            '2026-01-25', NULL, 'absent'),
    ('dmitry.kozlov@example.com',  'Дискретный Анализ',            '2026-02-12', 4,    'completed'),
    ('dmitry.kozlov@example.com',  'Базы данных',                  '2026-06-15', 4,    'completed'),
    ('dmitry.kozlov@example.com',  'Теория вероятностей',          '2026-06-20', 3,    'completed'),

    ('elena.morozova@example.com', 'Алгоритмы и структуры данных', '2026-01-15', 4,    'completed'),
    ('elena.morozova@example.com', 'Математический анализ',        '2026-01-20', 4,    'completed'),
    ('elena.morozova@example.com', 'Дискретный Анализ',            '2026-01-25', 4,    'completed'),
    ('elena.morozova@example.com', 'Базы данных',                  '2026-06-10', NULL, 'cancelled'),
    ('elena.morozova@example.com', 'Базы данных',                  '2026-06-15', 5,    'completed'),
    ('elena.morozova@example.com', 'Теория вероятностей',          '2026-06-20', 4,    'completed'),

    ('sergey.novikov@example.com', 'Алгоритмы и структуры данных', '2026-01-15', NULL, 'absent'),
    ('sergey.novikov@example.com', 'Алгоритмы и структуры данных', '2026-02-10', 4,    'completed'),
    ('sergey.novikov@example.com', 'Математический анализ',        '2026-01-20', 3,    'completed'),
    ('sergey.novikov@example.com', 'Дискретный Анализ',            '2026-01-25', 3,    'completed'),
    ('sergey.novikov@example.com', 'Базы данных',                  '2026-06-15', 2,    'completed'),
    ('sergey.novikov@example.com', 'Базы данных',                  '2026-09-15', 3,    'completed'),
    ('sergey.novikov@example.com', 'Теория вероятностей',          '2026-06-20', 2,    'completed'),
    ('sergey.novikov@example.com', 'Теория вероятностей',          '2026-11-10', NULL, 'scheduled'),

    -- ПМИ-307
    ('ivan.iv@example.com',        'Алгоритмы и структуры данных', '2026-01-15', 4,    'completed'),
    ('ivan.iv@example.com',        'Дискретный Анализ',            '2026-01-25', 5,    'completed'),
    ('ivan.iv@example.com',        'Базы данных',                  '2026-06-15', 4,    'completed'),
    ('ivan.iv@example.com',        'Теория вероятностей',          '2026-06-20', 5,    'completed'),

    ('maria.pavlova@example.com',  'Алгоритмы и структуры данных', '2026-01-15', 5,    'completed'),
    ('maria.pavlova@example.com',  'Математический анализ',        '2026-01-20', 4,    'completed'),
    ('maria.pavlova@example.com',  'Дискретный Анализ',            '2026-01-25', 5,    'completed'),
    ('maria.pavlova@example.com',  'Базы данных',                  '2026-06-15', 5,    'completed'),
    ('maria.pavlova@example.com',  'Теория вероятностей',          '2026-06-20', 5,    'completed'),

    ('artem.semenov@example.com',  'Алгоритмы и структуры данных', '2026-01-15', 3,    'completed'),
    ('artem.semenov@example.com',  'Математический анализ',        '2026-01-20', 2,    'completed'),
    ('artem.semenov@example.com',  'Математический анализ',        '2026-02-10', 2,    'completed'),
    ('artem.semenov@example.com',  'Математический анализ',        '2026-02-20', NULL, 'absent'),
    ('artem.semenov@example.com',  'Дискретный Анализ',            '2026-01-25', 3,    'completed'),
    ('artem.semenov@example.com',  'Базы данных',                  '2026-06-15', NULL, 'cancelled'),
    ('artem.semenov@example.com',  'Базы данных',                  '2026-06-25', 3,    'completed'),

    ('olga.fedorova@example.com',  'Алгоритмы и структуры данных', '2026-01-15', 4,    'completed'),
    ('olga.fedorova@example.com',  'Математический анализ',        '2026-01-20', 5,    'completed'),
    ('olga.fedorova@example.com',  'Дискретный Анализ',            '2026-01-25', 4,    'completed'),
    ('olga.fedorova@example.com',  'Базы данных',                  '2026-06-15', 4,    'completed'),
    ('olga.fedorova@example.com',  'Теория вероятностей',          '2026-06-20', 4,    'completed'),

    ('nikita.egorov@example.com',  'Алгоритмы и структуры данных', '2026-01-15', NULL, 'absent'),
    ('nikita.egorov@example.com',  'Алгоритмы и структуры данных', '2026-02-10', NULL, 'absent'),
    ('nikita.egorov@example.com',  'Математический анализ',        '2026-01-20', 3,    'completed'),
    ('nikita.egorov@example.com',  'Дискретный Анализ',            '2026-01-25', 2,    'completed'),
    ('nikita.egorov@example.com',  'Дискретный Анализ',            '2026-02-12', 3,    'completed'),

    ('polina.nikolaeva@example.com', 'Алгоритмы и структуры данных', '2026-01-15', 5,  'completed'),
    ('polina.nikolaeva@example.com', 'Математический анализ',        '2026-01-20', 5,  'completed'),
    ('polina.nikolaeva@example.com', 'Дискретный Анализ',            '2025-12-25', 5,  'completed'),
    ('polina.nikolaeva@example.com', 'Базы данных',                  '2026-06-15', 4,  'completed'),

    -- ПМИ-206
    ('alexey.petrov@example.com',  'Математический анализ',        '2026-01-22', 4,    'completed'),
    ('alexey.petrov@example.com',  'Линейная алгебра',             '2026-01-27', 5,    'completed'),
    ('alexey.petrov@example.com',  'Философия',                    '2025-12-26', 5,    'completed'),
    ('alexey.petrov@example.com',  'Алгоритмы и структуры данных', '2026-06-18', 4,    'completed'),

    ('victoria.solovyova@example.com', 'Математический анализ',        '2026-01-22', 5, 'completed'),
    ('victoria.solovyova@example.com', 'Линейная алгебра',             '2026-01-27', 5, 'completed'),
    ('victoria.solovyova@example.com', 'Философия',                    '2025-12-26', 4, 'completed'),
    ('victoria.solovyova@example.com', 'Алгоритмы и структуры данных', '2026-06-18', 5, 'completed'),

    ('maxim.vasiliev@example.com', 'Математический анализ',        '2026-01-22', 2,    'completed'),
    ('maxim.vasiliev@example.com', 'Математический анализ',        '2026-02-15', 3,    'completed'),
    ('maxim.vasiliev@example.com', 'Линейная алгебра',             '2026-01-27', 3,    'completed'),
    ('maxim.vasiliev@example.com', 'Философия',                    '2025-12-26', 3,    'completed'),
    ('maxim.vasiliev@example.com', 'Алгоритмы и структуры данных', '2026-06-18', 2,    'completed'),

    ('darya.zaitseva@example.com', 'Математический анализ',        '2026-01-22', 3,    'completed'),
    ('darya.zaitseva@example.com', 'Линейная алгебра',             '2026-01-27', 4,    'completed'),
    ('darya.zaitseva@example.com', 'Философия',                    '2025-12-26', NULL, 'absent'),
    ('darya.zaitseva@example.com', 'Философия',                    '2026-02-15', 4,    'completed'),
    ('darya.zaitseva@example.com', 'Алгоритмы и структуры данных', '2026-06-18', 4,    'completed'),

    ('kirill.mikhailov@example.com', 'Математический анализ',        '2026-01-22', NULL, 'absent'),
    ('kirill.mikhailov@example.com', 'Математический анализ',        '2026-02-15', 2,    'completed'),
    ('kirill.mikhailov@example.com', 'Линейная алгебра',             '2026-01-27', 2,    'completed'),
    ('kirill.mikhailov@example.com', 'Линейная алгебра',             '2026-02-17', 3,    'completed'),
    ('kirill.mikhailov@example.com', 'Философия',                    '2025-12-26', 3,    'completed'),
    ('kirill.mikhailov@example.com', 'Алгоритмы и структуры данных', '2026-06-18', NULL, 'cancelled'),
    ('kirill.mikhailov@example.com', 'Алгоритмы и структуры данных', '2026-11-12', NULL, 'scheduled'),

    ('sofya.belova@example.com',   'Математический анализ',        '2026-01-22', 5,    'completed'),
    ('sofya.belova@example.com',   'Линейная алгебра',             '2026-01-27', 4,    'completed'),
    ('sofya.belova@example.com',   'Философия',                    '2025-12-26', 5,    'completed'),
    ('sofya.belova@example.com',   'Алгоритмы и структуры данных', '2026-06-18', 5,    'completed'),

    -- ПМИ-406
    ('roman.grigoriev@example.com',    'Операционные системы', '2025-12-20', 5,    'completed'),
    ('roman.grigoriev@example.com',    'Теория вероятностей',  '2026-01-18', 4,    'completed'),
    ('roman.grigoriev@example.com',    'Базы данных',          '2026-01-23', 5,    'completed'),

    ('alina.romanova@example.com',     'Операционные системы', '2025-12-20', 4,    'completed'),
    ('alina.romanova@example.com',     'Теория вероятностей',  '2026-01-18', 3,    'completed'),
    ('alina.romanova@example.com',     'Базы данных',          '2026-01-23', 4,    'completed'),

    ('pavel.tikhonov@example.com',     'Операционные системы', '2025-12-20', 3,    'completed'),
    ('pavel.tikhonov@example.com',     'Теория вероятностей',  '2026-01-18', 2,    'completed'),
    ('pavel.tikhonov@example.com',     'Теория вероятностей',  '2026-02-14', 4,    'completed'),
    ('pavel.tikhonov@example.com',     'Базы данных',          '2026-01-23', 3,    'completed'),

    ('yulia.kudryavtseva@example.com', 'Операционные системы', '2025-12-20', 5,    'completed'),
    ('yulia.kudryavtseva@example.com', 'Теория вероятностей',  '2026-01-18', 5,    'completed'),
    ('yulia.kudryavtseva@example.com', 'Базы данных',          '2026-01-23', 5,    'completed'),

    ('gleb.baranov@example.com',       'Операционные системы', '2025-12-20', NULL, 'absent'),
    ('gleb.baranov@example.com',       'Операционные системы', '2026-02-11', 3,    'completed'),
    ('gleb.baranov@example.com',       'Теория вероятностей',  '2026-01-18', 3,    'completed'),
    ('gleb.baranov@example.com',       'Базы данных',          '2026-01-23', 2,    'completed'),
    ('gleb.baranov@example.com',       'Базы данных',          '2026-02-16', NULL, 'cancelled'),
    ('gleb.baranov@example.com',       'Базы данных',          '2026-03-02', 3,    'completed')
) AS v(email, course_name, exam_date, grade, status)
JOIN students s ON s.email = v.email
JOIN courses  c ON c.course_name = v.course_name;
