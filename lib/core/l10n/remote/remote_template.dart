// lib/core/l10n/remote/remote_template.dart
// Fills `{name}` placeholders of a remote text with the call's arguments.

final RegExp _placeholder = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');

/// Replaces every `{name}` in [template] with `args[name]`. One pass over the template, so an argument that itself contains
/// `{something}` is never expanded again. A name without an argument is left as written (the validator guarantees the template's
/// placeholder names equal the bundled ones, so this only protects against misuse).
String fillRemoteTemplate(String template, Map<String, String> args) => template
    .replaceAllMapped(_placeholder, (m) => args[m.group(1)] ?? m.group(0)!);
