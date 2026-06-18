# ML Kit Text Recognition: usiamo solo lo script latino. Il plugin
# google_mlkit_text_recognition referenzia anche i riconoscitori di altri
# alfabeti (cinese, giapponese, coreano, devanagari) che non includiamo nel
# bundle: senza queste regole R8 fallisce la minificazione del release per
# "Missing class". Diciamogli di ignorarli (non vengono mai usati a runtime).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
