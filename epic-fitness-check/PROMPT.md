# Epic Fitness Check Assessment Prompt

## Purpose
Score each exported Jira epic against five quality frameworks to determine
whether it is ready for AI-first development and PI Planning commitment.

## Frameworks and Scoring

### 1. GROOMING READINESS (Yes / Partial / No — score ≥ 7/10)
Score each criterion. G1–G5 are mandatory blockers.

| ID  | Criterion                                              | Mandatory |
|-----|--------------------------------------------------------|-----------|
| G1  | Title < 10 words, follows [Product]|[Domain]|[Feature] | YES       |
| G2  | Problem statement documented (need, not solution)      | YES       |
| G3  | Acceptance criteria defined at epic level              | YES       |
| G4  | Business value / outcome articulated (not cost code)   | YES       |
| G5  | Reviewed by named stakeholder (PO/PM/BO named)        | YES       |
| G6  | Dependencies identified (or explicitly "None")         | NO        |
| G7  | Risks and assumptions logged                           | NO        |
| G8  | Size estimate (T-shirt or story points)                | NO        |
| G9  | Definition of Done documented                          | NO        |
| G10 | Linked to parent REQ or strategic objective            | NO        |

Scoring: Yes = 1, Partial = 0.5, No = 0
Pass threshold: ≥ 7/10 AND G1–G5 all = Yes

### 2. INVEST (Rating 1–5 per criterion — score ≥ 22/30)
Any criterion rated 1 = automatic NOT READY.

| Criterion      | 5 = Fully meets              | 1 = Does not meet             |
|----------------|------------------------------|-------------------------------|
| Independent    | No coupling to other epics   | Tightly coupled / blocked     |
| Negotiable     | Scope is flexible            | Fully prescriptive solution   |
| Valuable       | Quantified business outcome  | No value statement            |
| Estimable      | Enough detail to estimate    | Far too vague                 |
| Small          | Fits 1–2 PIs                 | Unbounded scope               |
| Testable       | Clear measurable AC present  | No AC whatsoever              |

### 3. QUS — Quality User Story (Met / Partial / Not Met — score ≥ 9/11)
Q1, Q5, Q6 are mandatory (must all be Met).

Individual: Q1 Well-formed · Q2 Atomic · Q3 Minimal · Q4 Understandable
            Q5 Problem-oriented · Q6 Unambiguous · Q7 Conflict-free
Set-level:  Q8 Unique · Q9 Uniform · Q10 Independent · Q11 Complete

### 4. IEEE 29148:2018 (Rating 1–3 per characteristic — score ≥ 18/24)
I2, I3, I6 must each score ≥ 2.

I1 Correct · I2 Unambiguous · I3 Complete · I4 Consistent
I5 Ranked · I6 Verifiable · I7 Modifiable · I8 Traceable

### 5. ISTQB Testability (Rating 1–5 per dimension — score ≥ 28/40)
T1, T2, T7 must each score ≥ 3.

T1 Observability · T2 Controllability · T3 Decomposability · T4 Simplicity
T5 Stability · T6 Understandability · T7 Traceability · T8 Non-functional

## Scoring Signals (keyword/content heuristics)

### High-confidence PASS signals (+)
- Given/When/Then format in description → AC quality up
- Numbers/percentages with units → Unambiguous, Verifiable up
- "Definition of Done" heading with checklist → G9, INVEST T up
- Parent link (REQ-XXXXX) present → G10, IEEE I8 up
- Named Business Owner / PM in metadata → G5 Yes
- T-shirt size or story point range in text → G8 Yes, INVEST E up
- "As a [role], I want, so that" present → QUS Q1 Met
- NFR table or performance/security targets → ISTQB T8 up

### High-confidence FAIL signals (-)
- "to be detailed", "TBD", "Phase N requirements" → IEEE I3 = 1, G2 = No
- No acceptance criteria section → G3 = No, INVEST T ≤ 2
- "user" or "system" as sole role → QUS Q1 = Partial
- No Definition of Done → G9 = No
- No numeric targets (fast, quick, simple, large) → IEEE I2 = 1, QUS Q6 Not Met
- No parent REQ link → G10 = No, IEEE I8 = 1
- No size estimate → G8 = No, INVEST E ≤ 2

## Output per epic
- Individual Excel workbook (8 sheets: Cover, Grooming, INVEST, QUS, IEEE, ISTQB, Summary, Actions)
- Colour coding: GREEN (#E2EFDA) pass, YELLOW (#FFFFC0) partial, RED (#FCE4D6) fail
- Pre-populated input cells based on scores above
- Formula-driven totals and verdicts

## Summary workbook
- One row per epic
- Score columns colour-coded against thresholds
- Portfolio statistics block
- Hyperlinks to individual workbooks

## Assessment email
- Short, precise, non-complaining tone
- Include AI-first development framing
- Cover: total count, pass/fail split, top 3 gaps, immediate actions needed