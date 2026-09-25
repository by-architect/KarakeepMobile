# Architecture contract

MVVM with unidirectional state flow, over three layers. This applies to every
stack in `apps/` — only the file extensions change.

```
presentation  screens + view models + UI state    (knows domain)
     |
domain        entities, use cases, repo interfaces (knows nothing)
     |
data          repo implementations, remote, local  (knows domain)
```

## Rules

1. **Dependencies point inward.** `presentation` and `data` may depend on
   `domain`. `domain` depends on neither, and imports no framework types
   (no `android.*`, no `flutter/material.dart`). That is what makes it fast to test.
2. **The view model never sees the framework's view.** It exposes one immutable
   state object; the view observes and renders it. No back-references.
3. **One state class per screen.** Loading / error / content are fields of that
   state, not separate flags scattered across the view.
4. **One-shot effects are not state.** Navigation, toasts, dialogs go through a
   separate event channel, or they re-fire on every re-render.
5. **The repository is the single source of truth.** It decides cache vs network;
   callers above it never know which one answered.
6. **`domain/repository` holds interfaces, `data/repository` holds implementations.**
   That inversion is what keeps the domain layer framework-free.
7. **Use cases are optional.** Add one when logic is shared by more than one
   view model, or when a single action spans several repositories. Otherwise let
   the view model call the repository directly.

## Layer cheat sheet

| Folder | Holds | Never holds |
|---|---|---|
| `data/remote` | API clients, DTOs | business rules |
| `data/local` | DB, preferences, cache | business rules |
| `data/mapper` | DTO/entity translation | UI formatting |
| `data/repository` | interface implementations | UI state |
| `domain/model` | plain entities | framework types |
| `domain/usecase` | one action each | UI state |
| `presentation/state` | UI state + events + effects | network calls |
| `presentation/viewmodel` | state holders | widget/view references |
| `presentation/ui` | screens, components | business rules |

## Related

- [`feature-flags.md`](feature-flags.md) — the seam that decouples merging from releasing
- [`../release/README.md`](../release/README.md) — how the layers are verified before shipping
