import 'package:cloud_firestore/cloud_firestore.dart';

import 'entities.dart';
import 'local.dart';

typedef Document = DocumentReference<Map<String, dynamic>>;
typedef Roles = Map<String, Role>;
typedef Events = Map<String, Map<String, Object>>;


class Cloud {
	static final _cloud = FirebaseFirestore.instance;

	static late Role _role;
	/// The user's [Role] in the group.
	static Role get role => _role;

	/// The [Roles] of the group's students. Updates the user's [Role].
	static Future<Roles> roles() async {
		final rawRoles = await _document(Collection.students).get();
		final roles = {
			for (final studentRole in rawRoles.data()!.entries)
			studentRole.key: Role.values[studentRole.value as int]
		};

		_role = roles[Local.name]!;
		return roles;
	}

	/// Adds a subject with the [name] unless it exists.
	static Future<void> addSubject({required String name}) async => await _addEntity(
		entities: Collection.subjects,
		existingEquals: (existingSubject) => existingSubject == name,
		entity: name,
		details: {Field.totalEventCount.name: 0}
	);

	/// The names of the group's subjects.
	static Future<List<String>> subjectNames() async {
		final subjectsSnapshot = await _document(Collection.subjects).get();
		return subjectsSnapshot.exists ? List<String>.from(subjectsSnapshot.data()!.values) : [];
	}

	/// The group's [subjects].
	static Future<List<Subject>> subjects() async {
		final snapshots = await Future.wait([
			_document(Collection.subjects).get(),
			_document(Collection.events).get()
		]);
		final subjectNames = (snapshots.first.data() ?? {}).values;
		final eventEntries = (snapshots.last.data() ?? {}) as Events;

		final subjectsEvents = {for (final subject in subjectNames) subject: <Event>[]};

		for (final event in eventEntries.values) {
			subjectsEvents[event[Field.subject.name]]!.add(Event(
				name: event[Field.name.name] as String,
				subject: event[Field.subject.name] as String?,
				date: event[Field.date.name] as DateTime
			));
		}

		return [for (final subjectName in subjectNames) Subject(
			name: subjectName,
			events: subjectsEvents[subjectName]!
		)];
	}

	/// Adds an event with the arguments unless it exists.
	static Future<void> addEvent({
		required String name,
		String? subject,
		required DateTime date,
		String? note
	}) async {
		final wasWritten = await _addEntity(
			entities: Collection.events,
			existingEquals: (existingEvent) => existingEvent[Field.name.name] == name && existingEvent[Field.subject.name] == subject,
			entity: {
				Field.name.name: name,
				if (subject != null) Field.subject.name: subject,
				Field.date.name: date,
			},
			details: note != null ? {Field.note.name: note} : null,
		);

		if (wasWritten) {
			final document = _document(Collection.subjects);

			final subjectsSnapshot = await document.get();
			final subjectId = subjectsSnapshot.data()!.entries.firstWhere(
				(subjectEntry) => subjectEntry.value == subject
			).key;

			document.collection(Collection.details.name).doc(subjectId).update({
				Field.totalEventCount.name: FieldValue.increment(1)
			});
		}
	}

	/// Adds a message with the arguments unless it exists.
	static Future<void> addMessage({
		required String subject,
		required String content
	}) async => await _addEntity(
		entities: Collection.messages,
		existingEquals: (existingSubject) => existingSubject == subject,
		entity: subject,
		details: {Field.content.name: content},
	);

	/// Adds the [entity] unless it exists, with the given [details] unless they are `null`.
	/// Returns whether the [entity] was written.
	static Future<bool> _addEntity({
		required Collection entities,
		required bool Function(dynamic existingEntity) existingEquals,
		required Object entity,
		Map<String, Object>? details
	}) async {
		final document = _document(entities);

		final id = await _cloud.runTransaction((transaction) async {
			final entitiesSnapshot = await transaction.get(document);
			int intId = 0;

			if (entitiesSnapshot.exists) {
				final entityEntries = entitiesSnapshot.data()!;

				for (final existingEntity in entityEntries.values) {
					if (existingEquals(existingEntity)) return null;
				}

				final takenIds = entityEntries.keys;
				while (takenIds.contains(intId.toString())) intId++;
			}

			final id = intId.toString();
			final entityEntry = {id: entity};

			if (entitiesSnapshot.exists) {
				transaction.update(document, entityEntry);
			}
			else {
				transaction.set(document, entityEntry);
			}

			return id;
		});

		final wasWritten = id != null;
		if (details != null && wasWritten) document.collection(Collection.details.name).doc(id).set(details);
		return wasWritten;
	}

	/// [DocumentReference] to the document with the group's [entities].
	static Document _document(Collection entities) => _cloud.collection(entities.name).doc(Local.groupId);
}


/// The [Collection]s used in [FirebaseFirestore].
enum Collection {
	students,
	subjects,
	events,
	details,
	messages
}

/// The [Field]s used in [FirebaseFirestore].
enum Field {
	name,
	totalEventCount,
	subject,
	date,
	note,
	content
}
