-- добавляем статус экзамена, у старых записей из ЛР1 будет 'completed'
ALTER TABLE exam_results
    ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'completed'
        CHECK (status IN ('scheduled', 'completed', 'absent', 'cancelled'));

-- оценки может не быть (экзамен назначен, неявка, отменён)
ALTER TABLE exam_results
    ALTER COLUMN grade DROP NOT NULL;

-- оценка есть только у состоявшегося экзамена, у остальных статусов её быть не должно
ALTER TABLE exam_results
    ADD CONSTRAINT exam_results_grade_status_chk
        CHECK ((status = 'completed') = (grade IS NOT NULL));
