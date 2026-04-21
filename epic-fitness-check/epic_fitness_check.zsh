#!/usr/bin/env bash
# Compatible with both bash and zsh
# =============================================================================
#  epic_fitness_check.zsh
#  AI-Driven Epic Fitness Check
#
#  Invokes Claude Code (YOLO mode) or Devin to read exported Jira epic
#  .doc/.docx files (or pull via Jira MCP), assess them against 5 quality
#  frameworks using AI, and generate:
#    - One fitness-check workbook per epic  (openpyxl .xlsx)
#    - A portfolio summary workbook
#    - A draft assessment email  (Markdown)
#
#  Input Modes:
#    FILE mode (default) — reads .doc/.docx files from a directory
#    MCP mode (--mcp --jira) — pulls epics live from Jira via MCP (IDs on CLI)
#    MCP-interactive mode (--mcpi --jira) — verifies Jira MCP connection, then
#                                           prompts for epic IDs interactively
#
#  Usage:
#    FILE mode:
#      ./epic_fitness_check.zsh --cly [DIR] [PORTFOLIO]
#      ./epic_fitness_check.zsh --dev [DIR] [PORTFOLIO]
#
#    MCP mode:
#      ./epic_fitness_check.zsh --cly --mcp --jira [PORTFOLIO] EPIC-1 EPIC-2 ...
#      ./epic_fitness_check.zsh --dev --mcp --jira [PORTFOLIO] EPIC-1 EPIC-2 ...
#
#    MCP-interactive mode:
#      ./epic_fitness_check.zsh --cly --mcpi --jira [PORTFOLIO]
#      ./epic_fitness_check.zsh --dev --mcpi --jira [PORTFOLIO]
#
#  Examples:
#    ./epic_fitness_check.zsh --cly ./Engage "Engage"
#    ./epic_fitness_check.zsh --dev ./Core   "Core"
#    ./epic_fitness_check.zsh --cly                         # current dir, auto-named
#    ./epic_fitness_check.zsh --cly --mcp --jira "Engage" ICS-21226 ICS-21799
#    ./epic_fitness_check.zsh --dev --mcp --jira "Core" REQ-7318 ICS-23947
#    ./epic_fitness_check.zsh --cly --mcpi --jira "Engage"  # interactive
#
#  Requires: claude CLI (for --cly) OR devin CLI (for --dev)
# =============================================================================

set -euo pipefail

# ── Parse args ──────────────────────────────────────────────────────────────
AI_MODE=""
INPUT_MODE="file"
MCP_SOURCE=""
POSITIONAL=()

for arg in "$@"; do
    case "$arg" in
        --cly)  AI_MODE="claude" ;;
        --dev)  AI_MODE="devin"  ;;
        --mcp)  INPUT_MODE="mcp" ;;
        --mcpi) INPUT_MODE="mcpi" ;;
        --jira) MCP_SOURCE="jira" ;;
        *)      POSITIONAL+=("$arg") ;;
    esac
done

if [[ -z "$AI_MODE" ]]; then
    echo "ERROR: Specify --cly (Claude Code) or --dev (Devin)"
    echo ""
    echo "Usage:"
    echo "  FILE mode:            $0 --cly|--dev [EPIC_DIR] [PORTFOLIO]"
    echo "  MCP mode:             $0 --cly|--dev --mcp  --jira [PORTFOLIO] EPIC-1 EPIC-2 ..."
    echo "  MCP-interactive mode: $0 --cly|--dev --mcpi --jira [PORTFOLIO]"
    exit 1
fi

if [[ "$INPUT_MODE" == "mcp" && -z "$MCP_SOURCE" ]]; then
    echo "ERROR: --mcp requires a source flag (currently supported: --jira)"
    echo "Usage: $0 --cly|--dev --mcp --jira [PORTFOLIO] EPIC-1 EPIC-2 ..."
    exit 1
fi

if [[ "$INPUT_MODE" == "mcpi" && -z "$MCP_SOURCE" ]]; then
    echo "ERROR: --mcpi requires a source flag (currently supported: --jira)"
    echo "Usage: $0 --cly|--dev --mcpi --jira [PORTFOLIO]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M')"

if [[ "$INPUT_MODE" == "mcp" ]]; then
    # MCP mode: first positional = portfolio name, rest = epic IDs
    PORTFOLIO="${POSITIONAL[0]:-mcp-epics}"
    EPIC_IDS=("${POSITIONAL[@]:1}")
    EPIC_COUNT=${#EPIC_IDS[@]}
    if [[ $EPIC_COUNT -eq 0 ]]; then
        echo "ERROR: No epic IDs provided"
        echo "Usage: $0 --cly|--dev --mcp --jira PORTFOLIO EPIC-1 EPIC-2 ..."
        exit 1
    fi
    EPIC_DIR="$(pwd)"
    OUTPUT_DIR="$EPIC_DIR/fitness_output"
    TMP_DIR="$EPIC_DIR/.epic_fitness_tmp"
    CONVERTED=0
elif [[ "$INPUT_MODE" == "mcpi" ]]; then
    # MCP-interactive mode: portfolio from positional, epic IDs gathered at runtime
    PORTFOLIO="${POSITIONAL[0]:-mcp-epics}"
    EPIC_IDS=()
    EPIC_COUNT=0
    EPIC_DIR="$(pwd)"
    OUTPUT_DIR="$EPIC_DIR/fitness_output"
    TMP_DIR="$EPIC_DIR/.epic_fitness_tmp"
    CONVERTED=0
else
    # FILE mode: first positional = epic dir, second = portfolio name
    EPIC_DIR="${POSITIONAL[0]:-$(pwd)}"
    PORTFOLIO="${POSITIONAL[1]:-$(basename "$EPIC_DIR")}"
    OUTPUT_DIR="$EPIC_DIR/fitness_output"
    TMP_DIR="$EPIC_DIR/.epic_fitness_tmp"
fi

mkdir -p "$TMP_DIR"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

log()  { echo -e "${BLUE}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[-]${NC} $*"; exit 1; }

AI_MODE_UPPER=$(echo "$AI_MODE" | tr '[:lower:]' '[:upper:]')

INPUT_MODE_UPPER=$(echo "$INPUT_MODE" | tr '[:lower:]' '[:upper:]')
MCP_SOURCE_UPPER=$(echo "$MCP_SOURCE" | tr '[:lower:]' '[:upper:]')

echo ""
echo -e "${BOLD}================================================================${NC}"
echo -e "${BOLD}  EPIC FITNESS CHECK — AI-DRIVEN${NC}"
if [[ "$INPUT_MODE" == "mcp" ]]; then
    echo -e "${BOLD}  Agent: ${AI_MODE_UPPER} | Source: MCP+${MCP_SOURCE_UPPER} | Portfolio: $PORTFOLIO${NC}"
    echo -e "${BOLD}  Epics: ${EPIC_IDS[*]}${NC}"
elif [[ "$INPUT_MODE" == "mcpi" ]]; then
    echo -e "${BOLD}  Agent: ${AI_MODE_UPPER} | Source: MCP+${MCP_SOURCE_UPPER} (interactive) | Portfolio: $PORTFOLIO${NC}"
else
    echo -e "${BOLD}  Agent: ${AI_MODE_UPPER} | Source: FILE | Portfolio: $PORTFOLIO${NC}"
fi
echo -e "${BOLD}  INVEST · QUS · IEEE 29148 · ISTQB · Grooming${NC}"
echo -e "${BOLD}================================================================${NC}"
echo ""

# ── Validate CLI tool ──────────────────────────────────────────────────────
if [[ "$AI_MODE" == "claude" ]]; then
    command -v claude >/dev/null 2>&1 || err "claude CLI not found. Install: npm install -g @anthropic-ai/claude-code"
    ok "Claude Code CLI found"
elif [[ "$AI_MODE" == "devin" ]]; then
    command -v devin >/dev/null 2>&1 || err "devin CLI not found. Install per Devin docs."
    ok "Devin CLI found"
fi

# ── Create output directory ─────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── MCP-interactive mode: verify Jira MCP, then collect epic IDs ────────────
# Track the rendered ephemeral MCP config so it can be used by the main agent
# invocation later and cleaned up on exit.
EPHEMERAL_MCP_CONFIG=""
cleanup_ephemeral_mcp() {
    [[ -n "$EPHEMERAL_MCP_CONFIG" && -f "$EPHEMERAL_MCP_CONFIG" ]] && rm -f "$EPHEMERAL_MCP_CONFIG"
}
trap cleanup_ephemeral_mcp EXIT

if [[ "$INPUT_MODE" == "mcpi" ]]; then
    echo ""
    echo -e "${BOLD}────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}  VERIFYING ${MCP_SOURCE_UPPER} MCP CONFIGURATION${NC}"
    echo -e "${BOLD}────────────────────────────────────────────────────────${NC}"
    echo ""

    if ! command -v claude >/dev/null 2>&1; then
        err "claude CLI not found — required to verify MCP config. Install: npm install -g @anthropic-ai/claude-code"
    fi
    if ! command -v envsubst >/dev/null 2>&1; then
        err "envsubst not found. Install: brew install gettext (may need 'brew link --force gettext')"
    fi

    # Step 1: load env vars from SCRIPT_DIR/.env so the config stays portable
    # across cwds and credentials never hit the global claude config.
    ENV_FILE="$SCRIPT_DIR/.env"
    MCP_TEMPLATE="$SCRIPT_DIR/mcp/jira.mcp.json.template"

    [[ -f "$ENV_FILE" ]]    || err ".env not found at $ENV_FILE — copy .env.example to .env and fill in values"
    [[ -f "$MCP_TEMPLATE" ]] || err "MCP template missing at $MCP_TEMPLATE"

    log "Loading credentials from $ENV_FILE"
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a

    # Fail fast if anything the template needs is blank.
    REQUIRED_VARS=(JIRA_URL JIRA_PERSONAL_TOKEN JIRA_SSL_VERIFY CONFLUENCE_URL CONFLUENCE_PERSONAL_TOKEN CONFLUENCE_SSL_VERIFY)
    for v in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!v:-}" ]]; then
            err "Required variable $v is empty in $ENV_FILE"
        fi
    done
    ok "Loaded ${#REQUIRED_VARS[@]} credential vars"

    # Step 2: render the template into a temp file. Restrict envsubst to our
    # named vars so unrelated $HOME / $PATH references in the template (if any)
    # are left alone.
    EPHEMERAL_MCP_CONFIG="$(mktemp -t epic_fitness_mcp.XXXXXX).json"
    envsubst '$JIRA_URL $JIRA_PERSONAL_TOKEN $JIRA_SSL_VERIFY $CONFLUENCE_URL $CONFLUENCE_PERSONAL_TOKEN $CONFLUENCE_SSL_VERIFY' \
        < "$MCP_TEMPLATE" > "$EPHEMERAL_MCP_CONFIG"
    chmod 600 "$EPHEMERAL_MCP_CONFIG"
    ok "Rendered ephemeral MCP config → $EPHEMERAL_MCP_CONFIG"

    # Step 3: live-test the connection. Pass --mcp-config so claude loads ONLY
    # the jira server for this invocation; no mutation of ~/.claude.json.
    log "Testing live connection to Jira MCP server (this may take ~15s to pull/start docker)..."
    JIRA_PING_PROMPT='List the tools exposed by the mcp-atlassian MCP server. If the server is unreachable or no atlassian tools are available, print the exact token JIRA_MCP_UNAVAILABLE and nothing else. Otherwise print the exact token JIRA_MCP_OK on its own line, followed by a newline and a comma-separated list of the tool names. Do not print any other commentary.'
    PING_OUT="$(unset CLAUDECODE; claude -p --mcp-config "$EPHEMERAL_MCP_CONFIG" --dangerously-skip-permissions "$JIRA_PING_PROMPT" 2>&1 || true)"

    if echo "$PING_OUT" | grep -q "JIRA_MCP_OK"; then
        ok "Jira MCP is responding"
        TOOLS_LINE="$(echo "$PING_OUT" | grep -v "JIRA_MCP_OK" | grep -v '^$' | head -n1)"
        [[ -n "$TOOLS_LINE" ]] && log "  tools: $TOOLS_LINE"
    elif echo "$PING_OUT" | grep -q "JIRA_MCP_UNAVAILABLE"; then
        echo "$PING_OUT" | sed 's/^/    /'
        err "Jira MCP reported UNAVAILABLE. Check docker daemon, network, and credentials in $ENV_FILE."
    else
        echo "$PING_OUT" | sed 's/^/    /'
        warn "Could not unambiguously confirm Jira MCP health; continuing anyway."
    fi

    # Step 4: interactively collect epic IDs.
    echo ""
    echo -e "${BOLD}────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}  ENTER JIRA EPIC IDS${NC}"
    echo -e "${BOLD}────────────────────────────────────────────────────────${NC}"
    echo ""
    echo "Paste epic IDs (space or newline separated). Submit an empty line to finish."
    echo "Example: ICS-21226 ICS-21799 REQ-7318"
    echo ""

    while IFS= read -r -p "epic> " line; do
        [[ -z "$line" ]] && break
        # Split on whitespace — supports both per-line and space-separated input.
        for tok in $line; do
            EPIC_IDS+=("$tok")
        done
    done

    EPIC_COUNT=${#EPIC_IDS[@]}
    if [[ $EPIC_COUNT -eq 0 ]]; then
        err "No epic IDs entered. Aborting."
    fi

    ok "Collected $EPIC_COUNT epic ID(s): ${EPIC_IDS[*]}"

    # Promote to mcp mode so the rest of the pipeline (prompt assembly,
    # .epic_ids.txt writeout, agent invocation) runs unchanged.
    INPUT_MODE="mcp"
    INPUT_MODE_UPPER="MCP"
fi

if [[ "$INPUT_MODE" == "file" ]]; then
    # ── FILE MODE: Discover, convert, and assemble corpus ────────────────────

    # ── Discover epic files ──────────────────────────────────────────────────
    log "Scanning $EPIC_DIR for epic files..."

    DOC_FILES=()
    while IFS= read -r -d '' f; do
        DOC_FILES+=("$f")
    done < <(find "$EPIC_DIR" -maxdepth 1 \( -name "*.doc" -o -name "*.docx" \) -print0 2>/dev/null | sort -z)

    EPIC_COUNT=${#DOC_FILES[@]}

    if [[ $EPIC_COUNT -eq 0 ]]; then
        err "No .doc or .docx files found in $EPIC_DIR"
    fi
    ok "Found $EPIC_COUNT epic files"

    # ── Convert docs to text ─────────────────────────────────────────────────
    log "Converting docs to text..."
    mkdir -p "$TMP_DIR/txt"

    # Convert using macOS textutil (primary) with soffice as fallback
    CONVERTED=0
    for f in "${DOC_FILES[@]}"; do
        fname="$(basename "$f")"
        base="${fname%.*}"
        outfile="$TMP_DIR/txt/$base.txt"

        # Try macOS textutil first (handles .doc and .docx natively)
        if command -v textutil >/dev/null 2>&1; then
            textutil -convert txt -output "$outfile" "$f" 2>/dev/null || true
        fi

        # Fallback to LibreOffice if textutil didn't produce output
        if [[ ! -f "$outfile" ]] || [[ ! -s "$outfile" ]]; then
            if command -v soffice >/dev/null 2>&1; then
                soffice --headless --convert-to "txt:Text" --outdir "$TMP_DIR/txt/" "$f" >/dev/null 2>&1 || true
            fi
        fi

        if [[ -f "$outfile" ]] && [[ -s "$outfile" ]]; then
            ((CONVERTED++)) || true
        else
            warn "Could not convert: $fname"
        fi
    done
    ok "Converted $CONVERTED / $EPIC_COUNT files"

    # ── Combine into corpus ──────────────────────────────────────────────────
    CORPUS="$TMP_DIR/corpus.txt"
    for f in "$TMP_DIR/txt/"*.txt; do
        base="$(basename "$f" .txt)"
        echo "" >> "$CORPUS"
        echo "$(printf '=%.0s' {1..80})" >> "$CORPUS"
        echo "### FILE: $base" >> "$CORPUS"
        echo "$(printf '=%.0s' {1..80})" >> "$CORPUS"
        grep -v "Generated at" "$f" >> "$CORPUS" || true
    done

    CORPUS_SIZE=$(wc -c < "$CORPUS")
    ok "Corpus assembled: $CORPUS_SIZE bytes ($EPIC_COUNT epics)"

    # ── Copy corpus to output for AI agent access ────────────────────────────
    cp "$CORPUS" "$OUTPUT_DIR/.corpus.txt"

elif [[ "$INPUT_MODE" == "mcp" ]]; then
    # ── MCP MODE: Epic IDs provided, AI agent will pull via Jira MCP ─────────
    ok "MCP mode: $EPIC_COUNT epic IDs to fetch via Jira MCP"
    for eid in "${EPIC_IDS[@]}"; do
        log "  → $eid"
    done

    # Write epic ID list for the AI agent
    printf '%s\n' "${EPIC_IDS[@]}" > "$OUTPUT_DIR/.epic_ids.txt"
    ok "Epic ID list written → $OUTPUT_DIR/.epic_ids.txt"
fi

# ── Write the AI prompt ─────────────────────────────────────────────────────
log "Writing AI assessment prompt..."

PROMPT_FILE="$TMP_DIR/prompt.md"

# ── Mode-specific intro ──────────────────────────────────────────────────────
if [[ "$INPUT_MODE" == "mcp" ]]; then
cat > "$PROMPT_FILE" << 'PROMPT_INTRO'
# Epic Fitness Check — AI Assessment Agent Prompt (MCP Mode)

You are an expert agile coach and quality engineer. Your job is to pull Jira
epics via the Jira MCP server, assess each one against 5 industry-standard
quality frameworks, then generate professional Excel workbooks and an assessment
email.

## CRITICAL INSTRUCTIONS

1. You have access to the **Jira MCP server**. Use it to fetch each epic listed below.
2. For each epic ID, use the Jira MCP `get_issue` tool to retrieve the full issue details
   (summary, description, status, priority, assignee, reporter, components, labels,
   acceptance criteria, linked issues, parent link, comments, and all custom fields).
3. Read the epic ID list at `{OUTPUT_DIR}/.epic_ids.txt` — one ID per line.
4. For EACH epic, perform a deep qualitative assessment using the 5 frameworks below.
5. Generate one `.xlsx` workbook per epic using openpyxl (exact format specified below).
6. Generate one portfolio summary `.xlsx` workbook.
7. Generate one `assessment_email.md` file.
8. All outputs go into `{OUTPUT_DIR}/`
9. Make sure `pip install openpyxl --break-system-packages -q` runs first if needed.
10. Also save the raw fetched data for each epic as `{OUTPUT_DIR}/.raw/{EPIC_ID}.json`

## EPIC IDs TO FETCH VIA JIRA MCP

{EPIC_ID_LIST}

PROMPT_INTRO
else
cat > "$PROMPT_FILE" << 'PROMPT_INTRO'
# Epic Fitness Check — AI Assessment Agent Prompt (File Mode)

You are an expert agile coach and quality engineer. Your job is to read exported
Jira epics, assess each one against 5 industry-standard quality frameworks, then
generate professional Excel workbooks and an assessment email.

## CRITICAL INSTRUCTIONS

1. Read the corpus file at `{OUTPUT_DIR}/.corpus.txt`
2. Parse it — each epic is delimited by `===...` lines with `### FILE: EPIC-ID`
3. For EACH epic, perform a deep qualitative assessment using the 5 frameworks below
4. Generate one `.xlsx` workbook per epic using openpyxl (exact format specified below)
5. Generate one portfolio summary `.xlsx` workbook
6. Generate one `assessment_email.md` file
7. All outputs go into `{OUTPUT_DIR}/`
8. Make sure `pip install openpyxl --break-system-packages -q` runs first if needed

PROMPT_INTRO
fi

# ── Shared frameworks, scoring guidelines, workbook/email format ──────────────
cat >> "$PROMPT_FILE" << 'PROMPT_SHARED'
## THE 5 FRAMEWORKS

### Framework 1: GROOMING READINESS (G1–G10)
Score each criterion: Yes / Partial / No. (Yes=1, Partial=0.5, No=0)
**Pass threshold:** Score ≥ 7/10 AND G1–G5 must ALL be "Yes" (mandatory blockers).

| ID  | Criterion                                              | Mandatory |
|-----|--------------------------------------------------------|-----------|
| G1  | Title < 10 words, follows [Product]\|[Domain]\|[Feature] | YES       |
| G2  | Problem statement documented (need, not solution)      | YES       |
| G3  | Acceptance criteria defined at epic level               | YES       |
| G4  | Business value / outcome articulated (not cost code)   | YES       |
| G5  | Reviewed by named stakeholder (PO/PM/BO named)        | YES       |
| G6  | Dependencies identified (or explicitly "None")         | NO        |
| G7  | Risks and assumptions logged                           | NO        |
| G8  | Size estimate (T-shirt or story points)                | NO        |
| G9  | Definition of Done documented                          | NO        |
| G10 | Linked to parent REQ or strategic objective            | NO        |

### Framework 2: INVEST (I/N/V/E/S/T)
Rate each 1–5. **Pass threshold:** Total ≥ 22/30 AND no criterion rated 1.

| Criterion   | 5 = Fully meets              | 1 = Does not meet             |
|-------------|------------------------------|-------------------------------|
| Independent | No coupling to other epics   | Tightly coupled / blocked     |
| Negotiable  | Scope is flexible            | Fully prescriptive solution   |
| Valuable    | Quantified business outcome  | No value statement            |
| Estimable   | Enough detail to estimate    | Far too vague                 |
| Small       | Fits 1–2 PIs                 | Unbounded scope               |
| Testable    | Clear measurable AC present  | No AC whatsoever              |

### Framework 3: QUS — Quality User Story (Q1–Q11)
Score: Met / Partial / Not Met. (Met=1, Partial=0.5, Not Met=0)
**Pass threshold:** ≥ 9/11 AND Q1, Q5, Q6 must all be "Met".

| ID  | Quality Criterion                                     | Category    |
|-----|-------------------------------------------------------|-------------|
| Q1  | Well-formed: "As a [role], I want [goal], so that..." | Individual  |
| Q2  | Atomic: single capability (not bundled)               | Individual  |
| Q3  | Minimal: no unnecessary detail                        | Individual  |
| Q4  | Conceptual: describes what, not how                   | Individual  |
| Q5  | Problem-oriented: not a solution description          | Individual  |
| Q6  | Unambiguous: specific, measurable language             | Individual  |
| Q7  | Conflict-free: no contradictions                      | Individual  |
| Q8  | Full sentence, grammatically correct                  | Set-level   |
| Q9  | Set is independent: no redundancy between epics        | Set-level   |
| Q10 | Set is complete: covers full user journey              | Set-level   |
| Q11 | Uniform: consistent format across the set              | Set-level   |

### Framework 4: IEEE 29148:2018 (I1–I8)
Rate 1–3. **Pass threshold:** ≥ 18/24 AND I2, I3, I6 each ≥ 2.

| ID | Characteristic   | Description                                               |
|----|------------------|-----------------------------------------------------------|
| I1 | Necessary        | Represents a genuine stakeholder need, not gold-plating.  |
| I2 | Unambiguous      | Single interpretation; measurable language used.          |
| I3 | Feasible         | Implementable within known tech and schedule constraints. |
| I4 | Consistent       | No logical conflict with other requirements.              |
| I5 | Prioritised      | Has explicit priority relative to other work items.       |
| I6 | Verifiable       | Can be confirmed by test, inspection, or analysis.        |
| I7 | Modifiable       | Change to one requirement doesn't cascade everywhere.     |
| I8 | Traceable        | Bi-directional link: back to need, forward to test/design.|

### Framework 5: ISTQB Testability (T1–T8)
Rate 1–5. **Pass threshold:** ≥ 28/40 AND T1, T2, T7 each ≥ 3.

| ID | Dimension          | Description                                            |
|----|--------------------|--------------------------------------------------------|
| T1 | Observability      | System state and outputs are visible and measurable.   |
| T2 | Controllability    | Test inputs and system state can be set by testers.    |
| T3 | Decomposability    | System can be tested in independent, manageable parts. |
| T4 | Simplicity         | Minimal functionality — nothing that doesn't need testing. |
| T5 | Stability          | System does not change in ways that invalidate tests.  |
| T6 | Understandability  | Design and behaviour are well-documented and clear.    |
| T7 | Traceability       | Requirements map to test cases. Each AC has a test.    |
| T8 | Non-functional     | NFR targets are explicit, measurable, and testable.    |

## HOW TO SCORE (AI ASSESSMENT GUIDELINES)

Read each epic's FULL text carefully. Use your judgment as an expert:

**For Grooming (Yes/Partial/No):**
- "Yes" = clear, unambiguous evidence in the epic text
- "Partial" = some evidence but incomplete or vague
- "No" = no evidence whatsoever
- Look for: user stories, acceptance criteria (Given/When/Then), Definition of Done,
  business value statements, stakeholder names, parent links, size estimates, risk/dep logs

**For INVEST (1–5):**
- Score based on the actual content quality, not just keyword presence
- A well-written quantified business outcome = 4–5 on Valuable
- "TBD" or placeholder text = 1–2 across most dimensions
- Real acceptance criteria with measurable outcomes = 4–5 on Testable

**For QUS (Met/Partial/Not Met):**
- "Met" = the quality criterion is clearly satisfied
- Evaluate both individual epic quality AND set-level quality (Q8–Q11)

**For IEEE (1–3):**
- 3 = fully meets the IEEE characteristic
- 2 = partially meets
- 1 = does not meet

**For ISTQB (1–5):**
- Score based on how testable the requirement actually is
- No acceptance criteria = T1, T2, T7 should be low (1–2)
- Well-written Given/When/Then with numbers = T1, T2, T7 should be high (4–5)

## WORKBOOK FORMAT — INDIVIDUAL EPIC

Use openpyxl. Each epic workbook has 7 tabs:

### Palette (use these exact hex values, no # prefix):
```python
NAVY="1F3864"; BLUE="2E75B6"; TEAL="1D6A8E"
LBLUE="DEEAF1"; YELLOW="FFFFC0"; GREEN="E2EFDA"
RED="FCE4D6"; GRAY="F2F2F2"; WHITE="FFFFFF"; ORANGE="C55A11"
```

### Tab 1: "Cover" (tab color: NAVY)
- Columns A(28), B(50), C(14)
- Row 1: merged A1:C3 header "EPIC FITNESS CHECK" (NAVY bg, white text, 14pt bold)
- Row 2: merged A2:C2 subheader "INVEST · QUS · IEEE 29148 · ISTQB · Grooming" (BLUE bg, 9pt)
- Row 4: merged section header "EPIC METADATA" (TEAL bg)
- Rows 5–15: metadata fields — Epic ID, Title, Status, PI, Priority, Epic Type,
  Product Manager, Engineering Lead, Business Owner, Parent Link, Scrum Team
  (labels in col A with NAVY bg white text right-aligned; values in col B with alternating GRAY/WHITE bg)
- Row 17: merged section header "OVERALL FITNESS VERDICT" (BLUE bg)
- Row 18: merged verdict cell — "✅ READY — All frameworks passed" (GREEN bg, dark green text)
  or "❌ NOT READY — See individual tabs and Actions" (RED bg, dark red text)

### Tab 2: "1-Grooming" (tab color: BLUE)
- Columns A(7), B(50), C(16), D(40)
- Row 1: section header "SECTION 1 — GROOMING READINESS" (NAVY bg)
- Row 2: subheader "G1–G5 are mandatory blockers. Score ≥ 7/10 required." (BLUE bg)
- Row 3: column headers #, Criterion, Status, Notes (BLUE bg, white 9pt)
- Rows 4–13: G1–G10 items. Status column (C) color-coded: Yes=GREEN, Partial=YELLOW, No=RED
  Notes column (D) in YELLOW bg for manual entry.
- Row 15: "GROOMING SCORE" label + formula: =COUNTIF(C4:C13,"Yes")+COUNTIF(C4:C13,"Partial")*0.5
- Row 16: "VERDICT" + formula: =IF(AND(COUNTIF(C4:C13,"Yes")+COUNTIF(C4:C13,"Partial")*0.5>=7,COUNTIF(C4:C8,"No")=0),"✅ PASS","❌ NOT READY")

### Tab 3: "2-INVEST" (tab color: TEAL)
- Columns A(7), B(22), C(16), D(44)
- Row 1: section header "SECTION 2 — INVEST" (NAVY bg)
- Row 2: subheader with pass criteria
- Row 3: column headers #, Criterion, Rating 1–5, Notes
- Rows 4–9: I/N/V/E/S/T. Rating column color-coded: ≥4=GREEN, 3=YELLOW, ≤2=RED
- Row 10: scale note
- Row 11: "INVEST SCORE" + formula: =SUM(C4:C9)
- Row 12: "VERDICT" + formula: =IF(AND(SUM(C4:C9)>=22,COUNTIF(C4:C9,1)=0),"✅ PASS","❌ NOT READY")

### Tab 4: "3-QUS" (tab color: GREEN)
- Columns A(7), B(7), C(42), D(16), E(38)
- Row 1: section header "SECTION 3 — QUS QUALITY USER STORY"
- Individual quality (Q1–Q7) rows then Set-level quality (Q8–Q11) rows
- Score column: Met=GREEN, Partial=YELLOW, Not Met=RED
- Score formula: =COUNTIF(D5:D11,"Met")+COUNTIF(D5:D11,"Partial")*0.5+COUNTIF(D15:D18,"Met")+COUNTIF(D15:D18,"Partial")*0.5
- Verdict formula: =IF(AND(total>=9,D5="Met",D9="Met",D10="Met"),"✅ PASS","❌ NOT READY")

### Tab 5: "4-IEEE" (tab color: YELLOW)
- Columns A(7), B(22), C(44), D(16), E(38)
- I1–I8 items rated 1–3. Color: 3=GREEN, 2=YELLOW, 1=RED
- Score: =SUM(D4:D11), threshold ≥18/24
- Verdict: =IF(AND(SUM(D4:D11)>=18,D5>=2,D6>=2,D9>=2),"✅ PASS","❌ NOT READY")

### Tab 6: "5-ISTQB" (tab color: FF0000)
- T1–T8 items rated 1–5. Color: ≥4=GREEN, 3=YELLOW, ≤2=RED
- Score: =SUM(D4:D11), threshold ≥28/40
- Verdict: =IF(AND(SUM(D4:D11)>=28,D4>=3,D5>=3,D11>=3),"✅ PASS","❌ NOT READY")

### Tab 7: "Summary" (tab color: 375623)
- Framework / Score / Threshold / Verdict — one row per framework
- Cross-tab formula references (e.g. ='1-Grooming'!C15)
- Overall decision formula combining all 5 verdicts
- Note at bottom: "See Jira-Updates tab for copy-paste ready content suggestions"

### Tab 8: "Actions" (tab color: ORANGE)
- Columns A(5), B(60), C(20), D(60)
- Row 1: section header "RECOMMENDED ACTIONS — Priority order" (ORANGE bg, white text)
- Row 2: column headers: #, Action (what to do and why), Priority, Suggested Jira Text (snippet)
- Numbered list of recommended actions specific to THIS epic's gaps
- Be specific: reference the actual gaps found (e.g. "Write Given/When/Then ACs — currently none exist")
- For EACH action, column D must contain a brief snippet of the suggested text (first ~100 chars) with a note "→ See Jira-Updates tab for full text"
- Priority column: HIGH (RED bg) = mandatory blockers, MEDIUM (YELLOW bg) = framework gaps, LOW (GREEN bg) = improvements

### Tab 9: "Jira-Updates" (tab color: 70AD47)
- Columns A(22), B(50), C(55), D(55), E(40)
- Row 1: merged header "SUGGESTED JIRA CONTENT UPDATES" (NAVY bg, white text, 13pt bold)
- Row 2: merged subheader "Review each row. If relevant, copy the SUGGESTED CONTENT cell and paste directly into the Jira field." (BLUE bg, white, 9pt)
- Row 3: column headers: Jira Field, Field Label, CURRENT CONTENT (Full), SUGGESTED CONTENT (Copy-paste ready), Why This Change Fixes It
- For EVERY gap or weakness identified across all 5 frameworks, add a row:
  - Col A: Jira field key (e.g. summary, description, customfield_acceptance_criteria, customfield_dod, customfield_business_value, customfield_size)
  - Col B: Human label (e.g. "Epic Title", "Description / Problem Statement", "Acceptance Criteria", "Definition of Done", "Business Value", "Size Estimate")
  - Col C: FULL current content verbatim from the epic — do NOT truncate. If field is empty/missing write "⚠️ EMPTY — Not set in Jira". Col C cell bg = RED (FCE4D6) for gaps, GREEN (E2EFDA) if already acceptable.
  - Col D: AI-generated REPLACEMENT or ADDITION text, ready to copy-paste into Jira. Must be complete and specific to this epic's domain. Col D cell bg = GREEN (E2EFDA) always. If no change needed write "✅ No change needed".
  - Col E: One sentence citing which framework criterion this satisfies (e.g. "Satisfies G3 — Acceptance Criteria defined at epic level"). Col E cell bg = YELLOW (FFFFC0).
- Wrap text ON for columns C and D. Row height auto-fit.
- ALWAYS generate content for these fields (even if some are already good):
  1. **Epic Title** — if not following [Product]|[Domain]|[Feature] pattern or >10 words, suggest a compliant title
  2. **Description / Problem Statement** — if solution-focused or vague, rewrite as a genuine problem statement ("The problem of... affects... the impact is... a successful solution would...")
  3. **Acceptance Criteria** — if missing or weak, generate 3–5 proper Given/When/Then scenarios derived from the epic's actual stated goals and domain context. Each scenario on its own line: "Given [precondition] / When [action] / Then [measurable outcome]"
  4. **Definition of Done** — if missing, generate a DoD checklist (8–12 items) appropriate for the epic type detected (API/backend, UI/frontend, data pipeline, integration, etc.)
  5. **Business Value** — if missing or just cost codes, rewrite as a quantified outcome statement ("Enables X, reducing Y by Z%, improving [metric] for [persona]")
  6. **Size / Effort Estimate** — if missing, suggest a T-shirt size (S/M/L/XL) with a brief rationale based on scope
  7. Any other specific gaps found during the 5-framework assessment
- After the gap rows, add a divider row then a "FIELDS ALREADY ACCEPTABLE" section listing fields that scored well (GREEN bg rows, "✅ No change needed" in col D)

### File naming: `{EPIC_ID}_Fitness_Check.xlsx`

## WORKBOOK FORMAT — PORTFOLIO SUMMARY

File: `00_{PORTFOLIO}_Summary_Fitness_Check.xlsx`

### Tab: "Portfolio Summary"
- Row 1: merged header "{PORTFOLIO} — EPIC FITNESS CHECK PORTFOLIO SUMMARY"
- Row 2: subheader with framework names
- Row 4: column headers: ID, Title, Status, PI, Grooming, INVEST, QUS, IEEE, ISTQB, Overall, Top Action
- Rows 5+: one row per epic with scores color-coded (GREEN if ≥ threshold, YELLOW if close, RED if far below)
- After all epics: "PORTFOLIO STATISTICS" section with Total, Ready count/%, Not Ready count/%,
  Average scores per framework, counts of missing AC/DoD/Parent Link

## EMAIL FORMAT

File: `assessment_email.md`

Write TWO email drafts:

### EMAIL 1 — CTO & Technical Leadership (AI-First Framing)
Subject: {PORTFOLIO} Epics Are Not AI-Ready — Action Needed Before PI Planning

Frame around AI-first development: well-structured epics feed directly into
AI-assisted engineering workflows (Cursor, Copilot, Claude Code). Poor epics
mean engineers spend time clarifying instead of building. Include:
- Total/ready/not-ready counts
- Top 3 gap areas with specific numbers
- Average framework scores vs thresholds
- Call to action: 30-min review meeting

### EMAIL 2 — Product Owners & Product Managers (Specific Actions)
Subject: Action Needed — {PORTFOLIO} Epic Quality for AI-First PI2 Delivery

Provide concrete PO actions:
1. Write Definition of Done (count missing)
2. Add Given/When/Then Acceptance Criteria (count missing)
3. Replace placeholder descriptions
4. Link to parent REQ/ARM (count missing)

Sign both emails as: Amit
PROMPT_SHARED

# ── Mode-specific execution plan ─────────────────────────────────────────────
if [[ "$INPUT_MODE" == "mcp" ]]; then
cat >> "$PROMPT_FILE" << 'PROMPT_EXEC'

## EXECUTION PLAN

Write a Python script that:
1. Uses the Jira MCP `get_issue` tool to fetch EACH epic by ID
2. For each epic, extract ALL fields: summary, description, status, priority,
   assignee, reporter, components, labels, acceptance criteria, linked issues,
   parent link, comments, custom fields (PI, scrum team, business owner, size estimate)
3. Save the raw fetched JSON for each epic to `{OUTPUT_DIR}/.raw/{EPIC_ID}.json`
4. Scores each epic against all 5 frameworks using YOUR AI judgment (not keyword matching)
5. Generates individual workbooks with all 9 tabs (including "Jira-Updates"), proper formatting, formulas, colors
6. For the "Jira-Updates" tab: include the FULL verbatim current content of every assessed field in column C,
   and generate complete copy-paste-ready suggested replacements in column D (not summaries — full text)
7. Generates portfolio summary workbook
8. Generates assessment email with real numbers
9. Prints progress to stdout

Run the script after writing it. Use `pip install openpyxl --break-system-packages -q` if needed.

All output files go in: `{OUTPUT_DIR}/`
Epic ID list is at: `{OUTPUT_DIR}/.epic_ids.txt`
Portfolio name is: `{PORTFOLIO}`
PROMPT_EXEC
else
cat >> "$PROMPT_FILE" << 'PROMPT_EXEC'

## EXECUTION PLAN

Write a Python script that:
1. Reads the corpus file
2. Parses each epic section
3. Extracts metadata (ID, title, status, PI, priority, PM, eng lead, BO, parent link, scrum team)
4. Scores each epic against all 5 frameworks using YOUR AI judgment (not keyword matching)
5. Generates individual workbooks with all 9 tabs (including "Jira-Updates"), proper formatting, formulas, colors
6. For the "Jira-Updates" tab: include the FULL verbatim current content of every assessed field in column C,
   and generate complete copy-paste-ready suggested replacements in column D (not summaries — full text).
   The PO should be able to read column D and paste it directly into Jira with zero editing needed.
7. Generates portfolio summary workbook
8. Generates assessment email with real numbers
9. Prints progress to stdout

Run the script after writing it. Use `pip install openpyxl --break-system-packages -q` if needed.

All output files go in: `{OUTPUT_DIR}/`
Corpus file is at: `{OUTPUT_DIR}/.corpus.txt`
Portfolio name is: `{PORTFOLIO}`
PROMPT_EXEC
fi

# ── Substitute placeholders in the prompt ────────────────────────────────────
sed -i '' "s|{OUTPUT_DIR}|$OUTPUT_DIR|g" "$PROMPT_FILE"
sed -i '' "s|{PORTFOLIO}|$PORTFOLIO|g" "$PROMPT_FILE"
sed -i '' "s|{TIMESTAMP}|$TIMESTAMP|g" "$PROMPT_FILE"
sed -i '' "s|{EPIC_COUNT}|$EPIC_COUNT|g" "$PROMPT_FILE"

# Substitute MCP-specific placeholders
if [[ "$INPUT_MODE" == "mcp" ]]; then
    EPIC_ID_LIST=$(printf '- `%s`\n' "${EPIC_IDS[@]}")
    # Use awk for multi-line substitution (sed can't handle newlines reliably)
    awk -v replacement="$EPIC_ID_LIST" '{gsub(/{EPIC_ID_LIST}/, replacement); print}' "$PROMPT_FILE" > "$PROMPT_FILE.tmp"
    mv "$PROMPT_FILE.tmp" "$PROMPT_FILE"
fi

ok "Prompt written ($( wc -w < "$PROMPT_FILE" ) words)"

# ── Copy prompt to output for reference ──────────────────────────────────────
cp "$PROMPT_FILE" "$OUTPUT_DIR/.prompt.md"

# ── Invoke the AI agent ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}  LAUNCHING AI AGENT: ${AI_MODE_UPPER}${NC}"
echo -e "${BOLD}────────────────────────────────────────────────────────${NC}"
echo ""

PROMPT_CONTENT="$(cat "$PROMPT_FILE")"

if [[ "$AI_MODE" == "claude" ]]; then
    log "Invoking Claude Code in YOLO mode (--dangerously-skip-permissions)..."
    log "Working directory: $OUTPUT_DIR"

    # Claude Code invocation:
    #   -p  = non-interactive (pipe mode — takes prompt, runs autonomously, exits)
    #   --dangerously-skip-permissions = YOLO mode (auto-approves all tool use)
    #   --mcp-config (only when --mcpi was used) = ephemeral jira MCP for this
    #     run only; never touches global claude config
    #   Unset CLAUDECODE to allow running from within an existing Claude session
    #   We cd into OUTPUT_DIR so Claude sees the corpus and writes output there
    (
        cd "$OUTPUT_DIR"
        unset CLAUDECODE
        if [[ -n "$EPHEMERAL_MCP_CONFIG" && -f "$EPHEMERAL_MCP_CONFIG" ]]; then
            claude -p --mcp-config "$EPHEMERAL_MCP_CONFIG" --dangerously-skip-permissions "$PROMPT_CONTENT"
        else
            claude -p --dangerously-skip-permissions "$PROMPT_CONTENT"
        fi
    )
    EXIT_CODE=$?

elif [[ "$AI_MODE" == "devin" ]]; then
    log "Invoking Devin in interactive mode..."
    log "Working directory: $OUTPUT_DIR"

    # Devin invocation:
    #   --permission-mode dangerous = auto-approves all tools (YOLO mode)
    #   --prompt-file               = seed the session with the assessment prompt
    #   Interactive mode (no -p flag) so you can watch Devin work
    #   We cd into OUTPUT_DIR so Devin sees the corpus and writes output there
    (
        cd "$OUTPUT_DIR"
        devin --permission-mode dangerous --prompt-file "$PROMPT_FILE"
    )
    EXIT_CODE=$?
fi

# ── Verify outputs ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}  VERIFYING OUTPUTS${NC}"
echo -e "${BOLD}────────────────────────────────────────────────────────${NC}"
echo ""

WORKBOOK_COUNT=$(find "$OUTPUT_DIR" -name "*_Fitness_Check.xlsx" -not -name "00_*" | wc -l)
SUMMARY_EXISTS=$(find "$OUTPUT_DIR" -name "00_*Summary*.xlsx" | wc -l)
EMAIL_EXISTS=$([[ -f "$OUTPUT_DIR/assessment_email.md" ]] && echo 1 || echo 0)

if [[ $WORKBOOK_COUNT -gt 0 ]]; then
    ok "Individual workbooks: $WORKBOOK_COUNT"
else
    warn "No individual workbooks found — AI agent may have used different naming"
fi

if [[ $SUMMARY_EXISTS -gt 0 ]]; then
    ok "Summary workbook: found"
else
    warn "Summary workbook: not found"
fi

if [[ $EMAIL_EXISTS -eq 1 ]]; then
    ok "Assessment email: found"
else
    warn "Assessment email: not found"
fi

# ── Final summary ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}================================================================${NC}"
echo -e "${BOLD}  COMPLETE${NC}"
echo -e "${BOLD}================================================================${NC}"
echo ""
echo -e "  AI Engine    : ${BOLD}${AI_MODE_UPPER}${NC}"
if [[ "$INPUT_MODE" == "mcp" ]]; then
    echo -e "  Input Source : ${BOLD}MCP + ${MCP_SOURCE_UPPER}${NC}"
else
    echo -e "  Input Source : ${BOLD}FILE${NC}"
fi
echo -e "  Portfolio    : ${BOLD}$PORTFOLIO${NC}"
echo -e "  Epics        : ${BOLD}$EPIC_COUNT${NC}"
if [[ "$INPUT_MODE" == "file" ]]; then
    echo -e "  Converted    : ${BOLD}$CONVERTED${NC}"
fi
echo -e "  Workbooks    : ${BOLD}$WORKBOOK_COUNT${NC}"
echo ""
echo -e "  Output dir   : ${BOLD}$OUTPUT_DIR${NC}"
echo ""

if [[ $WORKBOOK_COUNT -gt 0 || $SUMMARY_EXISTS -gt 0 ]]; then
    echo -e "  Files created:"
    find "$OUTPUT_DIR" -maxdepth 1 -name "*.xlsx" -o -name "*.md" | sort | while read f; do
        fname="$(basename "$f")"
        [[ "$fname" == .* ]] && continue
        echo -e "    * $fname"
    done
    echo ""
fi

echo -e "  ${YELLOW}Prompt used: $OUTPUT_DIR/.prompt.md${NC}"
if [[ "$INPUT_MODE" == "mcp" ]]; then
    echo -e "  ${YELLOW}Epic IDs: $OUTPUT_DIR/.epic_ids.txt${NC}"
else
    echo -e "  ${YELLOW}Corpus: $OUTPUT_DIR/.corpus.txt${NC}"
fi
echo ""

# ── Cleanup temp ─────────────────────────────────────────────────────────────
rm -rf "$TMP_DIR"

exit ${EXIT_CODE:-0}
