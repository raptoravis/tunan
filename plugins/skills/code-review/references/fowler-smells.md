# Fowler Smell Baseline

A curated set of high-signal "Bad Smells in Code" (Fowler, _Refactoring_, ch.3) that applies even when a repo documents no conventions. Each smell is a labelled heuristic — a judgement call, never a hard violation.

Two binding rules:
- **The repo overrides.** A documented repo standard always wins; where it endorses something this baseline would flag, suppress the smell.
- **Skip what tooling enforces.** If the project's linter or formatter already catches it, don't flag it.

## The Smells

Each entry reads *what it is* → *how to fix*.

- **Mysterious Name** — a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design is murky.
- **Duplicated Code** — the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy** — a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps** — the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery** — one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change** — one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality** — abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man** — a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest** — a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

## Usage

The maintainability reviewer carries this baseline alongside whatever the repo documents. Flag a smell only when it represents a meaningful structural issue in the diff — not every long method name is Mysterious Name, not every delegation is a Middle Man. The label names the concern; the fix direction is the starting point for a concrete suggestion, not a rigid prescription.
