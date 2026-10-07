# --- MediaPipe Tasks (pipeline nativo de visão do Sinaliza) ---
# MediaPipe chama várias classes via JNI/reflexão; sem estas regras o build
# release (R8) remove classes e o app quebra ao carregar os modelos.
-keep public class com.google.mediapipe.** { *; }
-keep class com.google.mediapipe.framework.** { *; }
-keep class com.google.mediapipe.tasks.** { *; }
-keep interface com.google.mediapipe.tasks.** { *; }
-keep class com.google.mediapipe.proto.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keep class * extends com.google.protobuf.GeneratedMessageLite$Builder { *; }
-keep class com.google.common.flogger.** { *; }
-keep public class com.google.common.** { *; }
-keep public interface com.google.common.* { *; }

# Canal nativo do app
-keep class com.example.sinaliza_app_libras.** { *; }

-dontwarn javax.annotation.**
-dontwarn javax.lang.model.**
-dontwarn com.google.auto.value.**
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate

# ONNX Runtime (usado via FFI pelo pacote onnxruntime)
-keep class ai.onnxruntime.** { *; }
