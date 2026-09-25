import 'package:material_ui/material_ui.dart';

/// Shows [message] with an Undo button, replacing any current snackbar.
///
/// [onUndo] runs if Undo is tapped. [onCommit] runs once the snackbar goes
/// away any other way (timeout, swiped off, replaced by the next one) —
/// used to hold back changes the server can't reverse, like deleting.
void showUndoSnackBar(
  ScaffoldMessengerState messenger,
  String message, {
  required VoidCallback onUndo,
  VoidCallback? onCommit,
}) {
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      persist: false,
      action: SnackBarAction(label: 'Undo', onPressed: onUndo),
    ),
  );
  if (onCommit != null) {
    controller.closed.then((reason) {
      if (reason != SnackBarClosedReason.action) onCommit();
    });
  }
}
