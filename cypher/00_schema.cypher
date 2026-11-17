// =====================================================================
// 00_schema.cypher - Constraints e indices (idempotente)
//
// Modelo:
//   (:User)-[:LISTENED {play_count, last_played}]->(:Song)
//   (:User)-[:LIKED {liked_at}]->(:Song)
//   (:User)-[:FOLLOWS {since}]->(:Artist)
//   (:Song)-[:PERFORMED_BY]->(:Artist)
//   (:Song)-[:HAS_GENRE]->(:Genre)
//   (:Artist)-[:PLAYS_GENRE]->(:Genre)   (derivada na carga)
// =====================================================================

// Unicidade: tambem cria o indice de busca por id e protege o MERGE
CREATE CONSTRAINT user_id   IF NOT EXISTS FOR (u:User)   REQUIRE u.id IS UNIQUE;
CREATE CONSTRAINT song_id   IF NOT EXISTS FOR (s:Song)   REQUIRE s.id IS UNIQUE;
CREATE CONSTRAINT artist_id IF NOT EXISTS FOR (a:Artist) REQUIRE a.id IS UNIQUE;
CREATE CONSTRAINT genre_id  IF NOT EXISTS FOR (g:Genre)  REQUIRE g.id IS UNIQUE;

// Obs: constraints de existencia (IS NOT NULL) exigem Enterprise Edition;
// na Community a validacao fica a cargo do script de carga/testes.
CREATE CONSTRAINT genre_name_unique IF NOT EXISTS FOR (g:Genre) REQUIRE g.name IS UNIQUE;

// Indices de apoio para filtros frequentes
CREATE INDEX song_title IF NOT EXISTS FOR (s:Song)   ON (s.title);
CREATE INDEX song_year  IF NOT EXISTS FOR (s:Song)   ON (s.year);
CREATE INDEX artist_name IF NOT EXISTS FOR (a:Artist) ON (a.name);
CREATE INDEX listened_count IF NOT EXISTS FOR ()-[l:LISTENED]-() ON (l.play_count);
