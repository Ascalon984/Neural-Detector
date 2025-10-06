# Keep Flutter embedding
-keep class io.flutter.embedding.** { *; }

# Keep Flutter plugin registrars
-keep class io.flutter.plugins.** { *; }

# Keep ML Kit (narrow this if you can; broad rules avoid missing-class at runtime)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep any reflection/serialization models your app depends on (example)
-keep class com.example.ai_text_checker.** { *; }

# Keep Kotlin metadata
-keepclassmembers class kotlin.Metadata { *; }
