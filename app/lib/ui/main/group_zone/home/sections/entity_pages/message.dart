import 'package:flutter/material.dart';

import 'package:podiynyk/storage/cloud.dart';
import 'package:podiynyk/storage/local.dart';
import 'package:podiynyk/storage/entities/date.dart';
import 'package:podiynyk/storage/entities/message.dart';

import 'package:podiynyk/ui/main/common/fields.dart' show InputField;

import 'entity.dart';


class MessagePage extends StatefulWidget {
	final Message message;

	const MessagePage(this.message);

	@override
	State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
	late final Message _message;
	final _nameField = TextEditingController();
	final _contentField = TextEditingController();

	@override
	void initState() {
		super.initState();
		_message = widget.message;
		_nameField.text = _message.name;
		_message.addDetails().whenComplete(() => setState(() {}));
	}

	@override
	Widget build(BuildContext context) {
		final author = _message.author;
		final isAuthor = Local.name == author;

		final content = _message.content;
		final hasContent = content != null;
		if (hasContent) _contentField.text = content;

		return EntityPage(
			children: [
				InputField(
					controller: _nameField,
					name: "topic",
					enabled: isAuthor,
					onSubmitted: _setName,
				),
				Text(_message.date.fullRepr),
				if (author != null) Text("from $author"),
				if (hasContent) InputField(
					controller: _contentField,
					name: "content",
					enabled: isAuthor,
					onSubmitted: _setContent,
				)
			],
			actions: !isAuthor ? null : [EntityActionButton(
				text: "delete",
				action: () => Cloud.deleteMessage(_message)
			)]
		);
	}

	void _setName(String name) {
		if (name.isNotEmpty) {
			_message.name = name;
		}
		else {
			_nameField.text = _message.name;
		}
	}

	void _setContent(String content) {
		if (content.isNotEmpty) {
			_message.content = content;
		}
		else {
			_contentField.text = _message.content!;
		}
	}
}
