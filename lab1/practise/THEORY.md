# ЛР 2: теория для защиты

Шпаргалка: сначала общая теория SQL, которая нужна в этой лабе, потом разбор каждого файла
построчно, в конце список каверзных вопросов с ответами.

---

## 0. Схема базы (из ЛР 1), чтобы держать в голове

```
academic_groups (group_id PK, group_name UNIQUE, enrollment_year)
        ▲ 1
        │ N   ON DELETE CASCADE
students (student_id PK, first_name, last_name, email UNIQUE, group_id FK, birth_date)
        ▲ 1
        │ N   ON DELETE CASCADE
exam_results (student_id FK, course_id FK, exam_date, grade, status)   PK = (student_id, course_id, exam_date)
        │ N
        ▼ 1   ON DELETE CASCADE
courses (course_id PK, course_name, credits, professor_id FK NULL)
        │ N
        ▼ 1   ON DELETE SET NULL
professors (professor_id PK, first_name, last_name, department)
```

- `exam_results` — главная **операционная** таблица (таблица событий/фактов). Одна строка = одна попытка
  сдачи экзамена.
- Составной первичный ключ `(student_id, course_id, exam_date)` означает: один студент может сдавать
  один курс несколько раз, но в **разные даты**. Так и хранятся пересдачи.
- `SERIAL` — автоинкрементный целочисленный столбец (под капотом — последовательность `SEQUENCE`
  + `DEFAULT nextval(...)`).

---

## 1. Общая теория SQL

### 1.1. Категории команд

| Категория | Расшифровка | Команды | Где в лабе |
|---|---|---|---|
| DDL | Data Definition Language — описание структуры | `CREATE`, `ALTER`, `DROP` | `0_migration.sql` |
| DML | Data Manipulation Language — изменение данных | `INSERT`, `UPDATE`, `DELETE` | `1_1`, `1_2` |
| DQL | Data Query Language — чтение | `SELECT` | `2_1` – `4` |
| TCL | Transaction Control Language — транзакции | `BEGIN`, `COMMIT`, `ROLLBACK` | `1_2` |

### 1.2. Логический порядок выполнения SELECT

Пишем в одном порядке, а СУБД (логически) выполняет в другом. **Это главное, что надо понимать** —
из этого вытекают почти все ответы про WHERE/HAVING/алиасы.

```
Пишем:                     Выполняется:
SELECT ...                 1. FROM / JOIN      — собрать таблицы, соединить
FROM ...                   2. WHERE            — отфильтровать СТРОКИ
JOIN ... ON ...            3. GROUP BY         — разбить строки на группы
WHERE ...                  4. HAVING           — отфильтровать ГРУППЫ
GROUP BY ...               5. SELECT           — посчитать выражения, дать алиасы (AS)
HAVING ...                 6. DISTINCT
ORDER BY ...               7. ORDER BY         — отсортировать
                           8. LIMIT / OFFSET
```

Следствия:
- В `WHERE` нельзя писать агрегаты (`AVG`, `COUNT`...) — группировки ещё не было. Для этого есть `HAVING`.
- В `WHERE` и `GROUP BY` (по стандарту) нельзя использовать алиасы из `SELECT` — они ещё не созданы.
  Поэтому в 2.2.3 написано `GROUP BY EXTRACT(YEAR FROM er.exam_date), ...`, а не `GROUP BY year`.
- В `ORDER BY` алиасы использовать **можно** — он выполняется после `SELECT`
  (`ORDER BY g.group_name, student`, `ORDER BY avg_grade`).

### 1.3. NULL и трёхзначная логика

`NULL` — это «значение неизвестно / отсутствует», а не 0 и не пустая строка.

- Любое сравнение с NULL даёт не TRUE/FALSE, а **UNKNOWN**: `NULL = 2` → UNKNOWN, `NULL = NULL` → UNKNOWN.
- `WHERE` и `ON` пропускают только строки с TRUE. UNKNOWN отбрасывается так же, как FALSE.
- Проверять NULL можно только через `IS NULL` / `IS NOT NULL`.
- Арифметика и конкатенация с NULL дают NULL: `NULL || ' ' || 'Иван'` → NULL, `5 + NULL` → NULL.
- `CHECK` **пропускает** строку, если условие UNKNOWN (отклоняет только FALSE). Поэтому `CHECK (grade >= 2 AND grade <= 5)`
  не мешает `grade = NULL`.
- `COALESCE(a, b, c)` — вернуть первый аргумент, который не NULL.

### 1.4. Агрегатные функции

| Функция | Что делает | Как обращается с NULL | Если строк нет |
|---|---|---|---|
| `COUNT(*)` | число строк | считает все строки | 0 |
| `COUNT(col)` | число строк, где `col` не NULL | пропускает NULL | 0 |
| `COUNT(DISTINCT col)` | число **разных** не-NULL значений | пропускает NULL | 0 |
| `SUM(col)` | сумма | пропускает NULL | **NULL** |
| `AVG(col)` | среднее = SUM / COUNT(col) | пропускает NULL (не считает их нулями!) | **NULL** |
| `MIN(col)`, `MAX(col)` | минимум / максимум | пропускают NULL | **NULL** |

Важно для лабы: у неявок `grade = NULL`, поэтому `AVG(grade)` их просто не видит и средний балл не портится.

Правило `GROUP BY`: в `SELECT` можно выводить только (а) столбцы из `GROUP BY` и (б) агрегаты.
Всё остальное — ошибка, потому что непонятно, какое из значений группы показать.

**Агрегат без GROUP BY** сворачивает всю выборку в одну строку (даже если строк 0 — тогда результат одна строка
с `COUNT = 0` / `AVG = NULL`). Это используется в коррелированных подзапросах 3.4.

### 1.5. Подсчёт по условию: `SUM(CASE ...)` и `COUNT(CASE ...)`

```sql
SUM(CASE WHEN условие THEN 1 ELSE 0 END)   -- строка подходит → 1, нет → 0, сумма = количество
COUNT(CASE WHEN условие THEN 1 END)        -- нет ELSE → NULL, а COUNT не считает NULL
```

Оба варианта дают одно и то же. В PostgreSQL есть сокращение `COUNT(*) FILTER (WHERE ...)`, но это
расширение, а не стандарт, поэтому в лабе его нет.

`CASE` — условное выражение (аналог if/else внутри запроса):

```sql
CASE WHEN условие1 THEN значение1
     WHEN условие2 THEN значение2
     ELSE значение_по_умолчанию     -- если ELSE нет и ничего не подошло → NULL
END
```

### 1.6. Виды JOIN

| JOIN | Что остаётся в результате |
|---|---|
| `[INNER] JOIN` | только пары строк, для которых условие `ON` истинно |
| `LEFT [OUTER] JOIN` | все строки **левой** таблицы; если пары справа нет — столбцы правой = NULL |
| `RIGHT JOIN` | зеркально: все строки правой |
| `FULL JOIN` | все строки обеих таблиц |
| `CROSS JOIN` | декартово произведение (каждая с каждой) |

Приёмы:
- **Anti-join** (найти строки без пары): `LEFT JOIN ... WHERE правая.ключ IS NULL` (2.1.2).
- Проверять на NULL надо столбец, который **не может быть NULL** в реальной строке (PK или `NOT NULL`),
  иначе перепутаем «пары нет» и «пара есть, но значение NULL».
- Условие на правую таблицу при LEFT JOIN: в `ON` — фильтрует пары, левые строки остаются;
  в `WHERE` — фильтрует уже результат, и строки с NULL справа выкинутся (LEFT JOIN фактически станет INNER).
- Если после `LEFT JOIN t` написать `INNER JOIN` по столбцу из `t`, строки с NULL опять потеряются.
  Поэтому в 2.1.1 `LEFT JOIN professors` стоит последним.

### 1.7. Подзапросы

| Вид | Возвращает | Где пишут | Пример из лабы |
|---|---|---|---|
| Скалярный | 1 строку × 1 столбец | `SELECT`, `WHERE`, `VALUES`, `SET` | `(SELECT group_id FROM academic_groups WHERE group_name = 'ПМИ-307')` |
| Табличный / списочный | много строк | `IN (...)`, `FROM (...)` | `course_id IN (SELECT c.course_id ...)` в 1.2 |
| `EXISTS (...)` | TRUE / FALSE | `WHERE` | 3.2 |
| `NOT EXISTS (...)` | TRUE / FALSE | `WHERE` | 3.3 |
| **Коррелированный** | — | где угодно | 3.1, 3.2, 3.3, 3.4 |

- Скалярный подзапрос вернул 0 строк → результат NULL. Вернул больше 1 строки → **ошибка**. Поэтому
  поиск идёт по уникальным полям (`email UNIQUE`, `group_name UNIQUE`).
- **Некоррелированный** подзапрос не зависит от внешнего запроса, считается один раз.
- **Коррелированный** подзапрос ссылается на столбец внешнего запроса (`WHERE r.student_id = er.student_id`)
  и логически выполняется заново **для каждой строки** внешнего запроса. (Оптимизатор может переписать его
  в JOIN, но смысл такой.)
- `EXISTS` проверяет только факт наличия хотя бы одной строки и останавливается на первой найденной.
  Что написано в `SELECT` внутри — неважно, поэтому пишут `SELECT 1`.
- **Почему NOT EXISTS, а не NOT IN:** если в списке подзапроса есть NULL, то `x NOT IN (1, 2, NULL)` =
  `x<>1 AND x<>2 AND x<>NULL` = UNKNOWN → запрос вернёт **0 строк**. `NOT EXISTS` такой ловушки не имеет.

### 1.8. CTE (`WITH`)

```sql
WITH
шаг1 AS (SELECT ... FROM таблица),
шаг2 AS (SELECT ... FROM шаг1),
шаг3 AS (SELECT ... FROM шаг2 JOIN ...)
SELECT ... FROM шаг3;
```

- CTE (Common Table Expression) — именованный временный результат, существует только в рамках одного запроса.
- Каждый следующий CTE может ссылаться на предыдущие.
- Зачем: читаемость (сложный запрос разбит на шаги), можно сослаться на один шаг несколько раз,
  каждый шаг проверяется отдельно (`SELECT * FROM шаг1`).
- От представления (`VIEW`) отличается тем, что не сохраняется в базе.
- Бывает `WITH RECURSIVE` для рекурсивных запросов (деревья, графы) — в лабе не нужен.

### 1.9. Транзакции

`BEGIN` — начать транзакцию, `COMMIT` — зафиксировать, `ROLLBACK` — отменить всё с момента `BEGIN`.

Свойства **ACID**:
- **A**tomicity — атомарность: выполняется всё или ничего.
- **C**onsistency — согласованность: после транзакции все ограничения (PK, FK, CHECK) выполняются.
- **I**solation — изоляция: незакоммиченные изменения не видны другим сессиям
  (по умолчанию в PostgreSQL уровень `READ COMMITTED`).
- **D**urability — долговечность: после `COMMIT` данные не пропадут даже при сбое (журнал WAL).

Без явного `BEGIN` каждая команда в psql — отдельная транзакция (autocommit).
Если внутри транзакции произошла ошибка, PostgreSQL переводит её в состояние «aborted», все следующие команды
отклоняются, а `COMMIT` фактически сделает `ROLLBACK`.

**Последовательности (SERIAL) не откатываются:** если INSERT отменён или упал, выданный номер уже потрачен.
Поэтому после неудачных вставок в `constraints_test.sql` id «сдвинулись», и в лабе связи ищутся по именам/email.

### 1.10. Ссылочная целостность: что происходит при DELETE

| Опция у FOREIGN KEY | Что будет при удалении родителя |
|---|---|
| `ON DELETE CASCADE` | дочерние строки удаляются вместе с родителем |
| `ON DELETE SET NULL` | в дочерних строках FK становится NULL |
| `ON DELETE RESTRICT` / `NO ACTION` (по умолчанию) | удаление запрещено, пока есть дочерние строки (ошибка) |
| `ON DELETE SET DEFAULT` | FK становится значением по умолчанию |

В нашей схеме: `students → exam_results` CASCADE, `courses → exam_results` CASCADE,
`academic_groups → students` CASCADE, `professors → courses` SET NULL.

### 1.11. Мелкий синтаксис, который встречается в лабе

| Конструкция | Значение |
|---|---|
| `a \|\| ' ' \|\| b` | конкатенация строк (стандарт SQL) |
| `x BETWEEN a AND b` | `x >= a AND x <= b`, **границы включаются** |
| `x IN ('a', 'b')` | `x = 'a' OR x = 'b'` |
| `DATE '2026-06-01'` | литерал типа DATE (стандарт) |
| `CAST(x AS DATE)` | приведение типа (стандарт; в PG есть сокращение `x::date`) |
| `exam_date + INTERVAL '7' DAY` | прибавить 7 дней (стандартная запись интервала) |
| `EXTRACT(MONTH FROM d)` | вытащить часть даты (год, месяц, день...) |
| `ROUND(x, 2)` | округлить до 2 знаков |
| `100.0 * a / b` | `100.0` делает выражение дробным, иначе `3 / 8` = 0 (целочисленное деление) |
| `ORDER BY x DESC NULLS LAST` | NULL в конец (в PG при `DESC` NULL по умолчанию идут **первыми**) |
| `t AS алиас` / `t алиас` | псевдоним таблицы, `AS` можно не писать |
| `(VALUES (...), (...)) AS v(c1, c2)` | «таблица на лету» из перечисленных строк |

---

## 2. Разбор файлов

### 2.0. `0_migration.sql` — расширение модели

**Зачем:** в ЛР 1 в `exam_results` была только оценка, то есть у экзамена было одно «состояние» — сдан.
Задание требует ≥ 3 состояний бизнес-процесса, поэтому добавлен `status`.

```sql
ALTER TABLE exam_results
    ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'completed'
        CHECK (status IN ('scheduled', 'completed', 'absent', 'cancelled'));
```
- `ALTER TABLE ... ADD COLUMN` — добавить столбец в существующую таблицу.
- `NOT NULL DEFAULT 'completed'` — у всех **уже существующих** строк из ЛР 1 столбец сразу заполнится
  значением `'completed'`. Без DEFAULT добавить NOT NULL-столбец в непустую таблицу нельзя.
  Так выполнено требование «сохранить ранее созданные данные».
- `CHECK (status IN (...))` — допустимы только 4 значения (по сути перечисление/enum).

```sql
ALTER TABLE exam_results ALTER COLUMN grade DROP NOT NULL;
```
- Снимаем ограничение NOT NULL с оценки: у назначенного / пропущенного / отменённого экзамена оценки нет.

```sql
ALTER TABLE exam_results
    ADD CONSTRAINT exam_results_grade_status_chk
        CHECK ((status = 'completed') = (grade IS NOT NULL));
```
- Именованное ограничение (имя нужно, чтобы потом его можно было удалить/найти в ошибке).
- Сравниваются **два булевых значения**: «экзамен состоялся» и «оценка есть». Равенство булевых = «тогда и только тогда»:
  - `completed` и оценка есть → TRUE = TRUE → ок;
  - `scheduled` и оценки нет → FALSE = FALSE → ок;
  - `completed` без оценки → TRUE = FALSE → ошибка;
  - `absent` с оценкой → FALSE = TRUE → ошибка.
- Ловушки с NULL тут нет: `status` NOT NULL, а `IS NOT NULL` всегда TRUE/FALSE.
- Двойка (`grade = 2`, `completed`) — это «экзамен состоялся, но не сдан».

### 2.1. `1_1_data.sql` — наполнение данными

**Приём 1: условная вставка (чтобы не было дубля)**
```sql
INSERT INTO academic_groups (group_name, enrollment_year)
SELECT 'ПМИ-206', 2025
WHERE NOT EXISTS (SELECT 1 FROM academic_groups WHERE group_name = 'ПМИ-206');
```
- `INSERT ... SELECT` вставляет то, что вернул SELECT. SELECT без FROM возвращает одну строку,
  а `WHERE NOT EXISTS` делает так, что он вернёт 0 строк, если группа уже есть. Тогда вставится 0 строк
  и `UNIQUE(group_name)` не сработает. (Аналог PG-шного `ON CONFLICT DO NOTHING`, но стандартный.)

**Приём 2: скалярный подзапрос вместо id**
```sql
INSERT INTO courses (course_name, credits, professor_id) VALUES
('Базы данных', 5, (SELECT professor_id FROM professors WHERE last_name = 'Кузнецова')),
('Философия',   1, NULL),
...
```
- Вместо «магического» id подставляется результат подзапроса по фамилии.
- У «Философии» `professor_id = NULL` — разрешено, потому что FK без NOT NULL. Это пограничный случай.

**Приём 3: `INSERT ... SELECT FROM (VALUES ...) JOIN`**
```sql
INSERT INTO students (first_name, last_name, email, group_id, birth_date)
SELECT v.first_name, v.last_name, v.email, g.group_id, CAST(v.birth_date AS DATE)
FROM (VALUES
    ('Анна', 'Орлова', 'anna.orlova@example.com', 'ПМИ-306', '2006-03-12'),
    ...
) AS v(first_name, last_name, email, group_name, birth_date)
JOIN academic_groups g ON g.group_name = v.group_name;
```
- `(VALUES ...) AS v(...)` — временная таблица прямо в запросе, столбцам даются имена.
- Её JOIN с `academic_groups` по **естественному ключу** `group_name` превращает название группы в `group_id`.
- `CAST(... AS DATE)` — строку в дату.
- Аналогично для `exam_results`: JOIN со `students` по `email` и с `courses` по `course_name`.
- Минус приёма: если в названии опечатка, JOIN не найдёт пару и строка **молча не вставится**
  (а не упадёт с ошибкой).

**Как выполнены требования 1.1** (см. README): 122 строки в `exam_results`; 4 статуса; месяцы
дек 2025 — янв 2027; пересдачи (Козлов, Семёнов); сущности без операций (ПМИ-108, Лебедева,
Волкова, «Машинное обучение»); пограничные значения (оценки 2 и 5, 1 кредит, NULL-преподаватель, NULL-оценки).

### 2.2. `1_2_dml.sql` — INSERT / UPDATE / DELETE / ROLLBACK

Шаги 1–4 обёрнуты в `BEGIN; ... COMMIT;` — это одна бизнес-операция «перевод студента»,
либо выполнится целиком, либо никак.

**Шаг 1. INSERT новой сущности + связанных записей**
```sql
INSERT INTO students (first_name, last_name, email, group_id, birth_date)
VALUES ('Илья', 'Смирнов', 'ilya.smirnov@example.com',
        (SELECT group_id FROM academic_groups WHERE group_name = 'ПМИ-307'),
        '2006-10-03');
```
- `student_id` не указан — его выдаст `SERIAL`.
- Потом два INSERT в `exam_results` (многострочный `VALUES (...), (...)`), где `student_id` ищется
  подзапросом по `email`. Порядок важен: сначала родитель (студент), потом дети (экзамены), иначе FK не даст вставить.
- Статус `'scheduled'`, оценка `NULL` — проходит CHECK из миграции.
- Затем контрольный SELECT с JOIN — показать, что всё добавилось.

**Шаг 2. UPDATE — смена состояния**
```sql
UPDATE exam_results
SET status = 'completed', grade = 4
WHERE student_id = (SELECT ... WHERE email = 'ilya.smirnov@example.com')
  AND course_id  = (SELECT ... WHERE course_name = 'Базы данных')
  AND status = 'scheduled';
```
- `SET` меняет **оба** поля одной командой. Если поменять по отдельности (сначала статус, потом оценку),
  промежуточное состояние «completed без оценки» нарушит CHECK.
- `AND status = 'scheduled'` — защита: обновляем только назначенный экзамен, не трогаем уже сданные.
- **Без WHERE UPDATE изменит все строки таблицы.**

**Шаг 3. Массовый UPDATE по содержательному условию**
```sql
UPDATE exam_results
SET exam_date = exam_date + INTERVAL '7' DAY
WHERE status = 'scheduled'
  AND course_id IN (SELECT c.course_id
                    FROM courses c
                    JOIN professors p ON p.professor_id = c.professor_id
                    WHERE p.last_name = 'Кузнецова');
```
- Справа в `SET` можно использовать текущее значение столбца (`exam_date + ...`).
- Подзапрос в `IN` возвращает список курсов Кузнецовой (БД и ОС), обновляются все назначенные экзамены по ним.
- Дата — часть первичного ключа. Менять PK можно, главное, чтобы не появился дубль
  `(student, course, date)`.

**Шаг 4. DELETE**
```sql
DELETE FROM exam_results
WHERE student_id = (...) AND course_id = (SELECT ... 'Операционные системы');
```
- Удаляется **дочерняя** запись, на неё никто не ссылается, поэтому ограничения целостности не мешают.

**Шаг 5. ROLLBACK + демонстрация ограничений целостности**
```sql
BEGIN;
SELECT (SELECT COUNT(*) FROM students) AS students_cnt, ...;   -- до: 28 / 122 / 1
DELETE FROM students   WHERE email = 'gleb.baranov@example.com'; -- CASCADE: его 6 результатов тоже удалятся
DELETE FROM professors WHERE last_name = 'Соколов';              -- SET NULL: у его курсов professor_id = NULL
SELECT ...;                                                       -- внутри транзакции: 27 / 116 / 3
ROLLBACK;
SELECT ...;                                                       -- после отката снова 28 / 122 / 1
```
- `SELECT (подзапрос), (подзапрос), (подзапрос)` без FROM — способ вывести несколько счётчиков одной строкой.
- Показано, что: (1) удаление родителя вызывает каскадное удаление/обнуление у детей;
  (2) внутри транзакции изменения видны; (3) `ROLLBACK` отменяет **всё**, включая каскадные изменения.

### 2.3. `2_1_joins.sql` — многотабличные запросы

**2.1.1. Подробная информация: ведомость зимней сессии (5 таблиц)**
```sql
SELECT g.group_name,
       s.last_name || ' ' || s.first_name                          AS student,
       c.course_name,
       COALESCE(p.last_name || ' ' || p.first_name, 'не назначен') AS professor,
       er.exam_date, er.status, er.grade
FROM exam_results er
JOIN students        s ON s.student_id   = er.student_id
JOIN academic_groups g ON g.group_id     = s.group_id
JOIN courses         c ON c.course_id    = er.course_id
LEFT JOIN professors p ON p.professor_id = c.professor_id
WHERE er.exam_date BETWEEN DATE '2025-12-01' AND DATE '2026-03-31'
ORDER BY g.group_name, student, er.exam_date;
```
- Начинаем от таблицы событий `exam_results` и «подтягиваем» к ней справочники по FK.
- `LEFT JOIN professors`: у «Философии» `professor_id = NULL`, `NULL = что-угодно` → UNKNOWN,
  при INNER JOIN экзамены по философии пропали бы. При LEFT JOIN они остаются, а `p.*` = NULL.
- `COALESCE(...)`: конкатенация с NULL даёт NULL, и `COALESCE` заменяет его на «не назначен».
- `BETWEEN` включает обе границы: декабрь (досрочка), январь (сессия), февраль–март (пересдачи).
- `ORDER BY ... student` — сортировка по алиасу из SELECT.

**2.1.2. Объекты без связанных записей: студенты без экзаменов (anti-join)**
```sql
FROM academic_groups g
JOIN students s           ON s.group_id   = g.group_id
LEFT JOIN exam_results er ON er.student_id = s.student_id
WHERE er.student_id IS NULL
```
- LEFT JOIN оставляет каждого студента. Если экзаменов нет, все столбцы `er` = NULL.
- `WHERE er.student_id IS NULL` оставляет только таких. `er.student_id` — часть PK, в реальной строке
  он не может быть NULL, значит NULL = «пары нет».
- Результат: 3 студента ПМИ-108 и Лебедева.
- То же самое через подзапрос: `WHERE NOT EXISTS (SELECT 1 FROM exam_results er WHERE er.student_id = s.student_id)`.

**2.1.3. Несколько взаимосвязанных условий**
```sql
WHERE g.enrollment_year = 2024                                   -- условие на группу
  AND p.department = 'Кафедра вычислительной математики и программирования'  -- на преподавателя
  AND er.status = 'completed' AND er.grade = 5                   -- на результат
  AND er.exam_date BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'  -- на период
```
- Условия относятся к **разным** таблицам, поэтому они «взаимосвязанные»: чтобы их проверить, нужен JOIN
  всех 5 таблиц.
- Здесь `JOIN professors` обычный (INNER): нужен преподаватель с конкретной кафедрой, курсы без
  преподавателя заведомо не подходят.

### 2.4. `2_2_aggregation.sql` — агрегация и группировка

**2.2.1. Количественные показатели по группам**
```sql
SELECT g.group_name,
       COUNT(DISTINCT s.student_id)                             AS students,
       SUM(CASE WHEN er.status = 'completed' THEN 1 ELSE 0 END) AS exams_taken,
       SUM(CASE WHEN er.status = 'absent'    THEN 1 ELSE 0 END) AS absences,
       SUM(CASE WHEN er.grade = 2            THEN 1 ELSE 0 END) AS fails,
       SUM(CASE WHEN er.status = 'scheduled' THEN 1 ELSE 0 END) AS scheduled
FROM academic_groups g
LEFT JOIN students s      ON s.group_id    = g.group_id
LEFT JOIN exam_results er ON er.student_id = s.student_id
GROUP BY g.group_name
```
- После JOIN строк столько, сколько **экзаменов**, а не студентов: студент с 5 экзаменами повторится 5 раз.
  Поэтому `COUNT(DISTINCT s.student_id)` — каждого студента считаем один раз.
- Два `LEFT JOIN`: у ПМИ-108 нет экзаменов, при INNER JOIN группа исчезла бы. Сейчас для её студентов
  `er.*` = NULL, `CASE WHEN NULL = 'completed'` → идёт в `ELSE 0`, поэтому выводятся **нули, а не NULL**.
- `GROUP BY g.group_name` корректен, так как `group_name` UNIQUE.

**2.2.2. Фильтрация групп через HAVING — «трудные курсы»**
```sql
SELECT c.course_name, COUNT(*), ROUND(AVG(er.grade), 2) AS avg_grade,
       MIN(er.grade), MAX(er.grade), SUM(CASE WHEN er.grade = 2 THEN 1 ELSE 0 END) AS fails
FROM courses c
JOIN exam_results er ON er.course_id = c.course_id
WHERE er.status = 'completed'          -- ДО группировки: берём только состоявшиеся экзамены
GROUP BY c.course_name
HAVING COUNT(*) >= 5                   -- ПОСЛЕ группировки: достаточно статистики
   AND AVG(er.grade) < 4               -- и средний балл низкий
ORDER BY avg_grade;
```
- Здесь все 5 агрегатов: COUNT, AVG, MIN, MAX, SUM.
- `WHERE` против `HAVING` — классический вопрос: `WHERE` режет строки, `HAVING` режет группы,
  агрегаты можно только в `HAVING`.
- `COUNT(*) >= 5` — чтобы не объявить курс «трудным» по 1–2 экзаменам (статистически незначимо).
- В `HAVING` написано `AVG(er.grade)`, а не алиас `avg_grade`, потому что HAVING выполняется до SELECT.

**2.2.3. Сравнение по временным периодам (месяцам)**
```sql
SELECT EXTRACT(YEAR FROM er.exam_date) AS year, EXTRACT(MONTH FROM er.exam_date) AS month,
       COUNT(*) AS attempts, ROUND(AVG(er.grade), 2) AS avg_grade,
       SUM(CASE WHEN er.grade = 5 THEN 1 ELSE 0 END) AS excellent,
       SUM(CASE WHEN er.grade = 2 OR er.status = 'absent' THEN 1 ELSE 0 END) AS fails,
       ROUND(100.0 * SUM(...) / COUNT(*), 1) AS fail_pct
FROM exam_results er
WHERE er.status IN ('completed', 'absent')
GROUP BY EXTRACT(YEAR FROM er.exam_date), EXTRACT(MONTH FROM er.exam_date)
ORDER BY year, month;
```
- Группировка по **выражению**. Год нужен вместе с месяцем, иначе январь 2026 и январь 2027 склеились бы.
- `COUNT(*)` считает и неявки, а `AVG(grade)` — только оценки (у неявок NULL). Поэтому средний балл честный,
  а процент неудач учитывает и неявки.
- `100.0 * ...` — чтобы деление было дробным.
- Вывод: хуже всего февраль (пересдачи, средний 3,08, 37,5 % неудач), лучше всего декабрь (досрочка, 4,27).

### 2.5. `3_subqueries.sql` — подзапросы

Договорённость в начале файла: **попытка** = `completed` или `absent`; **курс сдан** = есть оценка ≥ 3.

**3.1. Сравнение с вычисляемым показателем: средний балл студента > средний по его группе**
```sql
SELECT g.group_name, s.last_name || ' ' || s.first_name AS student, ROUND(AVG(er.grade), 2) AS student_avg
FROM students s
JOIN academic_groups g ON g.group_id    = s.group_id
JOIN exam_results er   ON er.student_id = s.student_id
WHERE er.status = 'completed'
GROUP BY g.group_id, g.group_name, s.student_id, s.last_name, s.first_name
HAVING AVG(er.grade) > (
    SELECT AVG(er2.grade)
    FROM exam_results er2
    JOIN students s2 ON s2.student_id = er2.student_id
    WHERE s2.group_id = g.group_id        -- ← ссылка на внешний запрос
      AND er2.status = 'completed'
)
```
- Внешний запрос: группировка по студенту → средний балл каждого студента.
- Подзапрос в `HAVING` считает средний балл **всей группы этого студента**. Он коррелирован по `g.group_id`.
  Сослаться на `g.group_id` внутри HAVING можно только потому, что он есть в `GROUP BY`.
- В `GROUP BY` перечислены и имена (`last_name`, `first_name`), потому что они выводятся в SELECT.
  `s.student_id` включён, чтобы однофамильцы не склеились.
- Внутри используются другие алиасы (`er2`, `s2`), чтобы не путать с внешними таблицами.
- Группа сравнения = академическая группа — это естественная категория в предметной области.

**3.2. EXISTS: двойки, которые потом пересдали**
```sql
FROM exam_results er ...
WHERE er.grade = 2
  AND EXISTS (
      SELECT 1 FROM exam_results r
      WHERE r.student_id = er.student_id   -- тот же студент
        AND r.course_id  = er.course_id    -- тот же курс
        AND r.exam_date  > er.exam_date    -- позже
        AND r.status = 'completed' AND r.grade >= 3   -- и сдал
  )
```
- Для каждой «двойки» проверяется: существует ли более поздняя положительная оценка по тому же курсу.
- Таблица соединяется **сама с собой** (self-reference через подзапрос): `er` — двойка, `r` — пересдача.
- `EXISTS` = semi-join: строка `er` выводится один раз, даже если подходящих пересдач несколько
  (с обычным JOIN она бы задублировалась).

**3.3. NOT EXISTS: текущие академические задолженности**
```sql
WHERE er.status IN ('completed', 'absent')     -- студент уже пытался сдавать
  AND NOT EXISTS (
      SELECT 1 FROM exam_results r
      WHERE r.student_id = er.student_id
        AND r.course_id  = er.course_id
        AND r.status = 'completed' AND r.grade >= 3   -- события «курс сдан» нет
  )
GROUP BY g.group_name, s.student_id, s.last_name, s.first_name, c.course_name
-- в SELECT: MAX(er.exam_date) AS last_attempt, COUNT(*) AS attempts
```
- Содержательный смысл отсутствия: студент ходил на экзамен (или должен был), но **положительной оценки нет** → это долг.
- Раз положительной оценки нет, все отобранные попытки — это двойки и неявки.
- Курсы, где есть только `scheduled`, не попадают — экзамен ещё не наступил, это не долг.
- `GROUP BY` сворачивает несколько неудачных попыток в одну строку «студент — курс» с числом попыток и датой последней.
- Anti-join через NOT EXISTS; NOT IN тут хуже из-за проблемы с NULL (см. 1.7).

**3.4. Коррелированные скалярные подзапросы: карточка студента**
```sql
SELECT s.last_name || ' ' || s.first_name AS student, g.group_name,
    (SELECT COUNT(*) FROM exam_results er
     WHERE er.student_id = s.student_id AND er.status IN ('completed','absent'))  AS attempts,
    (SELECT ROUND(AVG(er.grade), 2) ... AND er.status = 'completed')            AS avg_grade,
    (SELECT COUNT(DISTINCT er.course_id) ... AND er.grade >= 3)                 AS courses_passed,
    (SELECT MIN(er.exam_date) ... AND er.status = 'scheduled')                  AS next_exam
FROM students s
JOIN academic_groups g ON g.group_id = s.group_id
```
- Каждый подзапрос в SELECT выполняется для текущего студента `s` (условие `er.student_id = s.student_id`).
- Каждый — скалярный: агрегат без GROUP BY всегда возвращает ровно одну строку.
- Для студентов без экзаменов: `COUNT` → 0, `AVG` и `MIN` → NULL. Студенты при этом не теряются
  (в отличие от варианта с INNER JOIN).
- `COUNT(DISTINCT course_id)` — если курс сдавался после пересдачи, считаем его один раз.
- `MIN(exam_date)` среди назначенных = ближайший экзамен.
- Альтернатива: `LEFT JOIN exam_results` + `GROUP BY` + `SUM(CASE ...)`. Подзапросы проще читать,
  но на больших данных JOIN обычно быстрее (один проход вместо четырёх на каждого студента).

### 2.6. `4_cte_report.sql` — аналитический отчёт

**Вопрос:** как каждая группа прошла сессии 2025/26 учебного года — средний итоговый балл, сколько
сдали всё с первого раза, сколько должников?

**Схема:** `exam_results → attempts → course_outcome → student_summary → group_summary → отчёт`
(исходные данные → промежуточные показатели → агрегация → итог).

**Этап 1. `attempts` — исходные данные**
```sql
SELECT er.student_id, er.course_id, er.grade
FROM exam_results er
WHERE er.status IN ('completed', 'absent')
  AND er.exam_date BETWEEN DATE '2025-09-01' AND DATE '2026-09-30'
```
- Вход: все записи `exam_results`. Выход: одна строка = одна реальная попытка за учебный год
  (включая осенние пересдачи сентября 2026). `scheduled` и `cancelled` отброшены — попыткой не являются.

**Этап 2. `course_outcome` — итог по паре «студент–курс»**
```sql
SELECT a.student_id, a.course_id,
       COUNT(*)                                                       AS attempts_cnt,
       MAX(a.grade)                                                   AS final_grade,
       CASE WHEN MAX(a.grade) >= 3 THEN 1 ELSE 0 END                  AS passed,
       CASE WHEN COUNT(*) = 1 AND MAX(a.grade) >= 3 THEN 1 ELSE 0 END AS first_try
FROM attempts a
GROUP BY a.student_id, a.course_id
```
- `MAX(grade)` = итоговая оценка (лучшая из попыток; неявки с NULL игнорируются).
- Если все попытки — неявки, `MAX` = NULL, `NULL >= 3` → UNKNOWN → `ELSE 0`: курс не сдан. Корректно.
- Флаги 1/0 удобны тем, что их потом можно суммировать и брать MIN.
- `CASE` над агрегатами в SELECT с GROUP BY разрешён.

**Этап 3. `student_summary` — итог по студенту**
```sql
SELECT co.student_id,
       AVG(CASE WHEN co.passed = 1 THEN co.final_grade END) AS avg_grade,
       COUNT(*) - SUM(co.passed)                            AS debts,
       MIN(co.first_try)                                    AS all_first_try
FROM course_outcome co
GROUP BY co.student_id
```
- `AVG(CASE ... THEN final_grade END)`: без ELSE несданные курсы дают NULL, и AVG их не учитывает →
  средний балл по **сданным** курсам.
- `debts` = всего курсов − сданных курсов.
- `MIN(first_try) = 1` ⇔ по **всем** курсам флаг 1 (если хоть один 0, минимум 0). Это приём «квантор всеобщности» через MIN.

**Этап 4. `group_summary` — агрегация по группам**
```sql
SELECT g.group_name,
       COUNT(s.student_id)                              AS students_total,
       COUNT(ss.student_id)                             AS students_examined,
       ROUND(AVG(ss.avg_grade), 2)                      AS group_avg_grade,
       COUNT(CASE WHEN ss.all_first_try = 1 THEN 1 END) AS first_try_students,
       COUNT(CASE WHEN ss.debts > 0 THEN 1 END)         AS debtors
FROM academic_groups g
LEFT JOIN students s         ON s.group_id    = g.group_id
LEFT JOIN student_summary ss ON ss.student_id = s.student_id
GROUP BY g.group_name
```
- CTE используется как обычная таблица и соединяется с реальными таблицами.
- `LEFT JOIN` дважды: чтобы не потерять группы без студентов и студентов без экзаменов (ПМИ-108, Лебедева).
- `COUNT(s.student_id)` — все студенты группы; `COUNT(ss.student_id)` — только те, у кого были попытки
  (у остальных `ss.student_id` = NULL, COUNT(col) его пропускает). Разница двух COUNT — главный трюк этапа.
- `AVG(ss.avg_grade)` — среднее из средних студентов (каждый студент весит одинаково, независимо от числа экзаменов).
- `COUNT(CASE WHEN ... THEN 1 END)` — подсчёт по условию.

**Этап 5. Итоговый SELECT**
```sql
SELECT ..., CASE WHEN gs.students_examined > 0
                 THEN ROUND(100.0 * gs.first_try_students / gs.students_examined, 1)
            END AS first_try_pct, ...
FROM group_summary gs
ORDER BY gs.group_avg_grade DESC NULLS LAST;
```
- `CASE` защищает от **деления на ноль** у ПМИ-108 (0 студентов сдавали) — выводится NULL.
- `DESC NULLS LAST`: в PostgreSQL при `DESC` NULL по умолчанию идут первыми, а группа без данных должна
  быть в конце.

**Вывод отчёта:** у ПМИ-307 лучший средний балл (4,06), но 2 должника; у ПМИ-406 балл чуть ниже (3,93),
зато долгов нет; у ПМИ-108 данных нет — сессии ещё не было.

---

## 3. Вопросы на защите (с ответами)

**Общие**

1. *Чем WHERE отличается от HAVING?* — WHERE фильтрует строки до GROUP BY, HAVING — группы после. Агрегаты только в HAVING.
2. *Почему в WHERE нельзя использовать алиас из SELECT, а в ORDER BY можно?* — порядок выполнения: WHERE раньше SELECT, ORDER BY позже.
3. *Что вернёт `COUNT(*)`, `COUNT(grade)`, `AVG(grade)` для строк с NULL?* — `COUNT(*)` считает всё, `COUNT(grade)` и `AVG` пропускают NULL.
4. *Почему нельзя писать `grade = NULL`?* — сравнение с NULL даёт UNKNOWN, нужно `IS NULL`.
5. *Что будет, если в SELECT вывести столбец, которого нет в GROUP BY?* — ошибка: в группе много значений, неясно какое.

**JOIN**

6. *Чем LEFT JOIN отличается от INNER?* — LEFT сохраняет все строки левой таблицы, недостающее справа = NULL.
7. *Что будет в 2.1.1, если заменить LEFT JOIN professors на JOIN?* — пропадут экзамены по «Философии».
8. *Как найти строки без пары?* — `LEFT JOIN ... WHERE right.pk IS NULL` или `NOT EXISTS`.
9. *Что будет, если условие на правую таблицу LEFT JOIN перенести из ON в WHERE?* — строки с NULL отфильтруются, LEFT станет фактически INNER.
10. *Зачем `COUNT(DISTINCT s.student_id)` в 2.2.1?* — после JOIN студент дублируется по числу экзаменов.

**Подзапросы**

11. *Что такое коррелированный подзапрос?* — ссылается на столбец внешнего запроса и выполняется для каждой его строки (3.1–3.4).
12. *EXISTS vs IN?* — EXISTS проверяет наличие, останавливается на первой строке; IN сравнивает со списком значений.
13. *Почему NOT EXISTS, а не NOT IN?* — при NULL в подзапросе NOT IN вернёт пустой результат.
14. *Что будет, если скалярный подзапрос вернёт 2 строки? 0 строк?* — ошибка; NULL.
15. *Зачем `SELECT 1` внутри EXISTS?* — EXISTS важен только факт наличия строк, что именно выбирается, неважно.
16. *Где в 3.1 корреляция?* — `s2.group_id = g.group_id` внутри подзапроса в HAVING.

**CTE**

17. *Что такое CTE и зачем?* — именованный подзапрос в WITH; делит запрос на шаги, шаги ссылаются друг на друга.
18. *CTE vs VIEW vs временная таблица?* — CTE живёт в одном запросе; VIEW хранится в БД как сохранённый запрос; временная таблица хранит данные до конца сессии.
19. *Зачем MIN(first_try)?* — MIN по флагам 0/1 = 1, только если все флаги 1 («сдал всё с первого раза»).
20. *Зачем CASE в first_try_pct?* — защита от деления на 0.
21. *Почему `COUNT(s.student_id)` и `COUNT(ss.student_id)` дают разные числа?* — у студентов без экзаменов `ss.student_id` = NULL.

**DML и транзакции**

22. *Что сделает UPDATE / DELETE без WHERE?* — изменит / удалит все строки таблицы.
23. *Почему в шаге 2 status и grade меняются одним UPDATE?* — по отдельности промежуточное состояние нарушит CHECK.
24. *Что такое транзакция, ACID?* — см. 1.9.
25. *Что произойдёт с результатами Баранова при его удалении? С курсами Соколова?* — CASCADE удалит результаты, SET NULL обнулит professor_id у курсов.
26. *Откатывается ли SERIAL при ROLLBACK?* — нет, последовательности не транзакционны, номер теряется.
27. *Почему связи в данных ищутся по email/названию, а не по id?* — id после неудачных вставок сдвинулись; естественные ключи надёжнее и читаемее.
28. *Как DEFAULT в миграции сохранил старые данные?* — `ADD COLUMN ... DEFAULT 'completed'` заполнил всем существующим строкам статус «сдан».
29. *Объясните CHECK `(status = 'completed') = (grade IS NOT NULL)`.* — равенство двух булевых = «оценка есть ⇔ экзамен состоялся».

**Стандарт SQL**

30. *Почему не FILTER, `::`, RETURNING, ON CONFLICT?* — это расширения PostgreSQL; в лабе стандартные аналоги:
    `SUM(CASE ...)`, `CAST`, отдельный SELECT, `INSERT ... SELECT ... WHERE NOT EXISTS`.
