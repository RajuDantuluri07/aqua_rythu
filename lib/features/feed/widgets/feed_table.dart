import 'package:flutter/material.dart';

class FeedTable extends StatelessWidget {
  final List logs;

  const FeedTable({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return ListTile(
          title: Text("DOC ${log.doc}"),
          subtitle: Text("${log.totalFeed} kg"),
        );
      },
    );
  }
}