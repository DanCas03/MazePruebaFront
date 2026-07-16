# Navigation Audit (front#103)

A proactive, whole-app pass over every named route to guarantee a **working,
predictable way back** to the main menu from every reachable screen — no
dead-ends, consistent affordances, and correct Android system-back behavior.

Scope: `MazePruebaFront/`. Routing model: Navigator 1.0 with named routes
resolved centrally by `AppRouter.onGenerateRoute` (`lib/core/router/app_router.dart`).
The Navigator **root** ('/') is the `AuthGate` (`lib/core/auth/auth_gate.dart`),
which renders `HomeScreen` when authenticated and `LoginScreen` otherwise. Every
game route is pushed on top of that root.

## Finding & fix

The audit surfaced **one concrete latent dead-end**:

- **Generated-flow "Exit" removed the AuthGate root.** The post-game screen exited
  with `pushNamedAndRemoveUntil(home, (_) => false)`, which wiped the entire stack —
  including the root `AuthGate` route — and pushed a *bare* `HomeScreen`. Logout is
  reactive: `AccountPanel` signs out and relies on the `AuthGate` still being mounted
  to swap to `LoginScreen` (see `account_panel.dart`). With the AuthGate gone, signing
  out from that Home left the user stranded on an authenticated-looking screen.

**Fix:** the two "return path" policies are now centralized in `AppRouter` as the
single source of truth for the no-dead-end guarantee:

| Helper | Behavior | Used by |
|---|---|---|
| `AppRouter.backToLevels(context)` | `pushNamedAndRemoveUntil(levels, withName('/'))` — keeps the root under the level list so the AppBar back arrow persists | Victory, Defeat, Game load-error |
| `AppRouter.exitToHome(context)` | `popUntil(withName('/'))` — pops the current sub-flow back to the **existing** root, preserving the AuthGate | Generated result "Exit" |

## Per-route back/home behavior

| Route | Reached from | Back / home affordance | System-back |
|---|---|---|---|
| `/` (AuthGate → Home / Login) | root | Main menu / login — terminal parent, no back needed | exits app (expected root behavior) |
| `/settings` | Home (push) | AppBar auto back arrow → Home | → Home |
| `/levels` | Home (push) | AppBar auto back arrow → Home | → Home |
| `/themed` | Home (push) | AppBar auto back arrow → Home | → Home |
| `/generate` (Configurator) | Home (push) | AppBar auto back arrow → Home | → Home |
| `/game` | Levels / Themed (push) | AppBar auto back arrow → level list | → level list |
| `/leaderboard` | level tile (push) | AppBar auto back arrow → Levels | → Levels |
| `/victory` | Game (pushReplacement) | "Next Level" / "Back to Levels" (`backToLevels`); root kept beneath | → Levels |
| `/defeat` | Game (pushReplacement) | "Retry" / "Back to Levels" (`backToLevels`); root kept beneath | → Levels |
| `/generate/play` | Configurator / result (pushReplacement) | AppBar auto back arrow → Home | → Home |
| `/generate/result` | generated game (pushReplacement) | "Another board" / "Repeat" / "Change params" / "Exit" (`exitToHome`) | → Home |
| Register | Login (push) | AppBar back arrow / "Go to login" / auto-pop on auth | → Login |

## Invariants that keep the guarantee true

1. The root '/' (AuthGate) is **never removed**. Terminal screens either keep it
   beneath (`backToLevels`) or pop down to it (`exitToHome`). No screen becomes a
   bare stack root.
2. Terminal screens without an AppBar (Victory, Defeat, Generated result) always
   expose an **explicit** back/home control, and system-back reveals their logical
   parent (they are reached via `pushReplacement`, never as a root).
3. The "return path" predicate lives in exactly **one** place (`AppRouter`), so a
   new screen cannot silently reintroduce the `(_) => false` foot-gun.

## Regression coverage (terminal transitions)

- `test/core/router/app_router_test.dart` — `backToLevels` keeps the root beneath;
  `exitToHome` pops to the root **without rebuilding it** (mount-count probe).
- `test/presentation/level_selection/victory_screen_test.dart` — Back to Levels keeps
  Home so the back arrow persists.
- `test/presentation/level_selection/defeat_screen_test.dart` — same guard for Defeat.
- `test/presentation/generated/generated_result_screen_test.dart` — "Salir" returns to
  the root without re-creating it (guards the AuthGate dead-end).
- `test/presentation/game/screens/game_screen_test.dart` — load-error branch shows the
  back button to the level list.

## Out of scope

- The three sites fixed by PR #97 (level list back arrow) — already done.
- Migrating the routing library or redesigning the navigation model.
