# Roteiro de evidências visuais (prints)

Salve as imagens em `docs/images/` com os nomes abaixo e elas aparecem no README.

| Arquivo | Como gerar |
|---|---|
| `schema.png` | No Neo4j Browser (http://localhost:7474): `CALL db.schema.visualization()` |
| `b5_vizinhanca_usuario.png` | Query **B5** de `cypher/04_business_queries.cypher` (visão em grafo) |
| `b6_caminho_recomendacao.png` | Query **B6** (visão em grafo): mostra *por que* uma música é recomendada |
| `r3_recomendacoes.png` | Query **R3** de `cypher/02_recommendations.cypher` com `:param userId => 1` (visão em tabela) |
| `gds_similar_to.png` | `MATCH p=(:User {id:1})-[:SIMILAR_TO]->(:User) RETURN p` (após `./run.sh gds`) |

Dica: no Browser, rode `:param userId => 1` e `:param limit => 10` antes das queries R1–R4.
