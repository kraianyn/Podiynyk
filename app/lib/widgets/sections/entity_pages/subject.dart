import 'package:flutter/material.dart';

import 'package:podiynyk/storage/cloud.dart' show Cloud;
import 'package:podiynyk/storage/local.dart';
import 'package:podiynyk/storage/entities/student.dart' show Role;
import 'package:podiynyk/storage/entities/subject.dart' show Subject;

import 'package:podiynyk/widgets/sections/new_entity_pages/event.dart';

import '../agenda.dart';
import 'entity.dart';


class SubjectPage extends StatefulWidget {
	final Subject _subject;
	final _nameField = TextEditingController();
	final _infoField = TextEditingController();

	SubjectPage(this._subject) {
		_nameField.text = _subject.name;
	}

	@override
	State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
	@override
	void initState() {
		widget._subject.addDetails().whenComplete(() => setState(() {}));
		super.initState();
	}

	@override
	Widget build(BuildContext context) {
		final subject = widget._subject;
		final totalEventCount = subject.totalEventCount;
		final info = subject.info;
		final events = subject.events;

		final isFollowed = !Local.entityIsStored(StoredEntities.unfollowedSubjects, subject);

		return EntityPage(
			children: [
				TextField(
					controller: widget._nameField,
					decoration: const InputDecoration(hintText: "subject"),
					onSubmitted: (label) {},  // todo: add the label
				),
				if (totalEventCount != null) Text("${subject.totalEventCountRepr} so far"),
				if (info != null) TextButton(
					child: const Text("information"),
					onPressed: () => _showPage([
						for (final entry in info) Text(entry)  // todo: make them fields to enable editing
					])
				),
				if (events.isNotEmpty) TextButton(
					child: Text(subject.eventCountRepr),
					onPressed: () => _showPage([
						for (final event in events) EventTile(event, showSubject: false)
					])
				)
			],
			actions: [
				EntityActionButton(
					text: "add an event",
					action: () => Navigator.of(context).push(MaterialPageRoute(
						builder: (_) => NewEventPage.subjectEvent(subject.name)
					))
				),
				EntityActionButton(
					text: "add information",
					action: () => Navigator.of(context).push(MaterialPageRoute(
						builder: (_) => GestureDetector(
							onDoubleTap: addInfo,
							child: Scaffold(
								body: Center(child: TextField(
									controller: widget._infoField
								))
							)
						)
					))
				),
				isFollowed ? EntityActionButton(
					text: "unfollow",
					action: () => Local.addStoredEntity(StoredEntities.unfollowedSubjects, subject)
				) : EntityActionButton(
					text: "follow",
					action: () => Local.deleteStoredEntity(StoredEntities.unfollowedSubjects, subject)
				),
				if (Cloud.role == Role.leader) EntityActionButton(
					text: "delete",
					action: () => Cloud.deleteSubject(subject)
				)
			]
		);
	}

	void _showPage(List<Widget> children) {
		Navigator.of(context).push(MaterialPageRoute(builder: (context) => Scaffold(
			body: Column(
				mainAxisAlignment: MainAxisAlignment.center,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: children
			)
		)));
	}

	void addInfo() {
		final subject = widget._subject;
		subject.info ??= [];

		subject.info!.add(widget._infoField.text);
		Cloud.updateSubjectInfo(widget._subject);
		Navigator.of(context).pop();
	}
}
