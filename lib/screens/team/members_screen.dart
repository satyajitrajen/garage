import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/permissions.dart';
import '../../widgets/permission_gate.dart';

/// SaaS team management: login identities for this garage (distinct from the
/// workshop staff roster). Owners / staff.manage can invite by email; invites
/// are accepted via token and land here as members.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<Map<String, dynamic>> _members = [];
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
    try {
      final members = await context.read<AuthProvider>().fetchMembers();
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.userMessage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load team.';
        _loading = false;
      });
    }
  }

  Future<void> _invite() async {
    if (!ensurePermission(context, Permissions.staffManage)) return;
    final email = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite member'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send invite')),
        ],
      ),
    );
    if (sent != true || !mounted) return;
    try {
      await context.read<AuthProvider>().inviteMember(email: email.text);
      if (!mounted) return;
      showAppSnackBar(context, 'Invite sent.');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.userMessage, type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team logins')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Invite'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _members.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          Center(child: Text('No team members yet.')),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _members.length,
                          separatorBuilder: (ctx, idx) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final m = _members[i];
                            final role = (m['role'] as String?) ?? 'staff';
                            final active = (m['is_active'] as bool?) ?? true;
                            final perms =
                                (m['permissions'] as List?)?.length ?? 0;
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                      ((m['name'] as String?) ?? '?')
                                              .isNotEmpty
                                          ? ((m['name'] as String)[0]
                                              .toUpperCase())
                                          : '?'),
                                ),
                                title: Text(
                                    (m['name'] as String?) ?? 'Member',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: AppText.body)),
                                subtitle: Text(
                                    '${m['email'] ?? ''} • $role • $perms permissions${active ? '' : ' • deactivated'}'),
                                trailing: role == 'owner'
                                    ? const Icon(Icons.star_rounded,
                                        color: Colors.amber)
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
