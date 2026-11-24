-- =====================================================================
-- NutriConsulta · testes das regras R garantidas pelo esquema
-- Roda dentro de uma transação e desfaz tudo no fim (ROLLBACK):
-- pode ser executado a qualquer momento sem alterar o banco.
--   psql -h localhost -U nutri -d nutriconsulta -f db/testes_regras.sql
-- =====================================================================
BEGIN;

-- Dados mínimos para os testes
INSERT INTO nutriente (nome_nutriente, unidade_padrao) VALUES ('proteins', 'g'), ('fat', 'g');
INSERT INTO grupo_alimentar (nome_grupo) VALUES ('en:spreads');
INSERT INTO alimento (codigo_barras, nome, marca, base_unidade)
VALUES ('3017620422003', 'Nutella', 'Ferrero', 'g');

DO $$
DECLARE
    a integer := (SELECT id_alimento FROM alimento WHERE codigo_barras = '3017620422003');
    n integer := (SELECT id_nutriente FROM nutriente WHERE nome_nutriente = 'proteins');
    g integer := (SELECT id_grupo FROM grupo_alimentar WHERE nome_grupo = 'en:spreads');
BEGIN
    -- R1: código de barras não se repete
    BEGIN
        INSERT INTO alimento (codigo_barras, nome) VALUES ('3017620422003', 'Outro');
        RAISE EXCEPTION 'FALHOU R1 (código duplicado aceito)';
    EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK  R1  código de barras duplicado é recusado';
    END;

    -- R1: nome obrigatório
    BEGIN
        INSERT INTO alimento (codigo_barras, nome) VALUES ('7890000000017', '   ');
        RAISE EXCEPTION 'FALHOU R1 (nome vazio aceito)';
    EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK  R1  alimento sem nome é recusado';
    END;

    -- R1: formato do código (8 a 14 dígitos)
    BEGIN
        INSERT INTO alimento (codigo_barras, nome) VALUES ('12AB', 'Teste');
        RAISE EXCEPTION 'FALHOU R1 (código inválido aceito)';
    EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK  R1  código fora do formato é recusado';
    END;

    -- R2: o mesmo vínculo alimento-grupo não se repete
    INSERT INTO classificado_em VALUES (a, g);
    BEGIN
        INSERT INTO classificado_em VALUES (a, g);
        RAISE EXCEPTION 'FALHOU R2';
    EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK  R2  vínculo alimento-grupo duplicado é recusado';
    END;

    -- R3/R4: um valor por par alimento-nutriente
    INSERT INTO tem_composicao VALUES (a, n, 6.3);
    BEGIN
        INSERT INTO tem_composicao VALUES (a, n, 7.0);
        RAISE EXCEPTION 'FALHOU R3';
    EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK  R3  segundo valor para o mesmo nutriente é recusado';
    END;

    -- R4: composição exige alimento e nutriente existentes
    BEGIN
        INSERT INTO tem_composicao VALUES (a, 99999, 1);
        RAISE EXCEPTION 'FALHOU R4';
    EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'OK  R4  composição de nutriente inexistente é recusada';
    END;

    -- R4: a base só pode ser g ou ml
    BEGIN
        UPDATE alimento SET base_unidade = 'kg' WHERE id_alimento = a;
        RAISE EXCEPTION 'FALHOU R4 (base kg aceita)';
    EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK  R4  base diferente de g ou ml é recusada';
    END;

    -- R5: nome de nutriente não se repete
    BEGIN
        INSERT INTO nutriente (nome_nutriente, unidade_padrao) VALUES ('proteins', 'mg');
        RAISE EXCEPTION 'FALHOU R5';
    EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK  R5  nutriente duplicado é recusado';
    END;

    -- R6: porção exige alimento; nome de medida não se repete no mesmo alimento
    INSERT INTO porcao VALUES (a, '15 g', 15, 'g');
    BEGIN
        INSERT INTO porcao VALUES (a, '15 g', 20, 'g');
        RAISE EXCEPTION 'FALHOU R6 (chave parcial)';
    EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK  R6  porção repetida no mesmo alimento é recusada';
    END;
    BEGIN
        INSERT INTO porcao VALUES (99999, '15 g', 15, 'g');
        RAISE EXCEPTION 'FALHOU R6 (porção sem alimento)';
    EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'OK  R6  porção sem alimento é recusada';
    END;

    -- R7: valor ausente não vira zero (não há linha); negativo é recusado
    BEGIN
        INSERT INTO tem_composicao (id_alimento, id_nutriente, valor)
        VALUES (a, (SELECT id_nutriente FROM nutriente WHERE nome_nutriente = 'fat'), NULL);
        RAISE EXCEPTION 'FALHOU R7 (nulo aceito)';
    EXCEPTION WHEN not_null_violation THEN RAISE NOTICE 'OK  R7  valor nulo não é gravado como composição';
    END;
    BEGIN
        INSERT INTO tem_composicao (id_alimento, id_nutriente, valor)
        VALUES (a, (SELECT id_nutriente FROM nutriente WHERE nome_nutriente = 'fat'), -1);
        RAISE EXCEPTION 'FALHOU R7 (negativo aceito)';
    EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK  R7  valor negativo é recusado';
    END;

    -- Entidade fraca: remover o alimento remove suas porções e composições
    DELETE FROM alimento WHERE id_alimento = a;
    IF EXISTS (SELECT 1 FROM porcao WHERE id_alimento = a)
       OR EXISTS (SELECT 1 FROM tem_composicao WHERE id_alimento = a) THEN
        RAISE EXCEPTION 'FALHOU entidade fraca';
    END IF;
    RAISE NOTICE 'OK  R6  porções e composições somem junto com o alimento';
END $$;

ROLLBACK;
