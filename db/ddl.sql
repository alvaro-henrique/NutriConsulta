-- =====================================================================
-- NutriConsulta · esquema lógico (Etapa 4) · PostgreSQL 16
-- Cada tabela corresponde a uma entidade ou relacionamento do ERD
-- (seção 3.4) e cita as regras R da Etapa 1 que as restrições garantem.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;   -- busca por trecho do nome (C3)

-- ---------------------------------------------------------------------
-- Entidade ALIMENTO
-- ---------------------------------------------------------------------
CREATE TABLE alimento (
    id_alimento      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_barras    varchar(14) UNIQUE                                  -- R1: não se repete
                     CHECK (codigo_barras ~ '^[0-9]{8,14}$'),
    nome             varchar(200) NOT NULL CHECK (btrim(nome) <> ''),    -- R1: nome obrigatório
    marca            varchar(200),
    base_quantidade  numeric(6,2) NOT NULL DEFAULT 100
                     CHECK (base_quantidade > 0),                        -- R4
    base_unidade     varchar(2)   NOT NULL DEFAULT 'g'
                     CHECK (base_unidade IN ('g', 'ml')),                -- R4
    data_atualizacao timestamptz,                                        -- R9: data da fonte
    data_verificacao timestamptz  NOT NULL DEFAULT now()                 -- R9: última consulta
);
COMMENT ON TABLE alimento IS 'Entidade ALIMENTO (ERD 3.4). Regras R1, R4, R9.';

-- ---------------------------------------------------------------------
-- Entidade GRUPO_ALIMENTAR
-- ---------------------------------------------------------------------
CREATE TABLE grupo_alimentar (
    id_grupo   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_grupo varchar(200) NOT NULL UNIQUE CHECK (btrim(nome_grupo) <> '')  -- R2
);
COMMENT ON TABLE grupo_alimentar IS 'Entidade GRUPO_ALIMENTAR (ERD 3.4). Regra R2.';

-- ---------------------------------------------------------------------
-- Entidade NUTRIENTE
-- ---------------------------------------------------------------------
CREATE TABLE nutriente (
    id_nutriente   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_nutriente varchar(60) NOT NULL UNIQUE CHECK (btrim(nome_nutriente) <> ''),  -- R5
    unidade_padrao varchar(10) NOT NULL CHECK (btrim(unidade_padrao) <> '')          -- R5
);
COMMENT ON TABLE nutriente IS 'Entidade NUTRIENTE (ERD 3.4). Regra R5.';

-- ---------------------------------------------------------------------
-- Relacionamento CLASSIFICADO_EM (N:M, participação parcial dos dois lados)
-- ---------------------------------------------------------------------
CREATE TABLE classificado_em (
    id_alimento integer NOT NULL REFERENCES alimento (id_alimento) ON DELETE CASCADE,
    id_grupo    integer NOT NULL REFERENCES grupo_alimentar (id_grupo) ON DELETE RESTRICT,
    PRIMARY KEY (id_alimento, id_grupo)                                   -- R2
);
COMMENT ON TABLE classificado_em IS 'Relacionamento N:M CLASSIFICADO_EM (ERD 3.4). Regra R2.';

-- ---------------------------------------------------------------------
-- Relacionamento TEM_COMPOSICAO (N:M com atributo próprio)
-- ---------------------------------------------------------------------
CREATE TABLE tem_composicao (
    id_alimento  integer NOT NULL REFERENCES alimento (id_alimento) ON DELETE CASCADE,
    id_nutriente integer NOT NULL REFERENCES nutriente (id_nutriente) ON DELETE RESTRICT,
    valor        numeric(12,4) NOT NULL CHECK (valor >= 0),               -- R7: ausente = sem linha
    PRIMARY KEY (id_alimento, id_nutriente)                               -- R3, R4
);
COMMENT ON TABLE tem_composicao IS 'Relacionamento N:M TEM_COMPOSICAO (ERD 3.4). Regras R3, R4, R7.';

-- ---------------------------------------------------------------------
-- Entidade fraca PORCAO + relacionamento de identificação POSSUI_PORCAO
-- ---------------------------------------------------------------------
CREATE TABLE porcao (
    id_alimento integer NOT NULL REFERENCES alimento (id_alimento) ON DELETE CASCADE,
    nome_medida varchar(60)  NOT NULL CHECK (btrim(nome_medida) <> ''),
    quantidade  numeric(10,2) NOT NULL CHECK (quantidade > 0),
    unidade     varchar(2)   NOT NULL CHECK (unidade IN ('g', 'ml')),
    PRIMARY KEY (id_alimento, nome_medida)                                -- R6: chave parcial
);
COMMENT ON TABLE porcao IS 'Entidade fraca PORCAO, identificada por ALIMENTO via POSSUI_PORCAO (ERD 3.4). Regra R6.';

-- ---------------------------------------------------------------------
-- Índices para as funções da Etapa 3 (além das chaves primárias e únicas)
-- ---------------------------------------------------------------------
-- C3 pesquisar_alimentos_por_nome: busca por trecho do nome, sem diferenciar maiúsculas
CREATE INDEX idx_alimento_nome_trgm ON alimento USING gin (lower(nome) gin_trgm_ops);

-- C4 listar_alimentos_por_grupo e C5 listar_grupos: partem do grupo
-- (a chave primária começa por id_alimento e só atende C2)
CREATE INDEX idx_classificado_grupo ON classificado_em (id_grupo, id_alimento);

-- Chave estrangeira de tem_composicao para nutriente: evita varredura
-- completa ao verificar a restrição quando um nutriente é removido (G3)
CREATE INDEX idx_composicao_nutriente ON tem_composicao (id_nutriente);
