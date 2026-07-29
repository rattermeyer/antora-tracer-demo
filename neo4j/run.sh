#!/usr/bin/env bash
# =============================================================================
# Neo4j Helper — Antora Tracer Traceability Graph
# =============================================================================
# Usage:
#   ./neo4j/run.sh up       # Start Neo4j, copy CSVs, auto-import data
#   ./neo4j/run.sh import   # Copy CSVs & re-import into running Neo4j
#   ./neo4j/run.sh shell    # Open cypher-shell
#   ./neo4j/run.sh down     # Stop and remove container
#   ./neo4j/run.sh logs     # Follow Neo4j logs
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/compose.yml"
CSV_DIR="$PROJECT_DIR/public/docs/tracer/latest/_attachments/traceability"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $*${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

wait_for_neo4j() {
  echo -n "Waiting for Neo4j..."
  for i in $(seq 1 30); do
    if curl -s -o /dev/null http://localhost:7474 2>/dev/null; then
      echo -e " ${GREEN}ready!${NC}"
      return 0
    fi
    sleep 2
    echo -n "."
  done
  echo -e " ${RED}timeout!${NC}"
  exit 1
}

copy_files() {
  # Copy CSVs and Cypher scripts into the container (avoids bind-mount chown issues)
  echo "Copying files into Neo4j..."
  docker compose -f "$COMPOSE_FILE" cp "$CSV_DIR/nodes.csv"       neo4j:/var/lib/neo4j/import/nodes.csv
  docker compose -f "$COMPOSE_FILE" cp "$CSV_DIR/relationships.csv" neo4j:/var/lib/neo4j/import/relationships.csv
  docker compose -f "$COMPOSE_FILE" cp "$SCRIPT_DIR/import.cypher"   neo4j:/var/lib/neo4j/import/import.cypher
  docker compose -f "$COMPOSE_FILE" cp "$SCRIPT_DIR/queries.cypher"  neo4j:/var/lib/neo4j/import/queries.cypher
  docker compose -f "$COMPOSE_FILE" exec -T neo4j chown -R neo4j:neo4j /var/lib/neo4j/import/
  echo -e "${GREEN}✓ Files copied${NC}"
}

cmd_up() {
  banner "Starting Neo4j..."
  docker compose -f "$COMPOSE_FILE" up -d
  wait_for_neo4j

  copy_files
  cmd_import

  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  Neo4j Browser:  http://localhost:7474${NC}"
  echo -e "${GREEN}  Bolt URL:       bolt://localhost:7687${NC}"
  echo -e "${GREEN}  Username:       neo4j${NC}"
  echo -e "${GREEN}  Password:       tracer123${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "Example queries: ${CYAN}./neo4j/run.sh shell -f import/queries.cypher${NC}"
}

cmd_import() {
  banner "Importing traceability data..."

  # Verify Neo4j is running
  if ! curl -s -o /dev/null http://localhost:7474; then
    echo -e "${RED}Error: Neo4j is not running. Run './neo4j/run.sh up' first.${NC}"
    exit 1
  fi

  # Run the import Cypher script
  docker compose -f "$COMPOSE_FILE" exec -T neo4j \
    cypher-shell -u neo4j -p tracer123 \
    -f /var/lib/neo4j/import/import.cypher

  echo ""
  echo -e "${GREEN}✓ Import complete. Open http://localhost:7474 to explore.${NC}"
}

cmd_reimport() {
  # Clean + reimport
  banner "Re-importing (full reset)..."
  copy_files

  echo "Clearing existing data..."
  docker compose -f "$COMPOSE_FILE" exec -T neo4j \
    cypher-shell -u neo4j -p tracer123 \
    "MATCH (n) DETACH DELETE n;"

  cmd_import
}

cmd_shell() {
  docker compose -f "$COMPOSE_FILE" exec neo4j \
    cypher-shell -u neo4j -p tracer123 "$@"
}

cmd_down() {
  banner "Stopping Neo4j..."
  docker compose -f "$COMPOSE_FILE" down
}

cmd_logs() {
  docker compose -f "$COMPOSE_FILE" logs -f neo4j
}

cmd_usage() {
  echo "Usage: $0 {up|import|reimport|shell|down|logs}"
  echo ""
  echo "  up        Start Neo4j, copy CSVs, import traceability data"
  echo "  import    Import CSVs into running Neo4j (appends to existing data)"
  echo "  reimport  Copy CSVs, clear all data, then re-import fresh"
  echo "  shell     Open cypher-shell (pass extra args, e.g. -f queries.cypher)"
  echo "  down      Stop and remove the Neo4j container"
  echo "  logs      Follow Neo4j logs"
  exit 0
}

case "${1:-}" in
  up)       cmd_up ;;
  import)   cmd_import ;;
  reimport) cmd_reimport ;;
  shell)    shift; cmd_shell "$@" ;;
  down)     cmd_down ;;
  logs)     cmd_logs ;;
  *)        cmd_usage ;;
esac
