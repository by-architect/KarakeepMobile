# android-kotlin

Native Android. Multi-module Gradle, Compose UI, MVVM with `StateFlow`.

```
app/                      assembly only: Application class, DI wiring, nav host
core/
  common/                 pure Kotlin helpers, Result types, dispatchers
  designsystem/           theme, tokens, reusable composables
  ui/                     shared UI helpers and state utilities
  navigation/             routes and navigation contracts
  network/                HTTP client, interceptors, serialization
  database/               DB setup and shared DAOs
  datastore/              preferences / key-value storage
  testing/                fakes, fixtures, test rules
feature/
  _template/              copy once per feature
    src/main/kotlin/
      data/               local, remote/dto, mapper, repository (impls)
      domain/             model, repository (interfaces), usecase
      presentation/       state, viewmodel, ui
    src/test/kotlin/      JVM tests
    src/androidTest/kotlin/  instrumented tests
```

`app/` stays thin — it wires modules together and owns nothing else. Features
never depend on each other; anything two features need moves down into `core/`.

## Per-fork setup (not shipped here)

`settings.gradle.kts`, `gradle/libs.versions.toml`, a `build.gradle.kts` per
module, `AndroidManifest.xml`, and the package directories under each
`src/main/kotlin` (e.g. `com/yourorg/yourapp/...`).
