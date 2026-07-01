# Keep rules so R8/ProGuard don't break flutter_local_notifications' Gson
# (de)serialization of scheduled notifications ("Missing type parameter").
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses, EnclosingMethod
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keepclassmembers class com.dexterous.flutterlocalnotifications.models.** { <fields>; }
