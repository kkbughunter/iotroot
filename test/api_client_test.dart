import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:iotroot/core/api_client.dart';

import 'support/fakes.dart';

void main() {
  test(
    'login uses backend contract, restores secure session and revokes logout',
    () async {
      final store = MemoryStore();
      final requests = <String>[];
      final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          requests.add(r.url.path);
          if (r.url.path.endsWith('/login')) {
            expect(jsonDecode(r.body), {
              'email': 'user@example.com',
              'password': 'account-secret',
            });
            return reply(tokens);
          }
          if (r.url.path.endsWith('/logout')) {
            expect(jsonDecode(r.body), {'refreshToken': 'refresh'});
            return reply(null);
          }
          expect(r.headers['Authorization'], 'Bearer access');
          return reply([]);
        }),
      );
      await api.login(
        'https://example.com/',
        'user@example.com',
        'account-secret',
      );
      expect(store.values.values.join(), isNot(contains('account-secret')));
      final restored = ApiClient(store: store);
      expect(await restored.restore(), isTrue);
      expect(restored.email, 'user@example.com');
      await api.request('/api/devices');
      await api.logout();
      expect(requests.last, '/api/auth/logout');
      expect(api.authenticated, isFalse);
      expect(store.values['iotroot.session'], isNull);
      api.dispose();
      restored.dispose();
    },
  );

  test('401 refreshes token once and retries authorized request', () async {
    var refreshes = 0;
    var calls = 0;
    final api = ApiClient(
      store: MemoryStore(),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return reply(tokens);
        if (r.url.path.endsWith('/refresh-token')) {
          refreshes++;
          return reply({...tokens, 'accessToken': 'new-access'});
        }
        calls++;
        if (calls == 1) return reply(null, status: 401);
        expect(r.headers['Authorization'], 'Bearer new-access');
        return reply(['ok']);
      }),
    );
    await api.login('https://example.com', 'a@b.com', 'secret');
    expect(await api.request('/api/devices'), ['ok']);
    expect(refreshes, 1);
    api.dispose();
  });

  test('revoked refresh clears session and reports expiry', () async {
    var expired = false;
    final api = ApiClient(
      store: MemoryStore(),
      client: MockClient(
        (r) async => r.url.path.endsWith('/login')
            ? reply(tokens)
            : reply(null, status: 401, message: 'Expired'),
      ),
    );
    api.onSessionExpired = () => expired = true;
    await api.login('https://example.com', 'a@b.com', 'secret');
    await expectLater(
      api.request('/api/devices'),
      throwsA(isA<ApiException>()),
    );
    expect(expired, isTrue);
    expect(api.authenticated, isFalse);
    api.dispose();
  });
  test('concurrent expired requests share one refresh operation', () async {
    var refreshes = 0;
    final release = Completer<void>();
    final api = ApiClient(
      store: MemoryStore(),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return reply({...tokens, 'expiresInSeconds': 0});
        }
        if (r.url.path.endsWith('/refresh-token')) {
          refreshes++;
          await release.future;
          return reply({...tokens, 'accessToken': 'new'});
        }
        expect(r.headers['Authorization'], 'Bearer new');
        return reply([]);
      }),
    );
    await api.login('https://example.com', 'a@b.com', 'secret');
    final first = api.request('/api/devices');
    final second = api.request('/api/devices/connection-status');
    release.complete();
    await Future.wait([first, second]);
    expect(refreshes, 1);
    api.dispose();
  });

  test('a late refresh cannot restore a signed-out session', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final store = MemoryStore();
    final api = ApiClient(
      store: store,
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return reply({...tokens, 'expiresInSeconds': 0});
        }
        if (r.url.path.endsWith('/refresh-token')) {
          started.complete();
          await release.future;
          return reply(tokens);
        }
        return reply(null);
      }),
    );
    await api.login('https://example.com', 'a@b.com', 'secret');
    final pending = api.request('/api/devices');
    final failure = expectLater(pending, throwsA(isA<ApiException>()));
    await started.future;
    await api.logout();
    release.complete();
    await failure;
    expect(api.authenticated, isFalse);
    expect(store.values['iotroot.session'], isNull);
    api.dispose();
  });
}
