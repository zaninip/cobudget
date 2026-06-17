import 'package:flutter/material.dart';

/// Avviso non bloccante mostrato quando lo stadio di categorizzazione con
/// apprendimento non e' disponibile (es. migrazione 0008 non applicata, RLS,
/// rete). L'operazione principale (salvare/importare le spese) riesce comunque:
/// questo serve solo a far accorgere che i suggerimenti non sono attivi.
const learningUnavailableMessage =
    'Attenzione: categorizzazione automatica non attiva';

SnackBar learningWarningSnackBar() => const SnackBar(
      content: Text(learningUnavailableMessage),
    );

void showLearningWarning(BuildContext context) =>
    ScaffoldMessenger.of(context).showSnackBar(learningWarningSnackBar());
