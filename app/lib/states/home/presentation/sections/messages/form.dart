import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:podiinyk/core/domain/id.dart';
import 'package:podiinyk/core/domain/types/date.dart';
import 'package:podiinyk/core/domain/user/state.dart';

import '../../../domain/entities/message.dart';
import '../../../domain/providers/messages.dart';


// do: TextField.(textInputType, multiline, textInputAction)
class MessageForm extends HookConsumerWidget {
	const MessageForm();

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final nameField = useTextEditingController();
		final contentField = useTextEditingController();

		return GestureDetector(
			onDoubleTap: () => _handleAdd(context, ref, nameField.text, contentField.text),
			child: Scaffold(body: Column(
				mainAxisAlignment: MainAxisAlignment.center,
				children: [
					TextField(
						controller: nameField,
						decoration: const InputDecoration(labelText: 'topic')
					),
					TextField(
						controller: contentField,
						decoration: const InputDecoration(labelText: 'content')
					)
				]
			))
		);
	}

	void _handleAdd(BuildContext context, WidgetRef ref, String name, String content) {
		// do: inform the user
		if (name.isEmpty || content.isEmpty) return;

		final user = ref.read(userProvider);
		// think: await to show success or a failure
		ref.read(messagesProvider.notifier).add(Message(
			id: newId(user: user),
			name: name,
			content: content,
			author: user.student,
			date: Date.now()
		));
		Navigator.of(context).pop();
	}
}
