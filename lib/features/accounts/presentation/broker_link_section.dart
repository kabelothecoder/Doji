import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../markets/data/mt5_api.dart';
import '../data/broker_link_repository.dart';
import '../domain/trading_account.dart';

/// The account editor's "broker" section: link this account to the trader's
/// MT5 account (read-only: prices, balance, equity) or unlink it. Acts at
/// once, apart from the editor's save. No design file (design/SOURCE.md ›
/// Missing); built from design-system parts.
class BrokerLinkSection extends ConsumerStatefulWidget {
  const BrokerLinkSection({super.key, required this.account, required this.onChanged});

  final TradingAccount account;

  /// The new link (null = unlinked), already stored on the account.
  final ValueChanged<BrokerLink?> onChanged;

  @override
  ConsumerState<BrokerLinkSection> createState() => _BrokerLinkSectionState();
}

class _BrokerLinkSectionState extends ConsumerState<BrokerLinkSection> {
  final _server = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _ready =>
      _server.text.trim().isNotEmpty && int.tryParse(_login.text.trim()) != null && _password.text.isNotEmpty;

  String _say(Object e) => switch (e) {
    Mt5Failure(:final message) => message.toLowerCase(),
    _ => "couldn't reach your broker. try again.",
  };

  Future<void> _link() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await ref
          .read(brokerLinkRepositoryProvider)
          .link(
            widget.account.id,
            server: _server.text.trim(),
            login: int.parse(_login.text.trim()),
            password: _password.text,
          );
      _password.clear();
      widget.onChanged(link);
    } on Object catch (e) {
      if (mounted) setState(() => _error = _say(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink() async {
    final ok = await showDojiAlert(
      context,
      title: 'unlink your broker?',
      message: 'doji stops reading prices, balance and equity from it. your saved password is deleted.',
      destructiveLabel: 'unlink',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(brokerLinkRepositoryProvider).unlink(widget.account.id);
      widget.onChanged(null);
    } on Object catch (e) {
      if (mounted) setState(() => _error = _say(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.account.brokerLink;
    final available = ref.watch(brokerLinkRepositoryProvider).available;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'link your MT5 account for live prices, balance and equity. read-only: doji never places trades.',
          style: DojiType.callout,
        ),
        const SizedBox(height: 12),
        if (link != null) ...[
          TerminalLine('linked · ${link.login} on ${link.server}', tone: TerminalTone.primary),
          const SizedBox(height: 12),
          DojiButton(
            label: _busy ? 'unlinking' : 'unlink',
            variant: DojiButtonVariant.ghost,
            onPressed: _busy || !available ? null : () => unawaited(_unlink()),
          ),
        ] else if (!available)
          const TerminalLine('sign in to link a broker. prices stay sample until then.')
        else ...[
          DojiTextField(
            controller: _server,
            hint: 'broker server, e.g. Deriv-Server',
            semanticLabel: 'broker server',
            large: false,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DojiTextField(
            controller: _login,
            hint: 'login (account number)',
            semanticLabel: 'MT5 login',
            large: false,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DojiTextField(
            controller: _password,
            hint: 'investor (read-only) password',
            helper: 'kept encrypted on doji\'s server to reconnect. never on this device.',
            semanticLabel: 'MT5 investor password',
            large: false,
            obscureText: true,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DojiButton(
            label: _busy ? 'linking' : 'link',
            variant: DojiButtonVariant.secondary,
            onPressed: _busy || !_ready ? null : () => unawaited(_link()),
          ),
        ],
        if (_error != null) ...[const SizedBox(height: 12), TerminalLine(_error!, tone: TerminalTone.tilt)],
      ],
    );
  }
}
