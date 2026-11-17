// =====================================================================
// 02_recommendations.cypher - Recomendacoes para um usuario
// Uso no cypher-shell:  :param userId => 1;
// No Browser:           :param userId => 1
// Cada query retorna: song, artist, genre, score e reasons (explicacao).
// =====================================================================
:param userId => 1;
:param limit => 10;

// ---------------------------------------------------------------------
// R1. Filtragem colaborativa (usuarios com gosto parecido)
// Pergunta: "O que usuarios que ouviram as mesmas musicas que eu ouviram e eu nao?"
// Similaridade = Jaccard das musicas escutadas; o score da musica soma a
// similaridade dos vizinhos que a escutaram (considerando curtidas como bonus).
// ---------------------------------------------------------------------
MATCH (me:User {id: $userId})-[:LISTENED]->(s:Song)
WITH me, collect(s) AS mine
MATCH (me)-[:LISTENED]->(shared:Song)<-[:LISTENED]-(peer:User)
WHERE peer <> me
WITH me, mine, peer, count(shared) AS common
MATCH (peer)-[:LISTENED]->(ps:Song)
WITH me, mine, peer, common, count(ps) AS peerTotal
WITH me, peer, toFloat(common) / (size(mine) + peerTotal - common) AS similarity
ORDER BY similarity DESC LIMIT 20
MATCH (peer)-[l:LISTENED]->(rec:Song)
WHERE NOT (me)-[:LISTENED]->(rec)
OPTIONAL MATCH (peer)-[lk:LIKED]->(rec)
WITH rec, sum(similarity * (1 + CASE WHEN lk IS NULL THEN 0 ELSE 0.5 END)) AS score,
     count(DISTINCT peer) AS peers
MATCH (rec)-[:PERFORMED_BY]->(a:Artist), (rec)-[:HAS_GENRE]->(g:Genre)
RETURN rec.title AS song, a.name AS artist, g.name AS genre,
       round(score, 3) AS score,
       'Ouvida por ' + peers + ' usuario(s) com gosto parecido' AS reason
ORDER BY score DESC LIMIT $limit;

// ---------------------------------------------------------------------
// R2. Baseada em conteudo (generos preferidos + artistas seguidos)
// Pergunta: "Que musicas novas combinam com o que eu mais escuto?"
// Afinidade de genero = plays do usuario no genero / total de plays.
// Bonus de +0.3 se segue o artista; +0.1 se curtiu outra musica do artista.
// ---------------------------------------------------------------------
MATCH (me:User {id: $userId})-[l:LISTENED]->(:Song)-[:HAS_GENRE]->(g:Genre)
WITH me, g, sum(l.play_count) AS plays
WITH me, collect({genre: g, plays: plays}) AS gs, sum(plays) AS total
UNWIND gs AS x
WITH me, x.genre AS g, toFloat(x.plays) / total AS affinity
MATCH (rec:Song)-[:HAS_GENRE]->(g), (rec)-[:PERFORMED_BY]->(a:Artist)
WHERE NOT (me)-[:LISTENED]->(rec)
WITH me, rec, a, g, affinity,
     CASE WHEN (me)-[:FOLLOWS]->(a) THEN 0.3 ELSE 0 END AS followBonus,
     CASE WHEN EXISTS { (me)-[:LIKED]->(:Song)-[:PERFORMED_BY]->(a) } THEN 0.1 ELSE 0 END AS likeBonus
RETURN rec.title AS song, a.name AS artist, g.name AS genre,
       round(affinity + followBonus + likeBonus, 3) AS score,
       'Genero ' + g.name + ' (' + toString(toInteger(round(affinity * 100))) + '% das suas escutas)'
         + CASE WHEN followBonus > 0 THEN ' + voce segue ' + a.name ELSE '' END AS reason
ORDER BY score DESC, rec.year DESC LIMIT $limit;

// ---------------------------------------------------------------------
// R3. Hibrida (60% colaborativa + 40% conteudo, ambas normalizadas 0..1)
// Retorna as duas explicacoes combinadas.
// ---------------------------------------------------------------------
CALL () {
  // --- componente colaborativo
  MATCH (me:User {id: $userId})-[:LISTENED]->(s:Song)
  WITH me, collect(s) AS mine
  MATCH (me)-[:LISTENED]->(shared:Song)<-[:LISTENED]-(peer:User)
  WHERE peer <> me
  WITH me, mine, peer, count(shared) AS common
  MATCH (peer)-[:LISTENED]->(ps:Song)
  WITH me, mine, peer, common, count(ps) AS peerTotal
  WITH me, peer, toFloat(common) / (size(mine) + peerTotal - common) AS similarity
  ORDER BY similarity DESC LIMIT 20
  MATCH (peer)-[:LISTENED]->(rec:Song)
  WHERE NOT (me)-[:LISTENED]->(rec)
  WITH rec, sum(similarity) AS cf, count(DISTINCT peer) AS peers
  WITH collect({rec: rec, cf: cf, peers: peers}) AS rows, max(cf) AS maxCf
  UNWIND rows AS r
  RETURN r.rec AS rec, r.cf / maxCf AS cf, r.peers AS peers
}
CALL (rec) {
  // --- componente de conteudo para a mesma musica
  MATCH (me:User {id: $userId})-[l:LISTENED]->(:Song)-[:HAS_GENRE]->(g:Genre)
  WITH me, g, sum(l.play_count) AS plays
  WITH me, collect({g: g, plays: plays}) AS gs, sum(plays) AS total
  MATCH (rec)-[:HAS_GENRE]->(rg:Genre), (rec)-[:PERFORMED_BY]->(a:Artist)
  WITH me, a, rg, [x IN gs WHERE x.g = rg | toFloat(x.plays) / total] AS aff
  RETURN coalesce(head(aff), 0.0) AS cb,
         EXISTS { (me)-[:FOLLOWS]->(a) } AS follows, a.name AS artist, rg.name AS genre
}
WITH rec, cf, peers, cb, follows, artist, genre,
     0.6 * cf + 0.4 * (cb + CASE WHEN follows THEN 0.3 ELSE 0 END) AS score
RETURN rec.title AS song, artist, genre, round(score, 3) AS score,
       peers + ' usuario(s) parecido(s) ouviram; genero ' + genre
         + CASE WHEN follows THEN '; voce segue ' + artist ELSE '' END AS reason
ORDER BY score DESC LIMIT $limit;

// ---------------------------------------------------------------------
// R4. "Descobrir artistas": artistas seguidos pelos vizinhos que eu nao sigo
// ---------------------------------------------------------------------
MATCH (me:User {id: $userId})-[:FOLLOWS]->(:Artist)<-[:FOLLOWS]-(peer:User)-[:FOLLOWS]->(a:Artist)
WHERE peer <> me AND NOT (me)-[:FOLLOWS]->(a)
RETURN a.name AS artist, count(DISTINCT peer) AS followedByPeers
ORDER BY followedByPeers DESC, artist LIMIT $limit;
