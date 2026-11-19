import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import '../services/app_clock.dart';
import '../services/todo_repository.dart';

Future<TodoItem?> showLinkTodoDialog(
  BuildContext context, {
  required TodoRepository todos,
  required AppClock clock,
  required Set<String> alreadyLinked,
}) async {
  final items = [
    ...todos.activeItems,
    ...todos.completedItems,
  ].where((e) => !alreadyLinked.contains(e.id)).toList();
  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('没有可关联的待办')),
    );
    return null;
  }
  return showDialog<TodoItem>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('关联待办'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item.title),
              subtitle: item.remindAt == null
                  ? null
                  : Text(clock.format(item.remindAt, 'MM-dd HH:mm')),
              onTap: () => Navigator.pop(context, item),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}
