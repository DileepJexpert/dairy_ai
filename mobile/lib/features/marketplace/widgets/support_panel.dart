import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/providers/admin_marketplace_provider.dart';

final storeHelpProvider = FutureProvider<Map<String, dynamic>>((ref) async =>
    Map<String, dynamic>.from(
        (await ref.watch(dioProvider).get('/marketplace/help')).data['data']));
final supportTicketsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, bool>((ref, admin) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final response = await ref
      .watch(dioProvider)
      .get(admin ? '/marketplace/admin/support' : '/marketplace/support');
  return (response.data['data'] as List)
      .map((j) => Map<String, dynamic>.from(j))
      .toList();
});

class SupportPanel extends ConsumerWidget {
  const SupportPanel({super.key, this.admin = false});
  final bool admin;

  Future<void> edit(BuildContext context, WidgetRef ref,
      [Map<String, dynamic>? ticket]) async {
    if (ref.read(currentUserProvider) == null) {
      context.push('/login');
      return;
    }
    final subject = TextEditingController(text: ticket?['subject']?.toString());
    final message = TextEditingController(text: ticket?['reply']?.toString());
    var status = ticket?['status']?.toString() ?? 'OPEN';
    var saving = false;
    final form = GlobalKey<FormState>();
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                  title: Text(admin ? 'Reply to enquiry' : 'Contact Milterra'),
                  content: SizedBox(
                      width: 500,
                      child: SingleChildScrollView(
                          child: Form(
                              key: form,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!admin)
                                      TextFormField(
                                          controller: subject,
                                          maxLength: 200,
                                          decoration: const InputDecoration(
                                              labelText: 'Subject'),
                                          validator: (s) =>
                                              (s?.trim().length ?? 0) < 3
                                                  ? 'Enter a subject'
                                                  : null),
                                    if (admin) ...[
                                      Text(
                                          '${ticket?['customer_phone']}\n${ticket?['message']}'),
                                      DropdownButtonFormField<String>(
                                          initialValue: status,
                                          isExpanded: true,
                                          items: [
                                            'OPEN',
                                            'IN_PROGRESS',
                                            'CLOSED'
                                          ]
                                              .map((s) => DropdownMenuItem(
                                                  value: s, child: Text(s)))
                                              .toList(),
                                          onChanged: (s) => status = s!)
                                    ],
                                    TextFormField(
                                        controller: message,
                                        maxLength: 4000,
                                        maxLines: 5,
                                        decoration: InputDecoration(
                                            labelText: admin
                                                ? 'Reply (visible to customer)'
                                                : 'Your enquiry'),
                                        validator: (s) =>
                                            (s?.trim().length ?? 0) <
                                                    (admin ? 1 : 10)
                                                ? 'Please add more detail'
                                                : null),
                                    const Text(
                                        'Enquiries and replies are saved here. No paid messaging service is used.'),
                                  ])))),
                  actions: [
                    TextButton(
                        onPressed: saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!form.currentState!.validate()) return;
                                setDialog(() => saving = true);
                                try {
                                  if (admin) {
                                    await ref.read(dioProvider).patch(
                                        '/marketplace/admin/support/${ticket!['id']}',
                                        data: {
                                          'status': status,
                                          'reply': message.text.trim()
                                        });
                                  } else {
                                    await ref
                                        .read(dioProvider)
                                        .post('/marketplace/support', data: {
                                      'subject': subject.text.trim(),
                                      'message': message.text.trim()
                                    });
                                  }
                                  ref.invalidate(supportTicketsProvider);
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (context.mounted) {
                                    setDialog(() => saving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(commerceError(e))));
                                  }
                                }
                              },
                        child: Text(saving ? 'Saving…' : 'Submit'))
                  ],
                )));
    subject.dispose();
    message.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!admin)
          FilledButton.icon(
              onPressed: () => edit(context, ref),
              icon: const Icon(Icons.support_agent),
              label: const Text('Send an enquiry')),
        Row(children: [
          Expanded(
              child: Text(admin ? 'Customer enquiries' : 'Your enquiries',
                  style: Theme.of(context).textTheme.titleLarge)),
          IconButton(
              onPressed: () => ref.invalidate(supportTicketsProvider(admin)),
              icon: const Icon(Icons.refresh))
        ]),
        ref.watch(supportTicketsProvider(admin)).when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) =>
                Text('Could not load enquiries: ${commerceError(e)}'),
            data: (tickets) => Column(children: [
                  if (tickets.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No enquiries yet.')),
                  for (final t in tickets)
                    Card(
                        child: ListTile(
                            title: Text('${t['subject']} · ${t['status']}'),
                            subtitle: Text(
                                '${t['message']}\n${t['reply'].toString().isEmpty ? 'Awaiting reply' : t['reply']}'),
                            onTap: admin ? () => edit(context, ref, t) : null)),
                ])),
      ]);
}

class StoreHelpAdminScreen extends ConsumerWidget {
  const StoreHelpAdminScreen({super.key});
  Future<void> editHelp(
      BuildContext context, WidgetRef ref, Map<String, dynamic> data) async {
    final contact =
        TextEditingController(text: data['contact_message']?.toString());
    final rows = (data['faqs'] as List? ?? [])
        .map((j) => [
              for (final key in ['category', 'question', 'answer'])
                TextEditingController(text: j[key]?.toString())
            ])
        .toList();
    var saving = false;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                  title: const Text('Edit help content'),
                  content: SizedBox(
                      width: 640,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        TextField(
                            controller: contact,
                            maxLength: 2000,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText:
                                    'Contact information / current service status')),
                        for (var i = 0; i < rows.length; i++)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(children: [
                                    TextField(
                                        controller: rows[i][0],
                                        decoration: const InputDecoration(
                                            labelText: 'Category')),
                                    TextField(
                                        controller: rows[i][1],
                                        decoration: const InputDecoration(
                                            labelText: 'Question')),
                                    TextField(
                                        controller: rows[i][2],
                                        maxLines: 4,
                                        decoration: const InputDecoration(
                                            labelText: 'Answer')),
                                    TextButton(
                                        onPressed: saving
                                            ? null
                                            : () => setDialog(() {
                                                  for (final c
                                                      in rows.removeAt(i)) {
                                                    c.dispose();
                                                  }
                                                }),
                                        child: const Text('Remove FAQ')),
                                  ]))),
                        TextButton(
                            onPressed: saving
                                ? null
                                : () => setDialog(() => rows.add(List.generate(
                                    3, (_) => TextEditingController()))),
                            child: const Text('Add FAQ')),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setDialog(() => saving = true);
                                try {
                                  await ref
                                      .read(dioProvider)
                                      .put('/marketplace/admin/help', data: {
                                    'contact_message': contact.text,
                                    'faqs': [
                                      for (final r in rows)
                                        {
                                          'category': r[0].text,
                                          'question': r[1].text,
                                          'answer': r[2].text
                                        }
                                    ]
                                  });
                                  ref.invalidate(storeHelpProvider);
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (context.mounted) {
                                    setDialog(() => saving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(commerceError(e))));
                                  }
                                }
                              },
                        child: Text(saving ? 'Saving…' : 'Publish'))
                  ],
                )));
    contact.dispose();
    for (final row in rows) {
      for (final c in row) {
        c.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('Help content & customer enquiries')),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            ref.watch(storeHelpProvider).when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Could not load help: $e'),
                data: (data) => ListTile(
                    title: const Text('Storefront FAQ and contact information'),
                    trailing: FilledButton(
                        onPressed: () => editHelp(context, ref, data),
                        child: const Text('Edit content')))),
            const SupportPanel(admin: true),
          ])));
}
