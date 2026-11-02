-- ЛР 2. Расширение модели данных из ЛР 1.
--
-- Обоснование: в ЛР 1 таблица exam_results хранила только выставленные оценки,
-- поэтому в ней нельзя было отразить состояние бизнес-процесса «экзамен».
-- Добавляем статус попытки сдачи:
--   scheduled - экзамен назначен, ещё не состоялся (оценки нет);
--   completed - экзамен состоялся, оценка выставлена (в т.ч. 2 = «неуд»);
--   absent    - студент не явился (оценки нет);
--   cancelled - попытка отменена/перенесена (оценки нет).
-- Оценка становится необязательной (NULL), но только для «несостоявшихся» попыток.
-- Уже существующие строки получают статус 'completed' через DEFAULT,
-- поэтому ранее внесённые данные сохраняются и остаются корректными.

ALTER TABLE exam_results
    ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'completed'
        CHECK (status IN ('scheduled', 'completed', 'absent', 'cancelled'));

ALTER TABLE exam_results
    ALTER COLUMN grade DROP NOT NULL;

-- Оценка есть тогда и только тогда, когда экзамен состоялся
ALTER TABLE exam_results
    ADD CONSTRAINT exam_results_grade_status_chk
        CHECK ((status = 'completed') = (grade IS NOT NULL));
