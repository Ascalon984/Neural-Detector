# Minimal ProGuard rules for Flutter + ML Kit
# Keep Flutter embedding and plugin registrars
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Keep ML Kit classes (narrow this down later if needed)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep other known plugin packages (add more if you see missing-class at runtime)
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**
