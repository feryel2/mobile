# CarRent development rules

The student is a beginner studying Flutter at university. CarRent is a group
project. The student's responsibility is Module 2: Gestion des réservations
(Reservation Management).

The main coding-style references are the teacher's original examples:

- Flutter: `references/workshop5sae9 (4).zip`
- Backend: `references/backend.zip`

These paths are relative to the workspace root. From the `carrent/` project
folder, use `../references/workshop5sae9 (4).zip` and
`../references/backend.zip`. These archives are teaching examples, not the
CarRent application.

## Rule 1 — Follow the teacher's coding style

Before implementing any feature, inspect the relevant examples in the teacher's
workshop. For backend work, also inspect the relevant teacher backend examples.
Use the same programming concepts, structure, and coding patterns whenever
possible.

Prefer:

- `StatelessWidget` and `StatefulWidget`.
- `setState` with explicit blocks.
- `Scaffold`, `AppBar`, `Column`, `Row`, and `Container`.
- `Form`, `GlobalKey<FormState>`, `TextFormField`, and `validator`.
- `Navigator.push` and `MaterialPageRoute`.
- `ListView.builder`.
- `FutureBuilder`, `Future`, `async`, and `await`.
- HTTP requests using the `http` package.
- Models using `fromJson`.
- Separate screens, models, services, custom widgets, and utils.

## Rule 2 — Avoid unnecessary complexity

Do not introduce advanced architectures, complex abstractions, state-management
libraries, or unnecessary packages.

When multiple solutions are possible, prefer the solution closest to the
teacher's examples. Do not use complicated syntax when a simpler version taught
in class works.

## Rule 3 — Explain new techniques

If a feature requires something not demonstrated in the workshops, it may be
used when necessary. Clearly explain:

1. What the new technique does.
2. Why it is necessary.
3. Why the teacher's existing examples are not sufficient.

Do not introduce extra complexity just for optimization.

## Rule 4 — Preserve the project

- Do not modify the teacher's original workshop files or reference archives.
- Do not change the group's approved Figma palette.
- Keep the reservation module separate and compatible with classmates' modules.
- Reuse existing shared models and services; do not duplicate Car or User models.
- Do not add unrelated functionality.

## Rule 5 — Mandatory comparison after EVERY implementation

After modifying any Flutter code, include a section in the response called:

**COMPARISON WITH TEACHER'S WORKSHOP**

Provide a table with these columns:

| Code or concept used in CarRent | Corresponding teacher workshop file and technique | Same, adapted, or new | Reason for any difference |
| --- | --- | --- | --- |

Use actual workshop examples. Do not claim a technique appears in the workshop
without verifying it. If a technique is new, identify it honestly and explain it
according to Rule 3.

## Rule 6 — Mandatory testing and explanation

After each coding task:

- Run `flutter analyze` from the `carrent/` project folder.
- Run `flutter test` from the `carrent/` project folder.
- Explain which files were modified and what each important part does.
- Explain the code in short, beginner-friendly English.
- State what was actually tested and whether the checks passed or failed.
- If a check could not run, state that clearly and explain why; do not claim it
  passed.
- Explain how the student can run the application and manually verify the result.

## Rule 7 — Work step by step

Implement only the feature requested in each prompt. Do not automatically
implement future features. Wait for the student's next instruction before
continuing.
