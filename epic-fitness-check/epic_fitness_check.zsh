#!/usr/bin/env bash
# Compatible with both bash and zsh
# =============================================================================
#  epic_fitness_check.zsh
#  AI-Driven Epic Fitness Check
#
#  Invokes Claude Code (YOLO mode) or Devin to read exported Jira epic
#  .doc/.docx files, assess them against 5 quality frameworks using AI,
#  and generate:
#    - One fitness-check workbook per epic  (openpyxl .xlsx)
#    - A portfolio summary workbook
#    - A draft assessment email  (Markdown)
#
#  Usage:
#    ./epic_fitness_check.zsh --cly [DIR] [PORTFOLIO]   # Claude Code YOLO
#    ./epic_fitness_check.zsh --dev [DIR] [PORTFOLIO]   # Devin YOLO
#
#  Examples:
#    ./epic_fitness_check.zsh --cly ./Engage "Engage"
#    ./epic_fitness_check.zsh --dev ./Core   "Core"
#    ./epic_fitness_check.zsh --cly                     # current dir, auto-named
#
#  Requires: claude CLI (for --cly) OR devin CLI (for --dev)
# =============================================================================

set -euo pipefail

# ── Parse args ──────────────────────────────────────────────────────────────
AI_MODE=""
POSITIONAL=()

for arg in "$@"; do
    case "$arg" in
        --cly) AI_MODE="claude" ;;
        --dev) AI_MODE="devin"  ;;
        *)     POSITIONAL+=("$arg") ;;
    esac
done

if [[ -z "$AI_MODE" ]]; then
    echo "ERROR: Specify --cly (Claude Code) or --dev (Devin)"
    echo "Usage: $0 --cly|--dev [EPIC_DIR] [PORTFOLIO_NAME]"
    exit 1
fi

EPIC_DIR="${POSITIONAL[0]:-$(pwd)}"
PORTFOLIO="${POSITIONAL[1]:-$(basename "$EPIC_DIR")}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
OUTPUT_DIR="$EPIC_DIR/fitness_output"
TMP_DIR="$(mktemp -d /tmp/epic_fitness_XXXXXX)"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M')"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

log()  { echo -e "${BLUE}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[-]${NC} $*"; exit 1; }

echo ""
echo -e "${BOLD}================================================================${NC}"
echo -e "${BOLD}  EPIC FITNESS CHECK — AI-DRIVEN${NC}"
echo -e "${BOLD}  Mode: ${AI_MODE^^} | Portfolio: $PORTFOLIO${NC}"
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

# ── Discover epic files ──────────────────────────────────────────────────────
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

# ── Convert docs to text ────────────────────────────────────────────────────
log "Converting docs to text..."
mkdir -p "$TMP_DIR/txt"

# Write the portable converter (handles sandboxed AF_UNIX sockets)
cat > "$TMP_DIR/convert.py" << 'CONVERT_EOF'
#!/usr/bin/env python3
import os, sys, socket, subprocess, tempfile
from pathlib import Path

_SHIM = Path(tempfile.gettempdir()) / "lo_socket_shim.so"
_SHIM_SRC = r"""
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <sys/socket.h>
static int (*_real_socket)(int,int,int) = NULL;
int socket(int domain, int type, int protocol) {
    if (!_real_socket) _real_socket = dlsym(RTLD_NEXT, "socket");
    if (domain == AF_UNIX) { errno = EAFNOSUPPORT; return -1; }
    return _real_socket(domain, type, protocol);
}
"""

def get_env():
    env = os.environ.copy()
    env["SAL_USE_VCLPLUGIN"] = "svp"
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.close()
    except OSError:
        if not _SHIM.exists():
            src = Path(tempfile.gettempdir()) / "lo_socket_shim.c"
            src.write_text(_SHIM_SRC)
            subprocess.run(["gcc","-shared","-fPIC","-o",str(_SHIM),str(src),"-ldl"],
                           check=True, capture_output=True)
            src.unlink()
        env["LD_PRELOAD"] = str(_SHIM)
    return env

if __name__ == "__main__":
    env = get_env()
    r = subprocess.run(["soffice","--headless","--convert-to","txt:Text",
                        "--outdir",sys.argv[2],sys.argv[1]], env=env, capture_output=True)
    sys.exit(r.returncode)
CONVERT_EOF

CONVERTED=0
for f in "${DOC_FILES[@]}"; do
    fname="$(basename "$f")"
    base="${fname%.*}"
    outfile="$TMP_DIR/txt/$base.txt"
    python3 "$TMP_DIR/convert.py" "$f" "$TMP_DIR/txt/" >/dev/null 2>&1 || true
    if [[ -f "$outfile" ]]; then
        ((CONVERTED++)) || true
    else
        warn "Could not convert: $fname"
    fi
done
ok "Converted $CONVERTED / $EPIC_COUNT files"

# ── Combine into corpus ────────────────────────────────────────────────────
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

# ── Create output directory ─────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── Copy corpus to output for AI agent access ───────────────────────────────
cp "$CORPUS" "$OUTPUT_DIR/.corpus.txt"

# ── Write the AI prompt ─────────────────────────────────────────────────────
log "Writing AI assessment prompt..."

PROMPT_FILE="$TMP_DIR/prompt.md"

cat > "$PROMPT_FILE" << 'PROMPT_HEREDOC'
# Epic Fitness Check — AI Assessment Agent Prompt

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

Read each epic's FULL exported text carefully. Use your judgment as an expert:

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

### Tab 8: "Actions" (tab color: ORANGE)
- Numbered list of recommended actions specific to THIS epic's gaps
- Be specific: reference the actual gaps found (e.g. "Write Given/When/Then ACs — currently none exist")

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

## EXECUTION PLAN

Write a Python script that:
1. Reads the corpus file
2. Parses each epic section
3. Extracts metadata (ID, title, status, PI, priority, PM, eng lead, BO, parent link, scrum team)
4. Scores each epic against all 5 frameworks using YOUR AI judgment (not keyword matching)
5. Generates individual workbooks with all 8 tabs, proper formatting, formulas, colors
6. Generates portfolio summary workbook
7. Generates assessment email with real numbers
8. Prints progress to stdout

Run the script after writing it. Use `pip install openpyxl --break-system-packages -q` if needed.

All output files go in: `{OUTPUT_DIR}/`
Corpus file is at: `{OUTPUT_DIR}/.corpus.txt`
Portfolio name is: `{PORTFOLIO}`
PROMPT_HEREDOC

# ── Substitute placeholders in the prompt ────────────────────────────────────
sed -i "s|{OUTPUT_DIR}|$OUTPUT_DIR|g" "$PROMPT_FILE"
sed -i "s|{PORTFOLIO}|$PORTFOLIO|g" "$PROMPT_FILE"
sed -i "s|{TIMESTAMP}|$TIMESTAMP|g" "$PROMPT_FILE"
sed -i "s|{EPIC_COUNT}|$EPIC_COUNT|g" "$PROMPT_FILE"

ok "Prompt written ($( wc -w < "$PROMPT_FILE" ) words)"

# ── Copy prompt to output for reference ──────────────────────────────────────
cp "$PROMPT_FILE" "$OUTPUT_DIR/.prompt.md"

# ── Invoke the AI agent ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}  LAUNCHING AI AGENT: ${AI_MODE^^}${NC}"
echo -e "${BOLD}────────────────────────────────────────────────────────${NC}"
echo ""

PROMPT_CONTENT="$(cat "$PROMPT_FILE")"

if [[ "$AI_MODE" == "claude" ]]; then
    log "Invoking Claude Code in YOLO mode (--dangerously-skip-permissions)..."
    log "Working directory: $OUTPUT_DIR"

    # Claude Code invocation:
    #   -p  = non-interactive (pipe mode — takes prompt, runs autonomously, exits)
    #   --dangerously-skip-permissions = YOLO mode (auto-approves all tool use)
    #   Unset CLAUDECODE to allow running from within an existing Claude session
    #   We cd into OUTPUT_DIR so Claude sees the corpus and writes output there
    (
        cd "$OUTPUT_DIR"
        unset CLAUDECODE
        claude -p --dangerously-skip-permissions "$PROMPT_CONTENT"
    )
    EXIT_CODE=$?

elif [[ "$AI_MODE" == "devin" ]]; then
    log "Invoking Devin in YOLO mode..."
    log "Working directory: $OUTPUT_DIR"

    # Devin invocation:
    #   --yes = auto-confirm (YOLO mode)
    #   -p    = prompt mode (non-interactive)
    #   We cd into OUTPUT_DIR so Devin sees the corpus and writes output there
    (
        cd "$OUTPUT_DIR"
        devin --yes -p "$PROMPT_CONTENT"
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
echo -e "  AI Engine    : ${BOLD}${AI_MODE^^}${NC}"
echo -e "  Portfolio    : ${BOLD}$PORTFOLIO${NC}"
echo -e "  Epics found  : ${BOLD}$EPIC_COUNT${NC}"
echo -e "  Converted    : ${BOLD}$CONVERTED${NC}"
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
echo -e "  ${YELLOW}Corpus: $OUTPUT_DIR/.corpus.txt${NC}"
echo ""

# ── Cleanup temp ─────────────────────────────────────────────────────────────
rm -rf "$TMP_DIR"

exit ${EXIT_CODE:-0}
