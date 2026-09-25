import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/grouped_section.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../state/login_state.dart';
import '../viewmodels/login_view_model.dart';
import '../widgets/auth_method_switch.dart';
import '../widgets/custom_headers_editor.dart';
import '../widgets/field_row.dart';
import '../widgets/server_status_line.dart';

/// First screen: where the server is, and who you are on it.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _server = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _apiKey = TextEditingController();
  final _serverFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _apiKeyFocus = FocusNode();
  var _passwordVisible = false;

  LoginViewModel get _vm => ref.read(loginViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Check the server as soon as the user leaves the field.
    _serverFocus.addListener(() {
      if (!_serverFocus.hasFocus && _server.text.trim().isNotEmpty) {
        _vm.checkServer();
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_server, _email, _password, _apiKey]) {
      c.dispose();
    }
    for (final f in [_serverFocus, _emailFocus, _passwordFocus, _apiKeyFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext();
    _vm.submit();
  }

  Future<void> _pasteApiKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _apiKey.text = text;
    _vm.apiKeyChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginViewModelProvider);

    // The view model may change the URL itself ("Karakeep Cloud" shortcut).
    ref.listen(loginViewModelProvider.select((s) => s.serverUrl), (_, url) {
      if (_server.text != url) _server.text = url;
    });

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Brand(),
                      const SizedBox(height: 36),
                      _serverSection(state),
                      const SizedBox(height: 8),
                      CustomHeadersEditor(
                        expanded: state.showAdvanced,
                        headers: state.headers,
                        headerCount: state.headerCount,
                        onToggle: () {
                          if (!state.showAdvanced && state.headers.isEmpty) {
                            _vm.addHeader();
                          } else {
                            _vm.toggleAdvanced();
                          }
                        },
                        onAdd: _vm.addHeader,
                        onChanged: _vm.updateHeader,
                        onRemove: _vm.removeHeader,
                      ),
                      const SizedBox(height: 24),
                      _credentialsSection(state),
                      const SizedBox(height: 20),
                      if (state.formError != null) ...[
                        InlineBanner(message: state.formError!),
                        const SizedBox(height: 16),
                      ],
                      PrimaryButton(
                        label: 'Sign in',
                        loadingLabel: 'Signing in…',
                        loading: state.submitting,
                        onPressed: state.canSubmit ? _submit : null,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Your credentials are exchanged for an API key that '
                        'stays in this device’s secure storage.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _serverSection(LoginState state) {
    return GroupedSection(
      label: 'Server',
      footer: ServerStatusFooter(state: state, onUseCloud: _vm.useCloudServer),
      children: [
        FieldRow(
          label: 'Address',
          controller: _server,
          focusNode: _serverFocus,
          hint: 'keep.example.com',
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.url],
          onChanged: _vm.serverUrlChanged,
          onSubmitted: (_) => (state.method == AuthMethod.password
                  ? _emailFocus
                  : _apiKeyFocus)
              .requestFocus(),
          trailing: ServerStatusIndicator(
            status: state.serverStatus,
            onCheck: () {
              FocusScope.of(context).unfocus();
              _vm.checkServer();
            },
          ),
        ),
      ],
    );
  }

  Widget _credentialsSection(LoginState state) {
    final passwordMode = state.method == AuthMethod.password;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthMethodSwitch(
          value: state.method,
          passwordEnabled: state.passwordAuthAvailable,
          onChanged: _vm.methodChanged,
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: passwordMode
              ? GroupedSection(
                  key: const ValueKey(AuthMethod.password),
                  children: [
                    FieldRow(
                      label: 'Email',
                      controller: _email,
                      focusNode: _emailFocus,
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.email,
                        AutofillHints.username,
                      ],
                      onChanged: _vm.emailChanged,
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    FieldRow(
                      label: 'Password',
                      controller: _password,
                      focusNode: _passwordFocus,
                      hint: 'Required',
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.go,
                      autofillHints: const [AutofillHints.password],
                      onChanged: _vm.passwordChanged,
                      onSubmitted: (_) => _submit(),
                      trailing: IconButton(
                        tooltip:
                            _passwordVisible ? 'Hide password' : 'Show password',
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                )
              : GroupedSection(
                  key: const ValueKey(AuthMethod.apiKey),
                  footer: Text(
                    state.passwordAuthAvailable
                        ? 'Create one on the web under Settings → API Keys. '
                            'Use this if you sign in with SSO.'
                        : 'This server uses single sign-on. Create a key on '
                            'the web under Settings → API Keys and paste it '
                            'here.',
                  ),
                  children: [
                    FieldRow(
                      label: 'API key',
                      controller: _apiKey,
                      focusNode: _apiKeyFocus,
                      hint: 'ak2_…',
                      obscureText: true,
                      textInputAction: TextInputAction.go,
                      onChanged: _vm.apiKeyChanged,
                      onSubmitted: (_) => _submit(),
                      trailing: IconButton(
                        tooltip: 'Paste',
                        onPressed: _pasteApiKey,
                        icon: const Icon(
                          Icons.content_paste_rounded,
                          size: 20,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Same artwork as the launcher icon (tool/generate_app_icon.py).
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/icon/app_icon.png',
            semanticLabel: '${AppConfig.appName} logo',
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          AppConfig.appName,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sign in to your Karakeep server',
          style: TextStyle(fontSize: 15, color: AppColors.mutedForeground),
        ),
      ],
    );
  }
}
