# Feature template

Copy this directory, rename it after the feature (not after the screen widget),
and delete the layers you genuinely do not need.

Wiring for one screen:

```
presentation/ui         renders state, sends user events up
presentation/state      UiState (immutable), UiEvent, UiEffect
presentation/viewmodel  holds UiState, calls domain or data
domain/usecase          one action per class (optional)
domain/repository       interface the view model depends on
data/repository         the implementation, picked at DI time
data/remote + local     the two sources it chooses between
data/mapper             DTO <-> domain model, both directions
```
