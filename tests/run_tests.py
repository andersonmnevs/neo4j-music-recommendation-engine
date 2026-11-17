"""Valida carga e recomendacoes contra o Neo4j em execucao (sem dependencias).

Uso: NEO4J_PASSWORD=... python tests/run_tests.py   (le .env se existir)
"""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTAINER = "music-recommender-neo4j"


def load_env():
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text().splitlines():
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


def q(cypher):
    """Executa Cypher e devolve linhas (lista de listas de strings)."""
    r = subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "cypher-shell",
         "-u", os.environ.get("NEO4J_USER", "neo4j"),
         "-p", os.environ["NEO4J_PASSWORD"], "--format", "plain"],
        input=cypher, capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(r.stderr.strip())
    lines = r.stdout.strip().splitlines()[1:]  # descarta cabecalho
    return [[c.strip().strip('"') for c in l.split(", ")] for l in lines]


def one(cypher):
    return q(cypher)[0][0]


TESTS = []


def test(fn):
    TESTS.append(fn)
    return fn


@test
def counts_match_csv():
    for label, csv in [("User", "users"), ("Song", "songs"), ("Artist", "artists"), ("Genre", "genres")]:
        expected = sum(1 for _ in open(ROOT / "data" / f"{csv}.csv", encoding="utf-8")) - 1
        assert int(one(f"MATCH (n:{label}) RETURN count(n)")) == expected, label


@test
def every_song_has_artist_and_genre():
    assert one("MATCH (s:Song) WHERE NOT (s)-[:PERFORMED_BY]->() OR NOT (s)-[:HAS_GENRE]->() RETURN count(s)") == "0"


@test
def no_duplicate_relationships():
    assert one("MATCH (u:User)-[r:LISTENED]->(s:Song) WITH u, s, count(r) AS c WHERE c > 1 RETURN count(*)") == "0"


@test
def relationship_properties_valid():
    assert one("MATCH ()-[l:LISTENED]->() WHERE l.play_count < 1 OR l.last_played IS NULL RETURN count(l)") == "0"


def recommendation_queries():
    """Le as queries R1-R3 de cypher/02_recommendations.cypher."""
    text = (ROOT / "cypher" / "02_recommendations.cypher").read_text(encoding="utf-8")
    body = "\n".join(l for l in text.splitlines() if not l.startswith((":param", "//")))
    return [st.strip() for st in body.split(";\n") if st.strip()][:3]


@test
def recs_never_include_heard_songs():
    for uid in (1, 7, 23, 50):
        heard = {r[0] for r in q(f"MATCH (:User {{id:{uid}}})-[:LISTENED]->(s:Song) RETURN s.title")}
        for i, query in enumerate(recommendation_queries(), 1):
            cy = query.replace("$userId", str(uid)).replace("$limit", "10")
            rows = q(cy)
            assert rows, f"R{i} vazia para user {uid}"
            leaked = [r[0] for r in rows if r[0] in heard]
            assert not leaked, f"R{i} user {uid} recomendou ja ouvidas: {leaked}"


@test
def collaborative_top_rec_is_in_users_taste():
    # A recomendacao principal deve ser de um genero que o usuario ja escuta
    cy = """
    MATCH (me:User {id: 1})-[:LISTENED]->(s:Song)<-[:LISTENED]-(peer:User) WHERE peer <> me
    WITH me, peer, count(s) AS common ORDER BY common DESC LIMIT 20
    MATCH (peer)-[:LISTENED]->(rec:Song)-[:HAS_GENRE]->(g:Genre) WHERE NOT (me)-[:LISTENED]->(rec)
    WITH me, g, count(*) AS n ORDER BY n DESC LIMIT 1
    RETURN EXISTS { (me)-[:LISTENED]->(:Song)-[:HAS_GENRE]->(g) }"""
    assert one(cy) == "TRUE"


@test
def every_user_gets_recommendations():
    cy = """
    MATCH (me:User)
    WHERE NOT EXISTS { (me)-[:LISTENED]->(:Song)<-[:LISTENED]-(:User)-[:LISTENED]->(r:Song)
                       WHERE NOT (me)-[:LISTENED]->(r) }
    RETURN count(me)"""
    assert one(cy) == "0"


if __name__ == "__main__":
    load_env()
    failed = 0
    for t in TESTS:
        try:
            t()
            print(f"PASS {t.__name__}")
        except Exception as e:  # noqa: BLE001
            failed += 1
            print(f"FAIL {t.__name__}: {e!r}")
    sys.exit(1 if failed else 0)
