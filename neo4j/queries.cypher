// =============================================================================
// Example Cypher Queries — Antora Tracer Traceability Graph
// =============================================================================
// Use these in Neo4j Browser at http://localhost:7474
// Credentials: neo4j / tracer123
// =============================================================================

// ---------------------------------------------------------------------------
// 1. OVERVIEW — All nodes color-coded by role
// ---------------------------------------------------------------------------
MATCH (n:Item)
RETURN n;

// ---------------------------------------------------------------------------
// 2. Uncovered requirements (no VERIFIES relationship from tests)
// ---------------------------------------------------------------------------
MATCH (req:requirement)
WHERE NOT EXISTS((req)<-[:VERIFIES]-(:test))
RETURN req.id AS UncoveredRequirement, req.title AS Title
ORDER BY req.id;

// ---------------------------------------------------------------------------
// 3. Coverage summary — requirements with test/design coverage
// ---------------------------------------------------------------------------
MATCH (req:requirement)
OPTIONAL MATCH (req)<-[v:VERIFIES]-(:test)
OPTIONAL MATCH (req)<-[a:ADDRESSES]-(:design)
WITH req, count(DISTINCT v) AS testCount, count(DISTINCT a) AS designCount
RETURN req.id AS Requirement,
       testCount,
       designCount,
       CASE
         WHEN testCount > 0 AND designCount > 0 THEN 'Fully Covered'
         WHEN testCount > 0 OR designCount > 0 THEN 'Partially Covered'
         ELSE 'Uncovered'
       END AS CoverageStatus
ORDER BY CoverageStatus, req.id;

// ---------------------------------------------------------------------------
// 4. Traceability chain — follow requirements through design to tests
// ---------------------------------------------------------------------------
MATCH path = (req:requirement)<-[:ADDRESSES]-(d:design)-[:ADDRESSES]->(other:requirement)
WHERE req <> other
RETURN path
LIMIT 20;

// ---------------------------------------------------------------------------
// 5. Impact analysis — what breaks if a requirement changes?
// ---------------------------------------------------------------------------
MATCH (req:requirement {id: 'REQ-001'})<-[*1..3]-(impacted)
RETURN req, impacted;

// ---------------------------------------------------------------------------
// 6. Most-connected items (hub nodes in the traceability graph)
// ---------------------------------------------------------------------------
MATCH (n:Item)-[r]-()
RETURN n.id AS Item, n.role AS Role, count(r) AS Connections
ORDER BY Connections DESC
LIMIT 10;

// ---------------------------------------------------------------------------
// 7. Requirements covered by each test
// ---------------------------------------------------------------------------
MATCH (t:test)-[:VERIFIES]->(req:requirement)
RETURN t.id AS Test, collect(req.id) AS RequirementsVerified
ORDER BY t.id;

// ---------------------------------------------------------------------------
// 8. Requirements addressed by each design artifact
// ---------------------------------------------------------------------------
MATCH (d:design)-[:ADDRESSES]->(req:requirement)
RETURN d.id AS DesignArtifact, collect(req.id) AS RequirementsAddressed
ORDER BY d.id;

// ---------------------------------------------------------------------------
// 9. Cross-role relationship matrix (role → role → count)
// ---------------------------------------------------------------------------
MATCH (a:Item)-[r]->(b:Item)
RETURN labels(a)[1] AS SourceRole, type(r) AS Relation, labels(b)[1] AS TargetRole, count(*) AS Count
ORDER BY Count DESC;

// ---------------------------------------------------------------------------
// 10. Orphan items — items with no relationships at all
// ---------------------------------------------------------------------------
MATCH (n:Item)
WHERE NOT (n)--()
RETURN n.id AS OrphanItem, n.role AS Role, n.title AS Title
ORDER BY n.id;

// ---------------------------------------------------------------------------
// 11. Full trace from any node — see complete neighborhood (great for visualization)
// ---------------------------------------------------------------------------
MATCH (n:Item {id: 'ARC-001'})-[r]-(related)
RETURN n, r, related;

// ---------------------------------------------------------------------------
// 12. Shortest path between two arbitrary items
// ---------------------------------------------------------------------------
MATCH (start:Item {id: 'TST-007'}), (end:Item {id: 'REQ-024'})
MATCH path = shortestPath((start)-[*..5]-(end))
RETURN path;
