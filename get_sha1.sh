#!/bin/bash

# Google Sign-In Setup Helper Script
# This script helps you get the SHA-1 certificate for Android

echo "🔍 Getting SHA-1 Certificate for Android..."
echo ""

cd android

echo "📱 Debug SHA-1 (for development):"
./gradlew signingReport | grep "SHA1:" | head -1

echo ""
echo "✅ Copy the SHA-1 fingerprint above and add it to Firebase Console:"
echo "   Firebase Console → Project Settings → Your Android App → Add Fingerprint"
echo ""
echo "📖 For detailed setup instructions, see GOOGLE_SIGNIN_GUIDE.md"
