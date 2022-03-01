import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'fields.dart';
import 'local.dart';

import 'entities/county.dart';
import 'entities/department.dart';
import 'entities/event.dart';
import 'entities/identification_option.dart';
import 'entities/message.dart';
import 'entities/question.dart';
import 'entities/student.dart';
import 'entities/subject.dart';
import 'entities/university.dart';


typedef CloudData = Map<String, dynamic>;


/// The group's [Collection] stored in [FirebaseFirestore].
enum Collection {
	counties,
	universities,
	groups,
	subjects,
	events,
	messages,
	questions,
	details
}

extension on Collection {
	/// [DocumentReference] to the document with the group's data of [collection] type.
	DocumentReference<CloudData> get ref =>	
		FirebaseFirestore.instance.collection(name).doc(Local.groupId);
	
	/// [DocumentReference] to the details of the entity with the [id] in the group's data of [collection] type.
	DocumentReference<CloudData> detailsRef(String id) =>	
		ref.collection(Collection.details.name).doc(id);
}


extension on CloudData {
	int get newId {
		int id = 0;
		while (containsKey(id.toString())) id++;
		return id;
	}
}


class Cloud {
	static final _cloud = FirebaseFirestore.instance;

	/// Initializes [Firebase] and synchronizes the user's [Role] in the group.
	static Future<void> init() async {
		await Firebase.initializeApp();
	}

	/// The [County]s of Ukraine.
	static Future<List<County>> get counties => _identificationOptions(
		collection: Collection.counties,
		document: Collection.counties.name,
		optionConstructor: ({required id, required name}) => County(id: id, name: name)
	);

	/// The [University]s of the [county].
	static Future<List<University>> universities(County county) => _identificationOptions(
		collection: Collection.counties,
		document: county.id,
		optionConstructor: ({required id, required name}) => University(id: id, name: name)
	);

	/// The [Department]s of the [university].
	static Future<List<Department>> departments(University university) => _identificationOptions(
		collection: Collection.universities,
		document: university.id,
		optionConstructor: ({required id, required name}) => Department(id: id, name: name)
	);

	static Future<List<O>> _identificationOptions<O extends IdentificationOption>({
		required Collection collection,
		required String document,
		required O Function({required String id, required String name}) optionConstructor
	}) async {
		final snapshot = await _cloud.collection(collection.name).doc(document).get();
		return [
			for (final entry in snapshot.data()!.entries) optionConstructor(
				id: entry.key,
				name: entry.value,
			)
		]..sort();
	}

	/// Adds the user to the group. If they are the group's first student, initializes the group's documents.
	static Future<void> enterGroup() async {
		final document = Collection.groups.ref;

		Local.id = await _cloud.runTransaction((transaction) async {
			final snapshot = await transaction.get(document);
			late String id;

			if (snapshot.exists) {
				final data = snapshot.data()!;
				id = CloudData.from(data[Field.names.name]).newId.toString();

				final selfInitField = data.containsKey(Field.roles.name) ? Field.roles : Field.confirmationCounts;
				transaction.update(document, {
					'${Field.names.name}.$id': Local.name,
					'${selfInitField.name}.$id': 0
				});
			}
			else {
				id = '0';

				// the [set] method does not support nested fields via dot notation
				transaction.set(document, {
					Field.names.name: {id: Local.name},
					Field.confirmationCounts.name: {id: 0},
					Field.joined.name: DateTime.now()
				});

				Collection.subjects.ref.set({});
				Collection.events.ref.set({});
				Collection.messages.ref.set({});
				Collection.questions.ref.set({});
			}

			return id;
		});
	}

	/// Whether the group is past the [LeaderElection] step. Updates [role].
	static Future<bool> get leaderIsElected async {
		final snapshot = await Collection.groups.ref.get();
		final data = snapshot.data()!;

		final isElected = data.containsKey(Field.roles.name);
		if (isElected) {
			final roleIndex = data[Field.roles.name][Local.id];
			_role = Role.values[roleIndex];
		}

		return isElected;
	}

	/// A [Stream] of updates of the group's [Student]s and confirmations for them to be the group's leader.
	/// As soon as the leader is determined, `null` is returned.
	static Stream<List<Student>?> get leaderElectionUpdates {
		return Collection.groups.ref.snapshots().map((snapshot) {
			final data = snapshot.data()!;

			if (data.containsKey(Field.confirmationCounts.name)) return [
				for (final id in data[Field.names.name].keys) Student.candidateFromCloudFormat(
					id,
					data: data
				)
			]..sort((a, b) => a.compareIdTo(b));

			// tofix: actually take the role from the data
			_role = Role.ordinary;
			return null;
		});
	}

	/// Adds a confirmation for the student with the id [toId].
	/// Takes one from the student with the id [fromId] if it is not `null`.
	static Future<void> changeLeaderVote({
		required String toId,
		String? fromId
	}) async {
		await Collection.groups.ref.update({
			'${Field.confirmationCounts.name}.$toId': FieldValue.increment(1),
			if (fromId != null) '${Field.confirmationCounts.name}.$fromId': FieldValue.increment(-1)
		});
	}

	static late Role _role;
	/// The user's [Role].
	static Role get role => _role;

	/// The group's sorted [Subject]s without the details.
	static Future<List<Subject>> get subjects async {
		final snapshots = await Future.wait([
			Collection.subjects.ref.get(),
			Collection.events.ref.get()
		]);

		final events = [
			for (final entry in snapshots.last.data()!.entries) Event.fromCloudFormat(entry)
		]..sort();

		return [
			for (final entry in snapshots.first.data()!.entries) Subject.fromCloudFormat(
				entry,
				events: events.where((event) =>
					event.subjectName == entry.value[Field.name.name]
				).toList()
			)
		]..sort();
	}

	/// The sorted names of the group's [Subject]s.
	static Future<List<String>> get subjectNames async {
		final snapshot = await Collection.subjects.ref.get();
		return [
			for (final entry in snapshot.data()!.entries) Subject.nameFromCloudFormat(entry)
		]..sort();
	}

	/// The group's sorted [Event]s without the details.
	static Future<List<Event>> get events async {
		final snapshot = await Collection.events.ref.get();
		return [
			for (final entry in snapshot.data()!.entries) Event.fromCloudFormat(entry)
		]..sort();
	}

	/// The group's sorted non-subject [Event]s.
	static Future<List<Event>> get nonSubjectEvents async {
		final snapshot = await Collection.events.ref.get();
		final eventEntries = snapshot.data()!.entries.where((entry) =>
			entry.value[Field.subject.name] == null
		);

		return [
			for (final entry in eventEntries) Event.fromCloudFormat(entry)
		]..sort();
	}

	/// The group's [Message]s without the details.
	static Future<List<Message>> get messages async {
		final snapshot = await Collection.messages.ref.get();
		return [
			for (final entry in snapshot.data()!.entries) Message.fromCloudFormat(entry)
		]..sort();
	}

	// todo: define
	/// The group's [Question]s without the details.
	static Future<List<Question>> get questions async {
		return [];
	}

	/// The group's [Student]s. Updates [role].
	static Future<List<Student>> get students async {
		final snapshot = await Collection.groups.ref.get();
		final data = snapshot.data()!;

		final students = [
			for (final id in data[Field.names.name].keys) Student.fromCloudFormat(
				id,
				data: data
			)
		]..sort();

		_role = students.firstWhere((student) => student.name == Local.name).role!;
		return students;
	}

	/// The details of the [collection] entity with the [id].
	static Future<CloudData> entityDetails(Collection collection, String id) async {
		final snapshot = await collection.detailsRef(id).get();
		return snapshot.data()!;
	}

	// todo: should all new entities check whether they already exist?

	/// Adds a [Subject] with the [name] unless it exists.
	static Future<void> addSubject({required String name}) async => await _addEntity(
		collection: Collection.subjects,
		existingEquals: (existing) => existing[Field.name.name] == name,
		entity: {Field.name.name: name},
		details: {Field.info.name: <String>[]}
	);

	/// Updates the [subject]'s information.
	static Future<void> updateSubjectInfo(Subject subject) async {
		Collection.subjects.detailsRef(subject.id).update({
			Field.info.name: [for (final item in subject.info!) item.inCloudFormat]
		});
	}

	/// Adds an [Event] with the arguments unless it exists. Increments the [subjectName]'s total event count.
	static Future<void> addEvent({
		required String name,
		String? subjectName,
		required DateTime date,
		String? note
	}) async => await _addEntity(
		collection: Collection.events,
		existingEquals: (existing) =>
			existing[Field.name.name] == name && existing[Field.subject.name] == subjectName,
		entity: {
			Field.name.name: name,
			Field.subject.name: subjectName,
			Field.date.name: date,
		},
		details: {if (note != null) Field.note.name: note},
	);

	/// Updates the [event]'s date.
	static Future<void> updateEventDate(Event event) async {
		await Collection.events.ref.update({
			'${event.id}.${Field.date.name}': event.date
		});
	}

	/// Updates the [event]'s note.
	static Future<void> updateEventNote(Event event) async {
		await Collection.events.detailsRef(event.id).update({
			Field.note.name: event.note
		});
	}

	/// Adds a [Message] with the arguments unless it exists.
	static Future<void> addMessage({
		required String name,
		required String content,
	}) async => await _addEntity(
		collection: Collection.messages,
		existingEquals: (existing) => existing[Field.name.name] == name,
		entity: {
			Field.name.name: name,
			Field.date.name: DateTime.now()
		},
		details: {
			Field.content.name: content,
			Field.author.name: Local.name
		},
	);

	/// Updates the [message]'s name (topic).
	static Future<void> updateMessageName(Message message) async {
		await Collection.messages.ref.update({
			'${message.id}.${Field.name.name}': message.name
		});
	}

	/// Updates the [message]'s content.
	static Future<void> updateMessageContent(Message message) async {
		await Collection.messages.detailsRef(message.id).update({
			Field.content.name: message.content
		});
	}

	// todo: define
	/// Adds a [Question] with the arguments unless it exists.
	static Future<void> addQuestion() async {}

	/// Adds the [entity] unless it exists, with the given [details] unless they are `null`.
	/// Returns whether the [entity] was written.
	static Future<bool> _addEntity({
		required Collection collection,
		required bool Function(Map<String, dynamic> existing) existingEquals,
		required Object entity,
		Map<String, Object>? details
	}) async {
		final document = collection.ref;

		final id = await _cloud.runTransaction((transaction) async {
			final snapshot = await transaction.get(document);
			final entries = snapshot.data()!;

			for (final existingEntity in entries.values) {
				if (existingEquals(existingEntity)) return null;
			}

			final id = entries.newId.toString();
			transaction.update(document, {id: entity});

			return id;
		});

		final wasWritten = id != null;
		if (details != null && wasWritten) await collection.detailsRef(id).set(details);
		return wasWritten;
	}

	// todo: delete the events
	/// Deletes the [subject]. The [subject]'s events are kept.
	static Future<void> deleteSubject(Subject subject) async {
		await Future.wait([
			Collection.subjects.ref.update({subject.id: FieldValue.delete()}),
			Collection.subjects.detailsRef(subject.id).delete()
		]);
	}

	/// Deletes the [event].
	static Future<void> deleteEvent(Event event) async {
		await Future.wait([
			Collection.events.ref.update({event.id: FieldValue.delete()}),
			Collection.events.detailsRef(event.id).delete()
		]);
	}

	/// Deletes the [message].
	static Future<void> deleteMessage(Message message) async {
		await Future.wait([
			Collection.messages.ref.update({message.id: FieldValue.delete()}),
			Collection.messages.detailsRef(message.id).delete()
		]);
	}

	/// Sets the [student]'s [Role] to [role].
	static Future<void> setRole(Student student, Role role) async {
		await Collection.groups.ref.update({
			'${Field.roles.name}.${student.id}': role.index
		});
	}

	/// Sets the [Role] of the [student] to [Role.leader], and the user's role to [Role.trusted].
	static Future<void> makeLeader(Student student) async {
		await Collection.groups.ref.update({
			'${Field.roles.name}.${Local.id}': Role.trusted.index,
			'${Field.roles.name}.${student.id}': Role.leader.index
		});
		_role = Role.trusted;
	}
}
