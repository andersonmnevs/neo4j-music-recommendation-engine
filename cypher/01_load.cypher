// =====================================================================
// 01_load.cypher - Carga dos CSVs (idempotente: usa MERGE)
// Os CSVs ficam em ./data, montado em /var/lib/neo4j/import no container,
// por isso as URLs usam file:///arquivo.csv
// Cada bloco roda em transacoes de 500 linhas (CALL ... IN TRANSACTIONS).
// =====================================================================

// ---- Generos --------------------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///genres.csv' AS row
CALL {
  WITH row
  MERGE (g:Genre {id: toInteger(row.id)})
  SET g.name = row.name
} IN TRANSACTIONS OF 500 ROWS;

// ---- Artistas -------------------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///artists.csv' AS row
CALL {
  WITH row
  MERGE (a:Artist {id: toInteger(row.id)})
  SET a.name = row.name, a.country = row.country
} IN TRANSACTIONS OF 500 ROWS;

// ---- Musicas + relacoes com artista e genero ------------------------
LOAD CSV WITH HEADERS FROM 'file:///songs.csv' AS row
CALL {
  WITH row
  MERGE (s:Song {id: toInteger(row.id)})
  SET s.title = row.title,
      s.year = toInteger(row.year),
      s.duration_sec = toInteger(row.duration_sec)
  WITH s, row
  MATCH (a:Artist {id: toInteger(row.artist_id)})
  MATCH (g:Genre  {id: toInteger(row.genre_id)})
  MERGE (s)-[:PERFORMED_BY]->(a)
  MERGE (s)-[:HAS_GENRE]->(g)
  // Relacao derivada: acelera consultas "artistas do genero X"
  MERGE (a)-[:PLAYS_GENRE]->(g)
} IN TRANSACTIONS OF 500 ROWS;

// ---- Usuarios -------------------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
CALL {
  WITH row
  MERGE (u:User {id: toInteger(row.id)})
  SET u.name = row.name, u.country = row.country, u.age = toInteger(row.age)
} IN TRANSACTIONS OF 500 ROWS;

// ---- Interacao: escutou (propriedades na aresta) --------------------
LOAD CSV WITH HEADERS FROM 'file:///listened.csv' AS row
CALL {
  WITH row
  MATCH (u:User {id: toInteger(row.user_id)})
  MATCH (s:Song {id: toInteger(row.song_id)})
  MERGE (u)-[l:LISTENED]->(s)
  SET l.play_count = toInteger(row.play_count),
      l.last_played = date(row.last_played)
} IN TRANSACTIONS OF 500 ROWS;

// ---- Interacao: curtiu ----------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///likes.csv' AS row
CALL {
  WITH row
  MATCH (u:User {id: toInteger(row.user_id)})
  MATCH (s:Song {id: toInteger(row.song_id)})
  MERGE (u)-[l:LIKED]->(s)
  SET l.liked_at = date(row.liked_at)
} IN TRANSACTIONS OF 500 ROWS;

// ---- Interacao: segue artista ---------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///follows.csv' AS row
CALL {
  WITH row
  MATCH (u:User {id: toInteger(row.user_id)})
  MATCH (a:Artist {id: toInteger(row.artist_id)})
  MERGE (u)-[f:FOLLOWS]->(a)
  SET f.since = date(row.since)
} IN TRANSACTIONS OF 500 ROWS;

// ---- Verificacao ----------------------------------------------------
MATCH (n) RETURN labels(n)[0] AS label, count(*) AS total ORDER BY label;
