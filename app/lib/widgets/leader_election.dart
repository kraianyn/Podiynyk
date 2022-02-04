import 'package:flutter/material.dart';

import 'package:podiynyk/storage/cloud.dart' show Cloud;
import 'package:podiynyk/storage/local.dart' show Local;
import 'package:podiynyk/storage/entities/student.dart';


class LeaderElection extends StatefulWidget {
	final void Function() endLeaderElection;

	const LeaderElection({required this.endLeaderElection});

	@override
	State<LeaderElection> createState() => _LeaderElectionState();
}

class _LeaderElectionState extends State<LeaderElection> {
	static const _intro = "The next thing you will see is the list of groupmates that have made it to this point. "
		"When you see the leader, tap on them. If you are the leader, sit back and let them tap on you.";

	late Widget _content;

	_LeaderElectionState() {
		_content = GestureDetector(
			onDoubleTap: () => setState(() {
				_content = LeaderCandidateList(endLeaderElection: widget.endLeaderElection);
			}),
			child: Scaffold(
				body: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: const [
						Text('Almost there'),
						Text(_intro)
					]
				)
			)
		);
	}

	@override
	Widget build(BuildContext context) {
		return _content;
	}
}


class LeaderCandidateList extends StatefulWidget {
	final void Function() endLeaderElection;

	const LeaderCandidateList({required this.endLeaderElection});

	@override
	_LeaderCandidateListState createState() => _LeaderCandidateListState();
}

class _LeaderCandidateListState extends State<LeaderCandidateList> {
	String? _votedForId;

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			body: Center(child: StreamBuilder<List<Student>?>(
				stream: _updates(),
				builder: (context, snapshot) {
					if (snapshot.connectionState == ConnectionState.waiting) return const Icon(Icons.cloud_download);
					// if (snapshot.hasError) print(snapshot.error);  // todo: consider handling

					final students = snapshot.data!;
  
					return ListView(
						shrinkWrap: true,
						children: [
							for (final student in students) ListTile(
								title: Text(student.name),
								trailing: student.confirmationCount == 0 ?
									null :
									Text(student.confirmationCount.toString()),
								onTap: student.name == Local.name ? null : () {
									if (student.id == _votedForId) return;

									Cloud.changeLeaderVote(toId: student.id, fromId: _votedForId);
									_votedForId = student.id;
								}
							)
						]
					);
				}
			))
		);
	}

	Stream<List<Student>> _updates() async* {
		await for (final students in Cloud.leaderElectionUpdates) {
			if (students != null) {
				yield students;
			}
			else {
				widget.endLeaderElection();
			}
		}
	}
}
