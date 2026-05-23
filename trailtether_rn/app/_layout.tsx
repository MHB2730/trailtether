// Trailtether — root layout.
//
// Loads the two custom fonts (Manrope + JetBrains Mono), holds the splash
// screen until they're ready, then renders the navigation stack which is
// composed entirely of the (tabs) group. Detail screens (trail-detail,
// achievements, forecast, etc.) are siblings of (tabs) inside `app/` and
// push on top of the tab bar via expo-router's default stack behaviour.

import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import {
  Manrope_400Regular,
  Manrope_500Medium,
  Manrope_600SemiBold,
  Manrope_700Bold,
  Manrope_800ExtraBold,
  useFonts as useManrope,
} from '@expo-google-fonts/manrope';
import {
  JetBrainsMono_400Regular,
  JetBrainsMono_500Medium,
  JetBrainsMono_600SemiBold,
  JetBrainsMono_700Bold,
  useFonts as useMono,
} from '@expo-google-fonts/jetbrains-mono';
import { tt } from '@theme/tokens';

// Keep the splash visible while we hydrate fonts so we don't flash a
// fallback system font on first render.
void SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const [manropeReady] = useManrope({
    Manrope_400Regular,
    Manrope_500Medium,
    Manrope_600SemiBold,
    Manrope_700Bold,
    Manrope_800ExtraBold,
  });
  const [monoReady] = useMono({
    JetBrainsMono_400Regular,
    JetBrainsMono_500Medium,
    JetBrainsMono_600SemiBold,
    JetBrainsMono_700Bold,
  });

  const ready = manropeReady && monoReady;

  useEffect(() => {
    if (ready) void SplashScreen.hideAsync();
  }, [ready]);

  if (!ready) return null;

  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: tt.bg }}>
      <SafeAreaProvider>
        <StatusBar style="light" />
        <Stack
          screenOptions={{
            headerShown: false,
            contentStyle: { backgroundColor: tt.bg },
            animation: 'slide_from_right',
          }}
        >
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="welcome" options={{ animation: 'fade' }} />
          <Stack.Screen name="sign-in" options={{ animation: 'fade' }} />
          <Stack.Screen name="trails" />
          <Stack.Screen name="trail-detail" />
          <Stack.Screen name="plan-route" />
          <Stack.Screen name="achievements" />
          <Stack.Screen name="forecast" />
          <Stack.Screen name="safety" />
          <Stack.Screen name="sos" />
          <Stack.Screen name="notifications" />
          <Stack.Screen name="search" />
          <Stack.Screen name="edit-profile" />
          <Stack.Screen name="settings" />
          <Stack.Screen name="history" />
          <Stack.Screen name="stats" />
        </Stack>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
