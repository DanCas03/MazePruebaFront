# front#9 — Level-source documentation reconciliation (doc-only)

> **For agentic workers:** this is a **documentation-only** fragment. No production
> behavior changes. No new tests (prose + code comments only — the justified exception
> to CLAUDE.md rule 5). One Conventional Commit + one `AI_HISTORY.MD` entry, on a
> dedicated branch, shipped as a small PR.

**Issue:** front#9 — `feat(infra): RemoteLevelRepository + loadLevel strategy` (OPEN, `ready-for-agent`).
**Design session:** `/grill-with-docs` (grilling + domain-modeling), 2026-07-13.
**Decisions taken this session (user-confirmed):**
1. #9 → **re-scope to doc-only** (not "implement as written", not "close silently").
2. Artifact → **README note only** (no ADR).
3. Delivery → **`feat/#9-doc` branch off `main` + PR into `main`** (revised at execution
   time: front#8 **and** front#36 are already merged to `main`, so every anchor this note
   edits exists on `main`, and `feat/#8` is a stale branch missing #36 — see Background).

---

## Background — why #9 collapses to documentation

front#8 ("remote levels integration") is **fully implemented and merged to `main`**
(squash-merge → issue #8 CLOSED; the old `feat/#8-dio-level-dto-mapper` branch lingers,
showing a phantom "17 ahead", and is now *behind* `main`, which also has front#36). It
already delivered **two of #9's three** acceptance criteria:

| #9 acceptance criterion | Status | Evidence |
|---|---|---|
| `loadLevel` baja del back y arma `GamePlaying` | ✅ **Delivered by #8** | `lib/application/state/game_controller.dart:73` → `_levelRepository.getLevel(id)` → `GamePlaying`. Commit `dce1da3`. |
| Test del repo remoto con datasource mockeado | ✅ **Delivered by #8** | `test/infrastructure/repositories/remote_level_repository_test.dart` (mockito `LevelRemoteDataSource`). Commit `4ef08b8`. |
| **Strategy intercambiable remoto/procedural** (procedural como *modo práctica/fallback*) | ❌ **Superseded** | #8 *unwired* the generator; `loadLevel` is pure-remote by design. See below. |

**Why criterion 2 is obsolete (domain-modeling findings):** #9 bundles backlog items
**E1.4 + E1.5**, written on cutover day (2026-06-23). Three later domain decisions removed
its premise:

- **`GeneratedBoard` glossary entry bans** "modo práctica / nivel de práctica" — the exact
  framing E1.5/#9 uses (`MazePruebaFront/CONTEXT.md`).
- **Procedural generation is a separate feature**, not a fallback: `GeneratedBoard` → front
  **#36** (done) + **#37** (open, "Generar nivel"). It is ephemeral, has **no `LevelId`**,
  never scores — so it *cannot* substitute for an official campaign `Level`.
- **Offline is handled by the cache** (`RemoteLevelRepository` network-first-with-cache);
  `LevelUnavailable` is the deliberate offline outcome, not a generated board.

**Architectural truth (verified):** `ILevelRepository` has exactly **one** production impl
(`RemoteLevelRepository`) → this is **DIP / ports-and-adapters**, *not* a Strategy (Strategy
needs ≥2 interchangeable impls behind one interface at runtime). "Remote vs procedural" are
two **different-typed** board sources (`Level` vs `GeneratedBoard`) on **different entry
points** — not two strategies behind one interface. #9's cite of "ADR 0001 decisión 4,
Strategy" refers to the **backend's** level-*production* pipeline (generator candidates vs
frozen JSON), not a frontend runtime switch.

**What's already documented vs. the gap:** `README.md` already describes the DIP/Adapter
campaign seam (§"Campaña remota (front#8)", §Design Patterns → Adapter row) and the separate
generator Strategy (§Design Patterns → Strategy row, §Open/Closed). The **only** thing absent
anywhere is an **explicit reconciliation** for a reader holding issue #9 / backlog E1.5:
*"the remote/procedural Strategy you were promised was intentionally not built — here's why."*
This fragment fills exactly that gap.

---

## Scope

**In scope**
- One reconciliation paragraph appended to `README.md` §"Campaña remota (front#8)" (Spanish, to match the section).
- Two short inline notes: the port `i_level_repository.dart` and `GameController.loadLevel`.
- One `AI_HISTORY.MD` entry.
- Branch `feat/#9-doc`, one commit, PR into `feat/#8-dio-level-dto-mapper`, reconciliation comment on #9.

**Out of scope (explicit non-goals)**
- Any production **behavior** change (no touch to `loadLevel` logic, the repo, providers, or DI).
- A second `ILevelRepository` implementation or any runtime remote/procedural switch.
- Any ADR (user chose README-only). No `CONTEXT.md` change — the glossary is terms-only; "DIP not Strategy" is an implementation/pattern detail. Existing `GeneratedBoard`/`Level`/`Catálogo` entries already carry the domain truth.
- New tests (nothing testable is added; prose + comments).
- Rewiring/removing the generator (it stays as the #36/#37 base).
- Editing the #9 issue **body** (preserve original intent; reconcile via a comment instead).

---

## Global constraints

- **Repo:** run all `git`/`flutter`/`dart` from `MazePruebaFront/` (git-independent repo).
- **Branch:** `feat/#9-doc`, created **off `main`** (which already holds front#8's README + code *and* front#36). **PR base = `main`** (the default branch, so `Closes #9` auto-closes on merge).
- **Language:** the README paragraph is **Spanish** (matches §"Campaña remota"). Inline code comments follow the file's existing comment language (Spanish, per `i_level_repository.dart`).
- **Commit:** exactly one — `docs(front): reconcile #9 level source as DIP, not remote/procedural strategy` — plus one `AI_HISTORY.MD` entry. Do not bundle unrelated changes.
- **DoD:** `flutter analyze` clean on every touched `.dart` file (comment-only edits must not introduce lint). No test run required (no behavior change), but `flutter analyze` must pass. README links must resolve.

---

## Tasks

### Task 1: Create the branch

```bash
# from MazePruebaFront/
git checkout main && git pull --ff-only origin main
git checkout -b feat/#9-doc
```

- [ ] Confirm `git status` is clean and HEAD is `feat/#9-doc` off up-to-date `main`.

---

### Task 2: README reconciliation paragraph

**File:** `README.md` — insert **after** the current last paragraph of §"Campaña remota (front#8)"
(the line starting `El generador local (...)`, currently line 72) and **before** `### Auth flow`.

Insert this blockquote note verbatim:

```markdown

> **Nota (front#9 — reconciliación).** El *Strategy intercambiable remoto/procedural* que
> imaginaban el backlog (E1.5) y el issue front#9 —con la generación procedimental como
> "modo práctica/fallback"— **no se construyó, a propósito**. Tras el cutover ([ADR 0001](../docs/adr/0001-snake-canonical-model.md)),
> la fuente de niveles de la campaña es **DIP puro**: el puerto
> [`ILevelRepository`](lib/domain/board/repositories/i_level_repository.dart) con un **único
> Adapter de producción** (`RemoteLevelRepository`), no una familia de estrategias dentro de
> `loadLevel`. El **offline** lo resuelve la **caché** (network-first, arriba), no un tablero
> generado; sin red ni caché el resultado es `LevelUnavailable`, no un board de reemplazo. La
> generación procedimental es una **feature aparte** —`GeneratedBoard`, front#36/#37—: sus
> tableros son efímeros, sin `LevelId`, sin score ni progreso, y **nunca** sustituyen a un
> `Level` oficial. (`GraphBoardGenerator` sí es un Strategy, pero de `ILevelGenerator`, no de
> la campaña.) Por eso front#9 se cierra como documentación: los criterios 1 y 3 los entregó
> front#8, y el criterio 2 quedó superado por este diseño.
```

- [ ] Verify the two relative links resolve from `MazePruebaFront/README.md`:
  `../docs/adr/0001-snake-canonical-model.md` (workspace root ADR) and
  `lib/domain/board/repositories/i_level_repository.dart`.

> **Link check note:** ADRs live at the **workspace root** `docs/adr/`, so from
> `MazePruebaFront/README.md` the path is `../docs/adr/...`. Confirm this renders on GitHub
> for the front repo (the root `docs/` is a *sibling* repo, not part of `MazePruebaFront`).
> **If `../docs/...` does not resolve** in the front repo context, drop the ADR hyperlink and
> reference it as plain text "ADR 0001 (workspace `docs/adr/`)". Keep the in-repo
> `lib/...` link regardless.

---

### Task 3: Inline notes

**File 1:** `lib/domain/board/repositories/i_level_repository.dart` — extend the existing
class doc comment (currently ends `...el repo cachea como efecto natural).`) by appending:

```dart
///
/// Nota (front#9): la fuente de nivel de la campaña es **DIP** —este puerto con un
/// único Adapter remoto (`RemoteLevelRepository`)—, no el "Strategy remoto/procedural"
/// que imaginaba E1.5. La generación procedimental es la feature GeneratedBoard
/// (#36/#37), fuera de este puerto. Ver README §"Campaña remota".
```

**File 2:** `lib/application/state/game_controller.dart` — add a two-line comment
**immediately above** `Future<void> loadLevel(LevelId levelId) async {` (line 73):

```dart
  // Fuente de nivel única: el puerto remoto (DIP). El "Strategy remoto/procedural"
  // de front#9 se descartó tras el cutover (ver README §"Campaña remota").
```

- [ ] `flutter analyze lib/domain/board/repositories/i_level_repository.dart lib/application/state/game_controller.dart` → `No issues found!`

---

### Task 4: AI_HISTORY entry + commit

Append to `MazePruebaFront/AI_HISTORY.MD` (`NNN` = next number):

```markdown
## Entrada NNN — Reconciliación doc de la fuente de nivel (front#9)

**Fecha:** 2026-07-13
**Tarea o problema abordado:** Cerrar front#9. Sus criterios 1 y 3 (loadLevel remoto → GamePlaying; test del repo con datasource mockeado) ya los entregó front#8; el criterio 2 ("Strategy intercambiable remoto/procedural", procedural como modo práctica/fallback) quedó superado por el cutover (ADR 0001), la caché como estrategia de offline y el split de la generación en GeneratedBoard (#36/#37). Documentar esa reconciliación.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8), sesión /grill-with-docs.
**Prompt o instrucción proporcionada:** > "trae el issue #9 del front y vamos a diseñar el plan para su implementacion"
**Resultado obtenido:** Párrafo de reconciliación en README §"Campaña remota"; notas inline en `i_level_repository.dart` (puerto) y `GameController.loadLevel`. Sin cambios de comportamiento, sin tests nuevos, sin ADR ni cambios de glosario.
**Modificaciones realizadas por el equipo:** (completar manualmente)
```

Then:

```bash
git add README.md \
        lib/domain/board/repositories/i_level_repository.dart \
        lib/application/state/game_controller.dart \
        AI_HISTORY.MD
git commit -m "docs(front): reconcile #9 level source as DIP, not remote/procedural strategy"
```

- [ ] One commit, four files staged, message as above.

---

### Task 5: PR + close #9

```bash
git push -u origin feat/#9-doc
gh pr create --base main --head feat/#9-doc \
  --title "docs(front): reconcile #9 level source (DIP, not remote/procedural strategy)" \
  --body "$(cat <<'EOF'
Doc-only reconciliation of front#9.

front#8 already delivered #9's criteria 1 (`loadLevel` remote → `GamePlaying`) and 3
(remote repo tested with a mocked datasource). Criterion 2 — a remote/procedural runtime
Strategy with procedural as "modo práctica/fallback" — was intentionally not built and is
superseded by the cutover (ADR 0001): the campaign level source is DIP via `ILevelRepository`
(one Adapter, `RemoteLevelRepository`); offline is the cache; procedural generation is the
separate `GeneratedBoard` feature (#36/#37).

This PR adds an explicit reconciliation note to README §"Campaña remota" plus inline notes on
the port and `loadLevel`. No behavior change, no new tests, no ADR.

Closes #9.
EOF
)"
```

- [ ] **Closure:** the PR base is `main` (default branch), so GitHub **auto-closes #9 on
  merge** via `Closes #9`. A reconciliation comment is still posted now for the record.

Reconciliation comment (post regardless of merge timing):

```bash
gh issue comment 9 --body "$(cat <<'EOF'
Reconciled as documentation (design session 2026-07-13).

- Criterion 1 (`loadLevel` remote → `GamePlaying`) — delivered by front#8 (`dce1da3`).
- Criterion 3 (remote repo tested with mocked datasource) — delivered by front#8 (`4ef08b8`).
- Criterion 2 (Strategy remote/procedural, procedural as practice/fallback) — **superseded**:
  the campaign level source is DIP via `ILevelRepository` (one Adapter); offline = the cache;
  procedural generation is the separate GeneratedBoard feature (#36/#37). "modo práctica" is a
  retired term (see CONTEXT.md).

Doc note added in PR (branch `feat/#9-doc`). Closing on merge.
EOF
)"
```

---

## Verification checklist

- [ ] `flutter analyze` clean on the two touched `.dart` files.
- [ ] README §"Campaña remota" renders; both links resolve (or ADR downgraded to plain text per Task 2 note).
- [ ] Exactly one commit on `feat/#9-doc`, message `docs(front): reconcile #9 ...`.
- [ ] `AI_HISTORY.MD` has the new entry.
- [ ] PR opened against `main`; reconciliation comment posted on #9.
- [ ] #9 auto-closes on PR merge (`Closes #9`, base = default branch).

## Loose ends surfaced (not part of this fragment)

- The stale branch `feat/#8-dio-level-dto-mapper` still exists (already squash-merged to
  `main`, and now *behind* `main`). Safe to delete once confirmed nothing depends on it.
