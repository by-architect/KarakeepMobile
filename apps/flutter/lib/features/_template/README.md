# Feature template

Copy this directory, rename it after the feature, delete unused layers.

One screen's wiring:

```
presentation/screens    renders state, sends user intents up
presentation/widgets    pieces used only by this feature
presentation/state      immutable state class + events/effects
presentation/viewmodels Cubit or Notifier — owns the state
domain/usecases         one action per class (optional)
domain/repositories     interface the view model depends on
data/repositories       the implementation, registered in core/di
data/datasources        remote (API) and local (DB/prefs)
data/mappers            DTO <-> entity, both directions
```

Keep `domain/` free of `package:flutter` imports so it runs on the Dart VM.
