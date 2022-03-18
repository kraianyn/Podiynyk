import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:podiynyk/storage/appearance.dart';
import 'package:podiynyk/storage/cloud.dart';
import 'package:podiynyk/storage/entities/event.dart';
import 'package:podiynyk/storage/entities/subject.dart' show Subject;

import 'package:podiynyk/ui/main/common/fields.dart';

import 'entity.dart';


class NewEventPage extends HookWidget {
	const NewEventPage() :
		_doAskSubject = true,
		_subjectIsDefined = false,
		_initialSubject = null;

	const NewEventPage.subjectEvent(Subject subject) :
		_doAskSubject = false,
		_subjectIsDefined = true,
		_initialSubject = subject;

	const NewEventPage.nonSubjectEvent() :
		_doAskSubject = false,
		_subjectIsDefined = false,
		_initialSubject = null;

	final bool _doAskSubject;
	final bool _subjectIsDefined;
	final Subject? _initialSubject;

	@override
	Widget build(BuildContext context) {
		final nameField = useTextEditingController();
		final subjectField = useTextEditingController(text: _initialSubject?.nameRepr);
		final noteField = useTextEditingController();

		final subject = useRef(_initialSubject);
		final date = useRef<DateTime?>(null);

		final subjectsFuture = useMemoized(() => _doAskSubject ? Cloud.subjects : null);

		return NewEntityPage(
			add: () => _add(nameField.text, subject.value, date.value, noteField.text),
			children: [
				InputField(
					controller: nameField,
					name: "name",
					style: Appearance.headlineText
				),
				if (_doAskSubject || _subjectIsDefined) OptionField(
					controller: subjectField,
					name: "subject",
					showOptions: !_subjectIsDefined ?
						(context) => _askSubject(context, subjectsFuture!, subject, subjectField) :
						null,
					style: Appearance.largeTitleText
				),
				DateField(onDatePicked: (picked) => date.value = picked),
				const ListTile(),
				InputField(
					controller: noteField,
					name: "note",
					multiline: true,
					style: Appearance.bodyText
				)
			]
		);
	}

	void _askSubject(
		BuildContext context,
		Future<List<Subject>> future,
		ObjectRef<Subject?> current,
		TextEditingController field
	) {
		Navigator.of(context).push(MaterialPageRoute(
			builder: (context) => Scaffold(
				body: Center(child: FutureBuilder<List<Subject>>(
					future: future,
					builder: (context, snapshot) => _subjectsBuilder(context, snapshot, current, field)
				))
			)
		));
	}

	Widget _subjectsBuilder(
		BuildContext context,
		AsyncSnapshot<List<Subject>> snapshot,
		ObjectRef<Subject?> current,
		TextEditingController field
	) {
		if (snapshot.connectionState == ConnectionState.waiting) return const Text("awaiting the subjects");
		// if (snapshot.hasError) print(snapshot.error);  // todo: consider handling

		final subjects = snapshot.data!;
		return subjects.isNotEmpty ? ListView(
			shrinkWrap: true,
			children: [
				for (final subject in subjects..remove(current.value)) ListTile(
					title: Text(subject.nameRepr),
					onTap: () => _handleSubject(context, subject, current, field)
				),
				if (current.value != null) ...[
					if (subjects.length != 1) const ListTile(),
					ListTile(
						title: const Text("none"),
						onTap: () => _handleSubject(context, null, current, field)
					)
				]
			]
		) : const Text("no subjects");
	}

	void _handleSubject(
		BuildContext context,
		Subject? picked,
		ObjectRef<Subject?> current,
		TextEditingController field
	) {
		current.value = picked;
		field.text = picked != null ? picked.nameRepr : '';
		Navigator.of(context).pop();
	}

	bool _add(String name, Subject? subject, DateTime? date, String note) {
		if (name.isEmpty || date == null) return false;

		final event = Event(
			name: name,
			subject: subject,
			date: date,
			note: note.isNotEmpty ? note : null
		);
		Cloud.addEvent(event);
		return true;
	}
}
