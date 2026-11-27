import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/router/auth_redirect.dart';

String? redirect(String location, {required bool isLoggedIn}) {
  return authRedirect(Uri.parse(location), isLoggedIn: isLoggedIn);
}

void main() {
  group('sem sessão', () {
    test('o painel leva ao login lembrando a tela pedida', () {
      expect(redirect('/admin', isLoggedIn: false), '/login?voltar=%2Fadmin');
      expect(
        redirect('/admin/relatorios?de=2026-11-01', isLoggedIn: false),
        '/login?voltar=%2Fadmin%2Frelatorios%3Fde%3D2026-11-01',
      );
    });

    test('a área pública e o login abrem normalmente', () {
      expect(redirect('/', isLoggedIn: false), isNull);
      expect(redirect('/login', isLoggedIn: false), isNull);
      expect(redirect('/administrador', isLoggedIn: false), isNull);
    });
  });

  group('com sessão', () {
    test('o login leva à tela lembrada ou ao início do painel', () {
      expect(
        redirect('/login?voltar=%2Fadmin%2Frelatorios', isLoggedIn: true),
        '/admin/relatorios',
      );
      expect(redirect('/login', isLoggedIn: true), '/admin');
    });

    test('nunca volta para fora do painel', () {
      expect(
        redirect(
          '/login?voltar=https%3A%2F%2Fexemplo.com%2Fadmin',
          isLoggedIn: true,
        ),
        '/admin',
      );
      expect(
        redirect('/login?voltar=%2F%2Fexemplo.com%2Fadmin', isLoggedIn: true),
        '/admin',
      );
      expect(redirect('/login?voltar=%2F', isLoggedIn: true), '/admin');
    });

    test('as demais telas abrem normalmente', () {
      expect(redirect('/admin/relatorios', isLoggedIn: true), isNull);
      expect(redirect('/', isLoggedIn: true), isNull);
    });
  });
}
