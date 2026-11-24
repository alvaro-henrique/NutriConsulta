# NutriConsulta

Banco de dados PostgreSQL 16 do NutriConsulta (trabalho de Banco de Dados), com Adminer para consulta pelo navegador.

## Estrutura

```
.
├── docker-compose.yml     # Postgres 16 + Adminer
└── db/
    ├── ddl.sql            # esquema lógico (executado na 1ª subida)
    └── testes_regras.sql  # testes das regras R (roda e faz ROLLBACK)
```

## Como subir

Pré-requisito: Docker Desktop aberto.

```bash
docker compose up -d
docker compose ps        # aguarde o db ficar "healthy"
```

| Serviço  | Endereço                | Credenciais     |
|----------|-------------------------|-----------------|
| Postgres | `localhost:5432`        | `nutri` / `nutri`, base `nutriconsulta` |
| Adminer  | http://localhost:8080   | Sistema PostgreSQL, servidor `db`, `nutri` / `nutri` |

## Testes das regras

```bash
docker compose exec -T db psql -U nutri -d nutriconsulta < db/testes_regras.sql
```

O script roda dentro de uma transação e desfaz tudo no fim, então não altera o banco.

## Recriar o banco do zero

O `ddl.sql` só roda quando o volume `dados` é criado. Para reaplicar o esquema (apaga todos os dados):

```bash
docker compose down -v
docker compose up -d
```
