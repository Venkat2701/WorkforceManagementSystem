import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/responsive_shell.dart';
import '../../core/widgets/custom_card.dart';
import '../../services/admin_management_service.dart';
import 'package:intl/intl.dart';

class ManageAdminsScreen extends ConsumerWidget {
  const ManageAdminsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveShell(
      title: 'Manage Admins',
      selectedIndex: 5,
      onDestinationSelected: (index) {},
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAdminDialog(context, ref),
        label: const Text('Add Admin'),
        icon: const Icon(Icons.person_add_alt_1),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const _ManageAdminsContent(),
    );
  }

  void _showAddAdminDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Admin'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter an email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(val.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Initial Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (val.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setState(() => isLoading = true);
                      try {
                        await ref
                            .read(adminManagementServiceProvider)
                            .createAdmin(
                              name: nameController.text.trim(),
                              email: emailController.text.trim(),
                              password: passwordController.text,
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Admin created successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          String errorMsg = e.toString();
                          if (errorMsg.contains('RE_ACTIVATED')) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Existing account found and re-activated!',
                                ),
                                backgroundColor: Colors.blue,
                              ),
                            );
                            return;
                          }

                          if (errorMsg.contains('email-already-in-use')) {
                            errorMsg = 'This email is already registered.';
                          } else if (errorMsg.contains('Exception: ')) {
                            errorMsg = errorMsg.replaceAll('Exception: ', '');
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errorMsg),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) setState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Admin'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageAdminsContent extends ConsumerStatefulWidget {
  const _ManageAdminsContent();

  @override
  ConsumerState<_ManageAdminsContent> createState() =>
      _ManageAdminsContentState();
}

class _ManageAdminsContentState extends ConsumerState<_ManageAdminsContent> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final adminsStream = ref
        .watch(adminManagementServiceProvider)
        .fetchAdmins();

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: StreamBuilder(
            stream: adminsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final docs = snapshot.data?.docs ?? [];
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery.toLowerCase()) ||
                    email.contains(_searchQuery.toLowerCase());
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(child: Text('No admins found.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.l),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data =
                      filteredDocs[index].data() as Map<String, dynamic>;
                  final uid = filteredDocs[index].id;
                  return _AdminCard(uid: uid, data: data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Administrators',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends ConsumerWidget {
  final String uid;
  final Map<String, dynamic> data;

  const _AdminCard({required this.uid, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = (data['name'] as String?)?.isNotEmpty == true
        ? data['name']
        : (data['displayName'] as String?)?.isNotEmpty == true
        ? data['displayName']
        : 'Admin (${uid.substring(0, 5)}...)';
    final email = data['email'] as String? ?? 'Email not set';
    final lastLogin = data['last_login'] != null
        ? DateFormat(
            'MMM dd, yyyy HH:mm',
          ).format((data['last_login'] as Timestamp).toDate())
        : 'Never logged in';

    return CustomCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'A',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.textMedium,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last active: $lastLogin',
                  style: const TextStyle(
                    color: AppColors.textLow,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.history, color: AppColors.primary),
                tooltip: 'History',
                onPressed: () => _showHistory(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.lock_reset, color: Colors.orange),
                tooltip: 'Reset Password',
                onPressed: () => _showResetPasswordDialog(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete Admin',
                onPressed: () => _showDeleteConfirmation(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Administrator?'),
        content: Text(
          'Are you sure you want to delete ${data['name']}? This will remove their Firestore records and revoke their system access immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(adminManagementServiceProvider).deleteAdmin(uid);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Admin removed and access revoked.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Confirm Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _AdminHistoryPanel(uid: uid, name: data['name'] ?? 'Admin'),
    );
  }

  void _showResetPasswordDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password for ${data['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This will send a secure password reset link to:'),
            const SizedBox(height: AppSpacing.s),
            Text(
              data['email'] ?? 'Unknown Email',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.m),
            const Text(
              'Once the admin clicks the link in their email, they can set a new password themselves.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = data['email'];
              if (email == null || email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No email found for this admin.'),
                  ),
                );
                return;
              }

              try {
                await ref
                    .read(adminManagementServiceProvider)
                    .sendPasswordReset(email);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reset email sent to $email'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }
}

class _AdminHistoryPanel extends ConsumerWidget {
  final String uid;
  final String name;

  const _AdminHistoryPanel({required this.uid, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsStream = ref
        .watch(adminManagementServiceProvider)
        .fetchAdminLogs(uid);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity History: $name',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder(
              stream: logsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 40,
                          ),
                          const SizedBox(height: AppSpacing.m),
                          Text(
                            'Error loading logs: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final logs = snapshot.data?.docs ?? [];
                if (logs.isEmpty) {
                  return const Center(child: Text('No activity logs found.'));
                }

                return ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index].data() as Map<String, dynamic>;
                    final type = log['type'] ?? 'UNKNOWN';
                    final timestamp = log['timestamp'] != null
                        ? (log['timestamp'] as Timestamp).toDate()
                        : DateTime.now();

                    return ListTile(
                      leading: Icon(
                        type == 'SIGN_IN' ? Icons.login : Icons.logout,
                        color: type == 'SIGN_IN' ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        type == 'SIGN_IN' ? 'Signed In' : 'Signed Out',
                      ),
                      subtitle: Text(
                        DateFormat(
                          'EEEE, MMM dd, yyyy HH:mm:ss',
                        ).format(timestamp),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
