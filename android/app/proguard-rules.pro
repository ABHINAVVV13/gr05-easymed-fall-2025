# Stripe Android SDK ProGuard rules
# Keep all Stripe classes
-keep class com.stripe.android.** { *; }

# Suppress warnings for optional push provisioning features
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

# Suppress warnings for React Native Stripe SDK (transitive dependency)
-dontwarn com.reactnativestripesdk.**

# General Android rules
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

