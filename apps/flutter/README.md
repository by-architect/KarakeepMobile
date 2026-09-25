# flutter

Flutter. MVVM via Cubit (`flutter_bloc`) or Riverpod notifiers — pick one per
fork and keep it consistent.

```
lib/
  core/
    config/       environment + flavor configuration
    di/           dependency registration (Riverpod providers / get_it)
    error/        failures and exception types
    network/      HTTP client, interceptors
    router/       route table and guards
    theme/        design tokens, light/dark themes
    utils/        pure helpers
    widgets/      shared widgets
  features/
    _template/    copy once per feature
      data/         datasources/local, datasources/remote, dto, mappers, repositories
      domain/       entities, repositories (interfaces), usecases
      presentation/ state, viewmodels, screens, widgets
assets/           images, icons, fonts
test/unit         pure Dart tests
test/widget       widget tests
integration_test/ end-to-end
```

`lib/main.dart` and any `main_<flavor>.dart` entry points belong at the root of
`lib/`, added per fork.

## Per-fork setup (not shipped here)

`pubspec.yaml`, `analysis_options.yaml`, the `android/` and `ios/` platform
folders — generate them with `flutter create .` from this directory, then move
the generated `lib/` contents into the structure above.
