#!/usr/bin/env bash
# Orquestra o projeto. Uso: ./run.sh [up|load|gds|recs <userId>|business|test|all|down]
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] && set -a && . ./.env && set +a
: "${NEO4J_PASSWORD:?defina NEO4J_PASSWORD no .env}"
C=music-recommender-neo4j
cs() { docker exec -i "$C" cypher-shell -u "${NEO4J_USER:-neo4j}" -p "$NEO4J_PASSWORD" "$@"; }

wait_ready() {
  echo "Aguardando Neo4j..."
  for _ in $(seq 1 40); do cs "RETURN 1" >/dev/null 2>&1 && return 0; sleep 3; done
  echo "Neo4j nao respondeu a tempo" >&2; exit 1
}

case "${1:-all}" in
  up)       docker compose up -d && wait_ready ;;
  load)     cs < cypher/00_schema.cypher && cs < cypher/01_load.cypher ;;
  gds)      cs < cypher/03_gds_similarity.cypher ;;
  recs)     { echo ":param userId => ${2:-1};"; grep -v '^:param userId' cypher/02_recommendations.cypher; } | cs ;;
  business) cs < cypher/04_business_queries.cypher ;;
  test)     python tests/run_tests.py ;;
  down)     docker compose down ;;
  all)      "$0" up && "$0" load && "$0" gds && "$0" test ;;
  *)        echo "Uso: $0 [up|load|gds|recs <userId>|business|test|all|down]"; exit 1 ;;
esac
