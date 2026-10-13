import 'package:flutter/widgets.dart';

/// Scrolls the first field showing a validation error into view.
///
/// Call right after `FormState.validate()` returns false, passing the
/// form's key. On long forms the save button sits far below the fields, so
/// without this the error can be off screen and the tap looks like it did
/// nothing.
void scrollToFirstFormError(GlobalKey<FormState> formKey) {
  final root = formKey.currentContext;
  if (root == null) return;
  BuildContext? first;
  void visit(Element element) {
    if (first != null) return;
    if (element is StatefulElement &&
        element.state is FormFieldState &&
        (element.state as FormFieldState).hasError) {
      first = element;
      return;
    }
    element.visitChildren(visit);
  }

  (root as Element).visitChildren(visit);
  final target = first;
  if (target == null) return;
  Scrollable.ensureVisible(
    target,
    alignment: 0.2,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
}
