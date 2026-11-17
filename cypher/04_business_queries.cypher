// =====================================================================
// 04_business_queries.cypher - Perguntas de negocio respondidas pelo grafo
// Sugestao para prints: rode no Neo4j Browser (http://localhost:7474) e
// alterne para a visao em grafo nas queries marcadas com [GRAFO].
// =====================================================================

// B1. Quais sao as 10 musicas mais ouvidas da plataforma?
MATCH (:User)-[l:LISTENED]->(s:Song)-[:PERFORMED_BY]->(a:Artist)
RETURN s.title AS song, a.name AS artist, sum(l.play_count) AS plays, count(*) AS listeners
ORDER BY plays DESC LIMIT 10;

// B2. Qual a participacao de cada genero nas escutas?
MATCH (:User)-[l:LISTENED]->(:Song)-[:HAS_GENRE]->(g:Genre)
WITH g, sum(l.play_count) AS plays
WITH collect({g: g.name, plays: plays}) AS rows, sum(plays) AS total
UNWIND rows AS r
RETURN r.g AS genre, r.plays AS plays, round(100.0 * r.plays / total, 1) AS pct
ORDER BY plays DESC;

// B3. Quais artistas tem mais seguidores e quantos deles tambem curtiram musicas?
MATCH (a:Artist)<-[:FOLLOWS]-(u:User)
WITH a, collect(u) AS fans
RETURN a.name AS artist, size(fans) AS followers,
       size([u IN fans WHERE EXISTS { (u)-[:LIKED]->(:Song)-[:PERFORMED_BY]->(a) }]) AS fansWhoLiked
ORDER BY followers DESC LIMIT 10;

// B4. Quais usuarios tem gosto mais parecido com o usuario 1? (comunidade de gosto)
MATCH (u:User {id: 1})-[:LISTENED]->(s:Song)<-[:LISTENED]-(peer:User)
RETURN peer.name AS peer, count(s) AS sharedSongs
ORDER BY sharedSongs DESC LIMIT 5;

// B5. [GRAFO] Vizinhanca do usuario 1: o que ele ouviu e os generos envolvidos
MATCH p = (u:User {id: 1})-[:LISTENED]->(s:Song)-[:HAS_GENRE]->(:Genre)
RETURN p LIMIT 40;

// B6. [GRAFO] Por que recomendar? Caminho usuario -> musica em comum -> par -> musica nova
// (usa os 3 pares mais parecidos com o usuario 1)
MATCH (me:User {id: 1})-[:LISTENED]->(c:Song)<-[:LISTENED]-(peer:User)
WITH me, peer, count(c) AS common ORDER BY common DESC LIMIT 3
MATCH (me)-[:LISTENED]->(shared:Song)<-[:LISTENED]-(peer)
WITH me, peer, collect(shared)[..3] AS sharedSample
UNWIND sharedSample AS shared
MATCH (peer)-[:LISTENED]->(rec:Song)
WHERE NOT (me)-[:LISTENED]->(rec)
WITH me, shared, peer, rec LIMIT 40
RETURN me, shared, peer, rec;

// B7. Quais generos "pontes" ligam comunidades? (usuarios que ouvem 3+ generos)
MATCH (u:User)-[:LISTENED]->(:Song)-[:HAS_GENRE]->(g:Genre)
WITH u, collect(DISTINCT g.name) AS genres
WHERE size(genres) >= 3
RETURN u.name AS user, size(genres) AS genreCount, genres
ORDER BY genreCount DESC LIMIT 10;

// B8. Musicas "escondidas": curtidas por muitos mas com poucas escutas totais
MATCH (s:Song)<-[:LIKED]-(u:User)
WITH s, count(u) AS likes
MATCH (s)<-[l:LISTENED]-(:User)
WITH s, likes, sum(l.play_count) AS plays
WHERE likes >= 3
RETURN s.title AS song, likes, plays, round(1.0 * likes / plays, 3) AS likeRate
ORDER BY likeRate DESC LIMIT 10;
