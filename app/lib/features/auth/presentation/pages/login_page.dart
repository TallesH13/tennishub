import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/session/owner_session.dart';
import 'package:tennishub/core/theme/app_spacing.dart';
import 'package:tennishub/core/widgets/app_brand.dart';
import 'package:tennishub/core/widgets/message_banner.dart';
import 'package:tennishub/features/auth/presentation/state/auth_controller.dart';

/// Chaves dos campos do login, usadas nos testes.
abstract final class LoginKeys {
  static const email = Key('login-email');
  static const password = Key('login-password');
  static const togglePassword = Key('login-toggle-password');
  static const submit = Key('login-submit');
}

/// Login do proprietário (rota `/login`, RF05).
///
/// Depois de entrar, o roteador leva ao painel ou à tela que estava aberta
/// quando a sessão expirou.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const String _invalidCredentials = 'E-mail ou senha incorretos.';

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;
  MessageKind _errorKind = MessageKind.error;
  late final bool _sessionExpired;

  @override
  void initState() {
    super.initState();
    _sessionExpired = ref.read(sessionStoreProvider.notifier).consumeExpired();
    if (!_sessionExpired) {
      unawaited(_restoreSession());
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Página recarregada com a sessão ainda válida na API: entra direto.
  Future<void> _restoreSession() async {
    try {
      await ref.read(authControllerProvider).restoreSession();
    } on ApiException {
      // Sem conexão: o proprietário entra pelo formulário.
    }
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .signIn(email: _email.text, password: _password.text);
    } on InvalidCredentialsException {
      _fail(_invalidCredentials, clearPassword: true);
    } on TooManyAttemptsException catch (error) {
      _fail(error.message, kind: MessageKind.warning, clearPassword: true);
    } on ApiException catch (error) {
      _fail(error.message);
    }
  }

  void _fail(
    String message, {
    MessageKind kind = MessageKind.error,
    bool clearPassword = false,
  }) {
    if (!mounted) {
      return;
    }
    if (clearPassword) {
      _password.clear();
    }
    setState(() {
      _submitting = false;
      _error = message;
      _errorKind = kind;
    });
    _passwordFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final error = _error;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: AppBrand(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Área do proprietário',
                          style: textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Entre para gerenciar quadras, horários e agendamentos.',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (_sessionExpired && error == null) ...[
                          const MessageBanner(
                            message: 'Sua sessão expirou por inatividade. Entre novamente para continuar.',
                            kind: MessageKind.info,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (error != null) ...[
                          MessageBanner(message: error, kind: _errorKind),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        TextFormField(
                          key: LoginKeys.email,
                          controller: _email,
                          enabled: !_submitting,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Informe o e-mail.'
                              : null,
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          key: LoginKeys.password,
                          controller: _password,
                          focusNode: _passwordFocus,
                          enabled: !_submitting,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            suffixIcon: IconButton(
                              key: LoginKeys.togglePassword,
                              tooltip: _obscurePassword
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              (value ?? '').isEmpty ? 'Informe a senha.' : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton(
                          key: LoginKeys.submit,
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: AppSpacing.sm),
                                    Text('Entrando…'),
                                  ],
                                )
                              : const Text('Entrar'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => context.go(AppRoutes.home),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Voltar para a área pública'),
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
      ),
    );
  }
}
