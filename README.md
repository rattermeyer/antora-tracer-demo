# Antora Tracer — Self-Traceability Demo

A demo project showcasing [antora-tracer](https://github.com/rattermeyer/antora-tracer), an Antora extension that adds role-based requirements traceability to AsciiDoc documentation. Includes a Neo4j setup for graph-based exploration of the generated traceability data.

## Prerequisites

- **Node.js 18+** (with `npx`)
- **Docker** and Docker Compose (for Neo4j)
- **curl** (for health checks)

## Quick Start

```bash
# 1. Install dependencies
npm install

# 2. Build the Antora documentation site
npx antora antora-playbook.yml

# 3. Serve the site to browse locally
npx serve public/docs
# Or: python3 -m http.server 8080 -d public/docs

# 4. (In another terminal) Start Neo4j and import traceability data
./neo4j/run.sh up
```

## Project Structure

```
├── antora-playbook.yml   # Antora build configuration
├── compose.yml           # Neo4j Docker Compose service
├── package.json          # Node dependencies (antora, antora-tracer, kroki)
├── neo4j/
│   ├── run.sh            # Neo4j control script (up/down/import/shell/logs)
│   ├── import.cypher     # Cypher script to load CSVs into Neo4j
│   └── queries.cypher    # Example Cypher queries for analysis
└── public/docs/          # Generated site output (gitignored)
    └── tracer/latest/_attachments/traceability/
        ├── nodes.csv           # Exported nodes for Neo4j import
        └── relationships.csv   # Exported relationships for Neo4j import
```

## Building the Documentation

```bash
npx antora antora-playbook.yml
```

This pulls AsciiDoc content from the [antora-tracer examples](https://github.com/rattermeyer/antora-tracer), processes traceability items (requirements, designs, tests), generates traceability matrices (HTML + CSV), and writes the output to `public/docs/`.

The traceability CSV exports (`nodes.csv`, `relationships.csv`) are written to:
```
public/docs/tracer/latest/_attachments/traceability/
```

## Browsing the Generated Site

After building, serve the static site:

```bash
npx serve public/docs
```

Then open the URL printed by `serve` (typically `http://localhost:3000/docs`). Key pages:

- **Dashboard** — global coverage chart and per-item relationship graphs
- **Traceability Matrices** — requirements ↔ design and requirements ↔ tests coverage tables with clickable links
- **Architecture** — design documents with embedded PlantUML diagrams

> **Note:** The site uses URLs prefixed with `/docs` to match the Antora playbook configuration (`site.url: https://antora-tracer.conemso.de/docs`).

## Neo4j — Graph Exploration

### Starting & Importing

```bash
# Start Neo4j, copy CSV files, and import the traceability graph
./neo4j/run.sh up
```

This will:
1. Start a Neo4j 5 Community Edition container
2. Wait for it to be healthy
3. Copy `nodes.csv`, `relationships.csv`, and Cypher scripts into the container
4. Create indexes, load nodes (with `:Item` + role-specific labels like `:requirement`, `:design`, `:test`), and load relationships (typed as `:ADDRESSES`, `:VERIFIES`, etc.)
5. Display connection details

### Accessing Neo4j Browser

Open [http://localhost:7474](http://localhost:7474) and log in with:

| Field    | Value        |
|----------|--------------|
| URL      | `bolt://localhost:7687` |
| Username | `neo4j`      |
| Password | `tracer123`  |

The Neo4j Browser provides an interactive graph visualization. Run `MATCH (n) RETURN n` to see all nodes color-coded by role, then click to explore.

### Commands Reference

| Command | Description |
|---------|-------------|
| `./neo4j/run.sh up` | Start Neo4j + copy files + import data |
| `./neo4j/run.sh import` | Import CSVs (appends to existing data) |
| `./neo4j/run.sh reimport` | Copy fresh CSVs, clear all data, re-import |
| `./neo4j/run.sh shell` | Open `cypher-shell` inside the container |
| `./neo4j/run.sh shell -f import/queries.cypher` | Run all example queries |
| `./neo4j/run.sh down` | Stop and remove the container |
| `./neo4j/run.sh logs` | Follow Neo4j logs |

### Example Queries

Copy and paste these into the Neo4j Browser query pane, or run via `./neo4j/run.sh shell`:

```cypher
// Uncovered requirements (no VERIFIES from tests)
MATCH (req:requirement)
WHERE NOT EXISTS((req)<-[:VERIFIES]-(:test))
RETURN req.id AS UncoveredRequirement, req.title AS Title;

// Coverage summary per requirement
MATCH (req:requirement)
OPTIONAL MATCH (req)<-[v:VERIFIES]-(:test)
OPTIONAL MATCH (req)<-[a:ADDRESSES]-(:design)
RETURN req.id, count(DISTINCT v) AS tests, count(DISTINCT a) AS designs,
  CASE WHEN count(DISTINCT v) > 0 AND count(DISTINCT a) > 0 THEN 'Fully Covered'
       WHEN count(DISTINCT v) > 0 OR count(DISTINCT a) > 0 THEN 'Partially Covered'
       ELSE 'Uncovered' END AS Status
ORDER BY Status, req.id;

// Impact analysis — what's connected to REQ-001?
MATCH (req:requirement {id: 'REQ-001'})<-[*1..3]-(impacted)
RETURN req, impacted;

// Shortest path between a test and a requirement
MATCH (start:Item {id: 'TST-007'}), (end:Item {id: 'REQ-024'})
MATCH path = shortestPath((start)-[*..5]-(end))
RETURN path;
```

More queries in [`neo4j/queries.cypher`](neo4j/queries.cypher).

## How the Tracer Works

The Antora Tracer extension:

1. Parses `[item, role=requirement]` blocks and inline `relation:TARGET[]` macros from AsciiDoc content during the Antora build
2. Builds an in-memory traceability graph with configurable roles and relations
3. Validates relationships against role-based rules
4. Generates HTML traceability matrices with coverage calculations and clickable links
5. Exports the graph as `nodes.csv` / `relationships.csv` for Neo4j

The current demo uses the `self-traceability` preset, where the antora-tracer project traces itself — its own requirements, designs, and tests.
