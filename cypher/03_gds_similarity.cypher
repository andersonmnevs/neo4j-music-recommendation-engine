// =====================================================================
// 03_gds_similarity.cypher - Similaridade entre usuarios com GDS
// Node Similarity (Jaccard) sobre a projecao User-[:LISTENED]->Song,
// gravando relacoes :SIMILAR_TO {score} para recomendar via vizinhos.
// Rode depois da carga; e idempotente (remove a projecao e as arestas antigas).
// =====================================================================

// 1. Limpa execucoes anteriores
CALL gds.graph.drop('listens', false) YIELD graphName RETURN graphName;
MATCH ()-[r:SIMILAR_TO]->() DELETE r;

// 2. Projecao em memoria
CALL gds.graph.project('listens', ['User', 'Song'], 'LISTENED')
YIELD graphName, nodeCount, relationshipCount
RETURN graphName, nodeCount, relationshipCount;

// 3. Node Similarity: top 10 vizinhos por usuario (cutoff evita ruido)
CALL gds.nodeSimilarity.write('listens', {
  writeRelationshipType: 'SIMILAR_TO',
  writeProperty: 'score',
  topK: 10,
  similarityCutoff: 0.05
})
YIELD nodesCompared, relationshipsWritten
RETURN nodesCompared, relationshipsWritten;

// 4. Recomendacao usando os vizinhos pre-calculados (rapida em leitura)
:param userId => 1;
:param limit => 10;
MATCH (me:User {id: $userId})-[sim:SIMILAR_TO]->(peer:User)-[:LISTENED]->(rec:Song)
WHERE NOT (me)-[:LISTENED]->(rec)
MATCH (rec)-[:PERFORMED_BY]->(a:Artist), (rec)-[:HAS_GENRE]->(g:Genre)
RETURN rec.title AS song, a.name AS artist, g.name AS genre,
       round(sum(sim.score), 3) AS score,
       count(DISTINCT peer) AS similarPeers
ORDER BY score DESC LIMIT $limit;

// 5. Libera a memoria
CALL gds.graph.drop('listens') YIELD graphName RETURN graphName;
