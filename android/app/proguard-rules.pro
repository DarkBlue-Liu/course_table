# flutter_local_notifications 17.x restores scheduled notifications via Gson.
# Keep generic signatures and TypeToken subclasses in R8 full mode.
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }
# Notification model fields are serialized reflectively into local preferences.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
