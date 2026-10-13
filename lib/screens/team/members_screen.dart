import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/date_formatter.dart';
import '../../utils/error_message.dart';
import '../../utils/permissions.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/permission_gate.dart';
import '../../l10n/app_language.dart';

/// SaaS team management: login identities for this garage (distinct from the
/// workshop staff roster). Owners / staff.manage can invite by email; invites
/// are accepted via token and land here as members. Pending invites are
/// listed above the members and can be revoked.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invites = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      final members = await auth.fetchMembers();
      // Pending invites are a staff.manage view; without it, skip them.
      final invites = auth.can(Permissions.staffManage)
          ? await auth.fetchInvites()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _members = members;
        _invites = invites;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = tr('Could not load team.');
        _loading = false;
      });
    }
  }

  Future<void> _invite() async {
    if (!ensurePermission(context, Permissions.staffManage)) return;
    final isOwner = context.read<AuthProvider>().isOwner;
    final request = await showDialog<_InviteRequest>(
      context: context,
      builder: (ctx) => _InviteDialog(canInviteOwner: isOwner),
    );
    if (request == null || !mounted) return;
    try {
      await context.read<AuthProvider>().inviteMember(
            email: request.email,
            role: request.role,
            permissions: request.role == 'owner' ? null : request.permissions,
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Invite sent to ${request.email}.',
          type: SnackBarType.success);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    }
  }

  Future<void> _revoke(Map<String, dynamic> invite) async {
    final email = (invite['email'] as String?) ?? 'this person';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          title: Text(tr('Revoke invite?')),
          content: Text('The invite link sent to $email will stop working.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('Keep'), style: TextStyle(color: palette.textSecondary))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.partial,
                  foregroundColor: palette.onPrimary,
                ),
                child: Text(tr('Revoke'))),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthProvider>().revokeInvite(invite['id'] as String);
      if (!mounted) return;
      showAppSnackBar(context, tr('Invite revoked.'),
          type: SnackBarType.success);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    }
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: AppText.caption)),
      );

  Widget _memberTile(Map<String, dynamic> m) {
    final palette = context.palette;
    final role = (m['role'] as String?) ?? 'staff';
    final active = (m['is_active'] as bool?) ?? true;
    final perms = (m['permissions'] as List?)?.length ?? 0;
    final name = (m['name'] as String?) ?? '';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
        ),
        title: Text(name.isNotEmpty ? name : tr('Member'),
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: AppText.body)),
        subtitle: Text('${m['email'] ?? ''} • $role • '
            '$perms permission${perms == 1 ? '' : 's'}'
            '${active ? '' : ' • deactivated'}'),
        trailing: role == 'owner'
            ? Icon(Icons.star_rounded, color: palette.partial)
            : null,
      ),
    );
  }

  Widget _inviteTile(Map<String, dynamic> invite) {
    final role = (invite['role'] as String?) ?? 'staff';
    final expires =
        DateTime.tryParse((invite['expires_at'] as String?) ?? '')?.toLocal();
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.mail_outline_rounded)),
        title: Text((invite['email'] as String?) ?? '',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: AppText.body)),
        subtitle: Text('$role • pending'
            '${expires == null ? '' : ' • expires ${AppDateFormatter.formatDate(expires)}'}'),
        trailing: IconButton(
          tooltip: tr('Revoke invite'),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _revoke(invite),
        ),
      ),
    );
  }

  /// Empty roster state; the invite CTA is shown only with staff.manage.
  Widget _emptyMembersState({required bool withCta}) {
    return EmptyStateWidget(
      icon: Icons.group_outlined,
      title: tr('No team members yet.'),
      description:
          tr('Invite your team so they can sign in and use this garage.'),
      buttonText: withCta ? tr('Invite') : null,
      onButtonPressed: withCta ? _invite : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Team logins'))),
      // Gated: staff without staff.manage can view the roster but never see
      // the invite affordance (the handler re-checks via ensurePermission).
      floatingActionButton: PermissionGate(
        permission: Permissions.staffManage,
        child: FloatingActionButton.extended(
          onPressed: _invite,
          icon: const Icon(Icons.person_add_outlined),
          label: Text(tr('Invite')),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 40, color: palette.textMuted),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: AppText.body,
                              color: palette.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _load, child: Text(tr('Retry'))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _members.isEmpty && _invites.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          PermissionGate(
                            permission: Permissions.staffManage,
                            fallback: _emptyMembersState(withCta: false),
                            child: _emptyMembersState(withCta: true),
                          ),
                        ])
                      : ListView(
                          // Bottom padding keeps the last card clear of the FAB.
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          children: [
                            if (_invites.isNotEmpty) ...[
                              _sectionLabel(tr('Pending invites')),
                              for (final invite in _invites) ...[
                                _inviteTile(invite),
                                const SizedBox(height: 8),
                              ],
                              _sectionLabel(tr('Members')),
                            ],
                            for (final member in _members) ...[
                              _memberTile(member),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                ),
    );
  }
}

class _InviteRequest {
  const _InviteRequest(this.email, this.role, this.permissions);
  final String email;
  final String role;
  final List<String> permissions;
}

/// Invite form: email, role (Owner is only offered to owners, matching the
/// backend rule) and, for staff, which parts of the app they may use.
class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.canInviteOwner});
  final bool canInviteOwner;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _email = TextEditingController();
  String _role = 'staff';
  final Set<String> _permissions = {...Permissions.defaultStaff};
  String? _emailError;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _emailError = tr('Enter a valid email'));
      return;
    }
    if (_role == 'staff' && _permissions.isEmpty) {
      showAppSnackBar(context, tr('Pick at least one permission'),
          type: SnackBarType.error);
      return;
    }
    Navigator.pop(
      context,
      _InviteRequest(email, _role, [
        for (final p in Permissions.all)
          if (_permissions.contains(p)) p,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Invite member')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
              decoration: InputDecoration(
                labelText: tr('Email'),
                border: const OutlineInputBorder(),
                errorText: _emailError,
              ),
            ),
            if (widget.canInviteOwner) ...[
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'staff', label: Text(tr('Staff'))),
                  ButtonSegment(value: 'owner', label: Text(tr('Owner'))),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
            ],
            const SizedBox(height: 8),
            if (_role == 'owner')
              Text(tr('Owners get full access, including billing and the team.'),
                  style: GoogleFonts.poppins(fontSize: AppText.caption))
            else ...[
              Text(tr('Can manage'),
                  style: GoogleFonts.poppins(
                      fontSize: AppText.caption, fontWeight: FontWeight.w600)),
              for (final p in Permissions.all)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(Permissions.label(p)),
                  value: _permissions.contains(p),
                  onChanged: (on) => setState(() =>
                      on == true ? _permissions.add(p) : _permissions.remove(p)),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel'))),
        FilledButton(onPressed: _submit, child: Text(tr('Send invite'))),
      ],
    );
  }
}
