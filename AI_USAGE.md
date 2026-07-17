# AI Usage — MazePruebaFront

This document is the compliance record of AI tool usage for the Flutter mobile client of Arrow Maze, as required by the course's academic-integrity policy for AI-assisted work. It summarizes and evaluates the fragment-by-fragment ledger kept in `AI_HISTORY.MD`; it does not replace it.

## Tools Used

| Tool | Model / version cited in the log | Role in the team's workflow |
|---|---|---|
| Claude Code (Anthropic CLI) | Claude Opus, cited as "Opus 4.8", "Opus 4.6", and "Opus 4.8 (1M context)" | Primary implementation tool for the majority of logged fragments: architecture-level features, domain modeling, and all work the team explicitly reserved for Opus to protect visual/behavioral fidelity (e.g., the arrow-rendering and screen-layout phases, Entrada 029: *"Me interesa que los agentes que directamente tengan que ver con el diseño de cómo se ve sean opus"*). Also used for orchestration in the subagent-driven-development workflow. |
| Claude Code (Anthropic CLI) | Claude Sonnet, cited as "Sonnet 4.6" and "Sonnet 5" | TDD sub-agents (writing failing tests, then minimal implementations), mechanical migrations, CI/lint fixes, mid-complexity features, and later in the project the main driver for most fragments. |
| Claude Code (Anthropic CLI) | Claude Haiku 4.5 | One delegated, narrowly-specified fragment (`ProgressReconciler` domain service, Entrada 044/front#18 task 2) — used where the task was small and fully specified in the brief. |
| Claude Code (Anthropic CLI) | Codename "Fable 5" (a model identifier the log uses from 2026-07-08 onward) | Triage/grilling sessions (`/triage`, `/grilling`, `/domain-modeling` skills), bug fixes, and a large share of feature fragments in the second half of the project. |
| Antigravity IDE | Claude Opus 4.6 (Thinking mode) | Used for exactly two fragments (Entradas 027 and 028, Tasks 4.1 and 4.2: `CommandInvoker.clear()` and the `GamePlaying`/`GameController` rewrite), executed inline by phase with checkpoints — the only fragments in the ledger not attributed to the Claude Code CLI. |
| GitHub REST API (invoked from within a Claude Code session) | n/a | Used a handful of times to edit issue descriptions/specs as part of triage (e.g., Entrada 044/front#5, Entrada 058/front#12), not for code generation. |

Project-level skills referenced in the log as part of the workflow (`arrowmaze-frontend`, `arrowmaze-qa`, `arrowmaze-code-reviewer`, `arrowmaze-domain-modeler`, plus generic `grilling`/`domain-modeling`/`codebase-design`/subagent-driven-development skills) are prompt-engineering scaffolding around the tools above, not separate AI products.

## Usage Log by Task

The following 15 entries are selected from `AI_HISTORY.MD`'s 123 entries as the most illustrative of the project's lifecycle: initial architecture, domain modeling, bugs caught by review, reverted work, large refactors, adversarial test-hardening, and shipped features. Entry numbers refer to `AI_HISTORY.MD`.

### 1. Initial architecture setup (Entrada 001, Phase 0)
- **Task:** Create the `feat/main-sprint` branch and remove the legacy game domain (`board`/`player`, `GameController`, `CellWidget`), replacing every file still referenced by the tree with minimal compile-only stubs, ahead of the Clean Mobile Architecture rewrite.
- **AI tool:** Claude Code, subagent-driven-development workflow.
- **Prompt:** Execute Phase 0 of the Main Sprint plan — create the branch, remove the old domain, replace six files with compile-only stubs, verify the build, and commit.
- **Result:** Deleted `lib/domain/board/`, `lib/domain/player/`, and five use-case/command files; replaced `direction.dart`, `position.dart`, `command.dart`, `command_invoker.dart`, `game_screen.dart`, `board_widget.dart` with minimal stubs. `flutter analyze` clean; 1/1 widget test passing.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** Replacing removed code with compiling stubs (rather than leaving the tree broken) kept every later fragment independently buildable — the pattern the rest of the project's "always green" discipline depended on.

### 2. Key domain-modeling decision: Arrow entity + ArrowBoard aggregate root (Entrada 004, Task 2B.3)
- **Task:** Model the `Arrow` entity (multi-cell, direction-aware) and the `ArrowBoard` aggregate root as the sole entry point to board state (`canExit`, `removeArrow`, `isCleared`), so no code outside the aggregate touches individual arrows.
- **AI tool:** Claude Code, subagent-driven-development (Opus).
- **Prompt:** Implement Task 2B.3 with TDD (RED/GREEN) and AAA tests; `Arrow` computes `head`/`cells`/`exitPath` by direction; `ArrowBoard` exposes `canExit`/`removeArrow`/`isCleared` and detects blocking via occupied cells.
- **Result:** `Arrow` (Equatable) with `head`, `cells`, `exitPath(cols, rows)`; `ArrowBoard` (Equatable aggregate root) with an inline comment documenting the Aggregate Root pattern. 9 new tests, 29/29 suite green.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** Establishing the aggregate root this early paid off: nearly every later structural change (occupancy caching, the BoardSpace refactor, silhouette mounting) extended `ArrowBoard` rather than bypassing it.

### 3. Bug found by review: conflated exceptions in RemoveArrowUseCase (Entrada 007)
- **Task:** Fix a review finding on Task 2B.5: `RemoveArrowUseCase` returned the same exception type and a contradictory message for two different failures — a nonexistent arrow id versus an arrow that exists but cannot exit — so the presentation layer could not distinguish a programming error from a legitimate blocked move.
- **AI tool:** Claude Code (Opus).
- **Prompt:** Fix the review findings of 2B.5 — distinguish an absent id (`ArrowNotFoundException`) from a blocked arrow (a new `InvalidMoveException`); re-run tests; commit.
- **Result:** Added `ArrowBoard.contains(ArrowId)` and a new `InvalidMoveException`; `RemoveArrowUseCase.execute` now branches on membership first, then on path-blocking. 20/20 green in the affected area.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** The defect traced back to the original plan document (cited lines 2544–2546), not to a misreading by the tool — AI-authored code faithfully reproduces defects present in its own upstream specification, so specs require the same review rigor as code.

### 4. Bug asserted by its own test: Command pattern undo (Entrada 009)
- **Task:** Fix Task 2B.6: `CommandInvoker` stored `(command, boardBefore)` pairs and `undo` returned the stored snapshot directly, leaving `RemoveArrowCommand.undo` as dead code and breaking the Command pattern's delegation contract. The existing test did not catch this because it passed the pre-execute board into `undo`, effectively asserting the buggy behavior.
- **AI tool:** Claude Code, subagent-driven-development (Opus).
- **Prompt:** Fix the 2B.6 review findings — `CommandInvoker` must store `List<ICommand>` and delegate `undo(currentBoard)` to the command exactly as the plan specifies; the test must pass the post-execute board and verify real delegation.
- **Result:** Rewrote `CommandInvoker` to store commands (not board snapshots) and delegate `undo`; rewrote the test to pass the post-execute board. RED was confirmed against the buggy invoker (it returned a stale board that still contained the removed arrow `a2`) before the fix.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** A green test suite does not certify correct behavior if the test encodes the same misunderstanding as the implementation — this is the log's clearest example of that failure mode, and it required an explicit review pass rather than being caught by the suite itself.

### 5. Feature shipped: GraphBoardGenerator DAG algorithm (Entrada 012, Task 2B.9)
- **Task:** Implement a procedural board generator that guarantees solvability without backtracking: a candidate arrow is accepted only if it can already exit the board at the moment of placement, so removing arrows in reverse insertion order is always a valid solve.
- **AI tool:** Claude Code (Opus).
- **Result:** `GraphBoardGenerator implements ILevelGenerator`, deterministic via an optional `seed`, `maxAttempts` cap for dense boards. 3 AAA tests (arrow count, solvability via repeated removal, seed determinism).
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** The "solvable by construction" invariant introduced here is the one guarantee every later generator change (occupancy caching, band-density rework, themed dense fill) had to explicitly re-verify rather than assume — it became the project's de facto regression contract for the generator.

### 6. Regression caught and fixed: BUG-2, provider not overridden (Entrada 019, 2026-06-18)
- **Task:** Fix a blocker where the app crashed on entering a game with `UnimplementedError: gameControllerProvider must be overridden`, and, once patched, a second bug where the board stayed blank because nothing called `loadLevel` on navigation.
- **AI tool:** Claude Code (Sonnet 4.6), working from a written debug handoff.
- **Prompt:** Use the debug handoff document and its recommended skills to resolve the reported bug.
- **Result:** Wrote a RED regression test first ("navigating to /game via router renders board without manual loadLevel call"); wired the composition-root override in `main.dart`; converted `GameScreen` to `ConsumerStatefulWidget` calling `loadLevel` from `initState`'s post-frame callback; updated the router to carry `LevelId` route arguments. Verified by running the app end to end.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** The fix needed two independent corrections (composition-root wiring and widget-lifecycle timing); only running the app confirmed both, foreshadowing the project's later habit of verifying fixes on device/Docker rather than trusting the test suite alone.

### 7. Design rejected and later reintroduced: Score/Stars value objects (Entrada 042, front#12)
- **Task:** Re-introduce `front#12` (Score/Stars value objects and formula) after PR #31 had been reverted by PR #34 with the note "needs to be checked yet, pulling from the backend" — not a bug or a CI failure, but a decision to hold the change out of `main` until it could be verified against the backend's newly landed scoring contract.
- **AI tool:** Claude Code (Opus 4.8).
- **Prompt:** Focus only on fixing what #12 needs.
- **Result:** Rebuilt the branch cleanly off updated `main`; audited the front's `Score`/`Stars` value objects against the back's `ScoreEntry`/`SubmitScoreDto` for type and range compatibility before re-landing.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** An already-merged, AI-authored PR was pulled back not because the code was locally wrong, but because cross-repo contract alignment could not be verified at merge time — a reminder that "tests pass" is a weaker guarantee than "the two independently evolving repositories agree," and closing that gap remained a human review decision.

### 8. Feature shipped with composed GoF patterns: audio service (Entrada 044, front#5, 2026-07-10)
- **Task:** Implement the E9 slice: an audio service behind a port, SFX for game events, background music, independent mute toggles, and clean AOP seams.
- **AI tool:** Claude Code (Opus 4.8), acting as senior architect; the issue description was drafted via the GitHub REST API before coding.
- **Result:** `IAudioService` port (Facade); `SilentAudioService` (Null Object default); `AudioService` (Facade + lazy Singleton); `AudioplayersBackend` (Adapter); `HiveAudioSettingsStore`; `LoggingAudioDecorator` (Decorator/AOP, the project's second cross-cutting aspect). Sound effects were synthesized originals (no copyrighted samples). 16 new AAA tests; 326/326 suite green.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** Composing four GoF patterns in one feature stayed auditable because each carried the one-line inline comment the project's conventions require, stating the problem it solves — patterns introduced without that discipline are harder to review later.

### 9. Adversarial review catching an uncaught-exception contract violation (Entrada 056, front#8 final-review hardening)
- **Task:** Resolve the one Important finding from the full-branch review of `front#8`: a raw type cast (`res.data as List` / `as Map`) in `LevelRemoteDataSource` could throw an uncaught `TypeError` on an unexpected response shape, violating the project's contract that network failures must surface as `Either`, never as an uncaught throw.
- **AI tool:** Claude Code (Opus 4.8).
- **Result:** Replaced the casts with shape checks that raise `FormatException` (already mapped by the repository to `LevelCorrupted`); made cache write-through best-effort so a Hive/IO failure can no longer discard an already-fetched level. New tests were shown to fail against the pre-fix cast (a real `TypeError`, not a `FormatException`) to prove the fix was necessary. 410/410 suite green.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** The defect had been latent since the data source was first written (Entrada 048) and passed every fragment-level test until a dedicated "review the whole branch" pass looked specifically for unguarded casts — ordinary per-fragment TDD did not surface it.

### 10. Refactor for correctness: generator band-density fix (Entradas 095–098, 2026-07-15)
- **Task:** The board generator produced a visible "perimeter ring" defect — arrows clustered near the board edge, interior underfilled — undetected because the existing density guardian test used a 20×20 configuration that produced a false green.
- **AI tool:** Claude Code (Opus 4.8, 1M context).
- **Result:** New pure helpers `concentricBands`/`largestRemainderQuotas`; `generate()` rewritten to place arrows interior-first by concentric band with proportional quotas, choosing direction among the geometrically feasible options rather than fixing it a priori (the actual cause of the ring). The guardian test was recalibrated to 50×50/arrowCount 200 by explicit user decision (the plan's own 20×20 config gave a false green); RED confirmed against the old generator (average density 0.474 < the 0.6 threshold) before the fix. Golden regression fixtures were recaptured as a forward guard. 704/704 suite green.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** A guardian test's own calibration can hide the defect it exists to catch; tightening that calibration was as important as fixing the generator, and the recalibration decision was made by the human maintainer, not proposed unprompted by the tool.

### 11. Domain-modeling decision spanning both artifacts: BoardSpace / ADR-0005 (Entrada 071, session C2, issue #69)
- **Task:** Before writing any code, interrogate a design problem: 2D arithmetic was leaking into call sites (three clones of `exitPath`, five direction→delta switches, inline adjacency/bounds checks), and a 3D-board variation would have cost roughly 25 files across both artifacts. Define the minimal seam that would make such a variation cheap without speculative code.
- **AI tool:** Claude Code (Fable 5), using the `/grilling`, `/domain-modeling`, and `/codebase-design` skills.
- **Result:** Decisions D1–D5 recorded in ADR-0005: a `BoardSpace` interface with a production `RectSpace` and a test-only `HoledRectSpace` (extending `RectSpace`, overriding only `contains`) to prove the seam is real rather than hypothetical; `Direction` stays a closed enum with no vector, so the compiler flags every 3D-migration call site; `ArrowBoard` holds the space; `Arrow` becomes pure data. Implementation was deliberately deferred to a later issue (#73).
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** The team's explicit test for validating an abstraction — "two adapters, or it is a hypothetical seam" — later produced a concrete acceptance test (Entrada 084) that mechanically certified the abstraction by running the unchanged aggregate over a holed space; that criterion is a reusable verification pattern beyond this one refactor.

### 12. Large atomic refactor: Arrow becomes pure data (Entrada 081, front#73 fragment 4)
- **Task:** Change the shape of the aggregate per ADR-0005: `ArrowBoard` gains a `space: BoardSpace` field instead of raw `cols`/`rows`; `Arrow` becomes pure data (`Arrow.exitPath` and `Arrow.straight` removed). Because Dart compiles the whole tree, every call site had to migrate in the same fragment: 4 files in `lib/`, roughly 43 in `test/`, and 38 uses of `Arrow.straight`.
- **AI tool:** Claude Code (Opus 4.8, 1M context).
- **Result:** `cols`/`rows` became delegated getters; the per-instance occupancy cache from an earlier fragment was preserved; a new `test/support/arrow_fixtures.dart` factory replaced the removed `Arrow.straight`. Suite 645/645 green, including the golden generator fixture (byte-identical), confirming determinism survived the migration.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** A refactor this wide was only tractable because a large-context model could hold the full call-site graph in view in a single pass; the log explicitly frames it as atomic (all ~47 files migrate together) rather than incremental — a different risk profile from the project's usual small-fragment discipline, and one that depended on the model's context size, not just its correctness.

### 13. Test-writing effort that found a real defect and fixed the test rather than the production code (Entradas 119–120)
- **Task:** A review of the dense themed-fill generator (issue #118) found that three of its guardian tests "did not bite": the hole-depth guardian asserted a mean (which a few shallow perimeter holes could dilute), the density guardian only asserted the single best seed out of 100 candidates (an almost-free maximum), and no guardian existed for the "chunky, not spindly" arrow-length mix the maintainer cared about.
- **AI tool:** Claude Code (Opus 4.8, 1M context, qa-engineer role), explicitly instructed not to modify `graph_board_generator.dart`.
- **Result:** Added a `maxDepth <= 2` assertion, a minimum-coverage-across-all-100-seeds assertion, and length-mix bounds. The strengthened hole-depth guardian then genuinely failed: the heart mask's best-covered seed (98) had free cells at hole-depth 4 in the middle of the figure — a real defect the mean had been hiding. Rather than relaxing the threshold or touching the generator, the team traced the defect to the seed-selection criterion (picking by coverage alone) and fixed that in the following entry, which improved the heart's `maxDepth` from 4 to 0 at a coverage cost of one cell out of 608.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** This pair of entries is the log's clearest demonstration that "make the guardian able to fail, then report the failure honestly instead of moving the goalposts" surfaced a real defect that would otherwise have shipped inside a themed-level fixture; the fix targeted the actual root cause (seed selection) instead of making a riskier change to already-approved generator code.

### 14. Recurring state-management bug: double victory screen and duplicate score submission (Entrada 108, and its follow-up in Entrada 111)
- **Task:** (#98) The victory/defeat screen was pushed twice on completing a campaign level. Root cause: `GameScreen`'s `ref.listen` navigated whenever the state *was* `GameWon` rather than on the transition into it; since `GameState` has no value equality, any re-emission of an already-`GameWon` state re-triggered navigation inside the route-transition window. The first fix gated navigation on `state is GameWon && prevState is! GameWon`. The user then reported the symptom recurring in a different shape: after winning, returning to the level list, and entering a *different* level, the previous level's victory screen reappeared — traced to `gameControllerProvider` not being `autoDispose`, so Riverpod's loading state retained the previous `GameWon` value, and the score-submission and progress-recording observers lacked the same edge guard, causing duplicate `POST /scores` calls and duplicate local progress writes.
- **AI tool:** Claude Code (Opus 4.8, 1M context) for both fragments.
- **Result:** Edge guards added to both observers, plus a new per-level invariant (`state.levelId == widget.levelId`) in the navigation listener, so a `GameScreen` can never act on a stale `GameWon` belonging to a different level even if the timing recurs. Regression tests reproduced the duplicate-submission symptom (`['level-01','level-01']`) red before the fix, green after.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** The same class of bug (acting on a state re-emission rather than a state transition) recurred across three independent consumers — navigation, score submission, progress recording — because the underlying non-`autoDispose` provider and non-equatable state were never addressed at the source; the log records the second occurrence explicitly as a follow-up, which is itself a signal that the initial AI-authored fix under-scoped the root cause.

### 15. Feature shipped with disciplined pre-commit adversarial review (Entrada 123, issue #102, auto-solver)
- **Task:** Open the existing hint auto-solver to the entire campaign (not only levels ≥ 7), present it explicitly as an auto-solver with a confirmation dialog (progress is at risk), and scale playback speed with board size on large boards.
- **AI tool:** Claude Code (Sonnet 5).
- **Result:** `HintPolicy.isEligible` simplified to unconditionally `true`; a new pure domain service `AutoSolvePacing` interpolates step delay between a "deliberate" plateau and a "fast" floor, calibrated against the production ramp table; the app's first modal confirmation dialog was added. Before committing, the team ran an explicit eight-angle adversarial review that found three real defects, the most serious being a race condition: if the level's countdown timer expired while the new confirmation dialog was open, the terminal-navigation call would replace the dialog's route (the topmost one) instead of the game screen beneath it, stranding the player on a finished board with no way back. Fixed by tracking and dismissing the dialog's route before any terminal navigation, with a regression test reproducing the race.
- **Team modifications:** No manual modification recorded for this entry.
- **Lessons learned / limitations:** The three defects the adversarial pass found — including the navigation race — were not visible from the initial implementation or its own unit tests; the log treats this structured pre-commit review as a required step for any feature touching navigation or dialogs, not an optional polish pass.

The complete fragment-by-fragment log lives in [AI_HISTORY.MD](AI_HISTORY.MD).

## Critical Evaluation

### Approximate share of AI-assisted code

Effectively all production and test code in this repository was drafted by Claude Code — or, for two of the 123 logged fragments (Entradas 027–028), by Antigravity IDE running a Claude model — under the workflow `CLAUDE.md` mandates: an `AI_HISTORY.MD` entry and a corresponding git commit for every significant fragment. No entry in the ledger credits a production file to direct human hand-authorship of the diff itself. On that basis, the estimate is that **on the order of 95–100% of committed lines of code** (implementation and its paired tests) originated as AI-generated output.

"AI-assisted" in this project specifically means: the team supplies scope, architecture, and acceptance criteria — often through written specs, plans, and ADRs, and frequently through an adversarial "grilling" session before any code is written — and directs which model tier handles which risk (e.g., reserving Opus for visual-fidelity work, Entrada 029). The tool then produces the diff (implementation plus AAA tests, in a RED→GREEN→analyze cycle), and the team reviews, and not infrequently revises, rejects, reverts (Entrada 042), or requires a second adversarial pass on (Entradas 056, 096, 119–120, 123) before merging. The percentage of AI-produced diff is therefore high, but it does not reflect the amount of direction, specification, and review effort the team invested per fragment, which the log documents was substantial and repeated.

### Cases where AI was wrong or suboptimal

- **Entrada 007 (front, Task 2B.5 fix).** `RemoveArrowUseCase` returned the identical exception type and a self-contradictory message for two different failure modes — an arrow id that does not exist versus an arrow that exists but is blocked — so the presentation layer could not tell a programming error from a legitimate blocked move. Caught by review of the fragment (traced to the plan document itself, not a misreading), fixed with a dedicated `InvalidMoveException` and a membership check.
- **Entrada 009 (front, Task 2B.6 fix).** The Command pattern implementation stored board snapshots instead of delegating `undo` to the command, leaving `RemoveArrowCommand.undo` as dead code — and the accompanying test did not catch it because it asserted the buggy behavior by construction (it passed the pre-execute board into `undo`). Only an explicit review pass, which rewrote both the implementation and the test, exposed the defect.
- **Entrada 056 (front#8 final-review hardening).** `LevelRemoteDataSource` used raw type casts (`as List`, `as Map`) on network responses that would throw an uncaught `TypeError` on an unexpected shape, violating the project's own "nothing throws outward, failures surface as `Either`" contract. The defect shipped and passed every fragment-level test from Entrada 048 onward; it was only found during a dedicated review of the entire branch before merge.
- **Entrada 096 (generator band-density fix).** The board generator produced a "perimeter ring" — arrows clustered at the edge, the interior underfilled — that its own density guardian test failed to catch because the guardian's chosen board size (20×20) happened to give a false green. Fixing the generator required first recognizing that the test protecting it was miscalibrated.
- **Entradas 108 and 111 (double victory screen / duplicate score submission).** A navigation listener written to react whenever state "is" `GameWon` (rather than on the transition into it) caused the victory screen to be pushed twice; the same root cause (acting on a Riverpod state re-emission rather than a state transition) recurred independently in the score-submission and progress-recording observers, requiring a second, more invasive fix after the first one was reported as insufficient by the user.

### Team reflection

The workflow's per-fragment discipline — a written prompt, a RED test, a GREEN implementation, `flutter analyze`, a ledger entry, and a commit, repeated 123 times over roughly one month (2026-06-17 to 2026-07-17) — produced a high and sustained throughput: complete features (authentication, i18n, audio, leaderboard, themed level generation, an auto-solver) each landed with their own tests and, in the later fragments, with dedicated adversarial-review passes before merge. Delegating narrowly-specified sub-tasks to a smaller model (Entrada 044, Claude Haiku 4.5) and reserving the largest-context model for wide, atomic refactors (Entrada 081) suggests the team learned to match task shape to model tier rather than using one model uniformly.

The recurring limitation visible across the log is that a green test suite was repeatedly shown to be an insufficient proof of correctness on its own. Several of the project's most consequential defects — the Command-pattern bug whose own test asserted it (Entrada 009), the unguarded network cast (Entrada 056), the generator's perimeter ring (Entrada 096), and the hole-depth defect a mean-based guardian was hiding (Entrada 119) — were caught only by a separate, deliberately adversarial review step, not by the fragment's own TDD cycle. The same class of state-management bug (acting on a re-emission instead of a transition) also recurred across three independent consumers before it was fully addressed (Entradas 98 and its follow-up). This indicates that in this project, the review layer — human-directed "review the whole branch" passes and explicit multi-angle adversarial checks — was not a formality layered on top of AI-authored code but the primary mechanism by which its defects were actually found.
