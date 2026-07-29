// =============================================================================
// Neo4j Import Script — Antora Tracer Traceability Graph
// =============================================================================
// This script loads nodes.csv and relationships.csv into Neo4j.
// Run after starting: docker compose up -d
// Access Neo4j Browser at: http://localhost:7474
// Credentials: neo4j / tracer123
//
// To execute: paste this entire script into the Neo4j Browser query pane,
// or use cypher-shell:
//   docker compose exec neo4j cypher-shell -u neo4j -p tracer123 \
//     -f /var/lib/neo4j/import/import.cypher
// =============================================================================

// --- Clean slate (uncomment if re-importing) ---
// MATCH (n) DETACH DELETE n;

// ---------------------------------------------------------------------------
// 1. Create indexes for performance
// ---------------------------------------------------------------------------
CREATE INDEX item_id IF NOT EXISTS FOR (i:Item) ON (i.id);
CREATE INDEX item_role IF NOT EXISTS FOR (i:Item) ON (i.role);

// ---------------------------------------------------------------------------
// 2. Load nodes (items) from CSV
// ---------------------------------------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///nodes.csv' AS row
MERGE (n:Item {id: row.id})
SET n.title = row.title,
    n.role = row.role,
    n.status = row.status,
    n.sourceFile = row.sourceFile,
    n.content = row.content
WITH n, row
// Add a role-specific label for easy filtering
CALL apoc.create.addLabels(n, [row.role]) YIELD node
RETURN count(*) AS nodesLoaded;

// ---------------------------------------------------------------------------
// 3. Load relationships from CSV
// ---------------------------------------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///relationships.csv' AS row
MATCH (source:Item {id: row.source})
MATCH (target:Item {id: row.target})
CALL apoc.merge.relationship(
  source,
  toUpper(row.type),          // Relationship type, e.g. ADDRESSES, VERIFIES
  {id: row.id, sourceFile: row.sourceFile},
  {},
  target
) YIELD rel
RETURN count(*) AS relationshipsLoaded;

// ---------------------------------------------------------------------------
// 4. Verify import
// ---------------------------------------------------------------------------
MATCH (n:Item)
RETURN labels(n)[1] AS role, count(n) AS count
ORDER BY count DESC;

// Show relationship type counts
MATCH ()-[r]->()
RETURN type(r) AS relationshipType, count(r) AS count
ORDER BY count DESC;
