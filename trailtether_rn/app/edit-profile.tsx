// Trailtether — Edit Profile.
//
// Reads the current `ProfileRow` from the auth store, hydrates the
// form, and on save calls supabase `profiles.update`. All editable
// design fields now persist (BLOCKERS #19 resolved): display_name,
// username, region, bio, experience_level, interests, plus the two
// emergency contact fields. Avatar upload still pending — it needs a
// storage bucket policy + picker.

import React, { useEffect, useMemo, useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { ScreenShell } from '@components/primitives/ScreenShell';
import { TTAppBar, IconBtn } from '@components/primitives/TTAppBar';
import { FormField } from '@components/design/FormField';
import { ErrorState } from '@components/primitives/States';
import { Icon } from '@components/Icon';
import { useAuth } from '@/store/auth';
import { supabase } from '@/data/supabase';
import { initialsFromName, colorForUid } from '@/data/adapters';
import { font, fz, ls, radius, shadow, sp, tt } from '@theme/tokens';

function capitalise(s: string): string {
  return s.length === 0 ? s : s[0]!.toUpperCase() + s.slice(1);
}

export default function EditProfileScreen() {
  const router = useRouter();
  const profile = useAuth((s) => s.profile);
  const userId = useAuth((s) => s.user?.id);
  const refreshProfile = useAuth((s) => s.refreshProfile);

  const [displayName, setDisplayName] = useState(profile?.display_name ?? '');
  const [username, setUsername] = useState(profile?.username ?? '');
  const [region, setRegion] = useState(profile?.region ?? '');
  const [bio, setBio] = useState(profile?.bio ?? '');
  const [experience, setExperience] = useState<
    'beginner' | 'intermediate' | 'advanced' | 'expert' | ''
  >(profile?.experience_level ?? '');
  const [interestsText, setInterestsText] = useState(
    (profile?.interests ?? []).join(', '),
  );
  const [emergencyEmail, setEmergencyEmail] = useState(
    profile?.emergency_contact_email ?? '',
  );
  const [emergencyPhone, setEmergencyPhone] = useState(
    profile?.emergency_contact_phone ?? '',
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showExperiencePicker, setShowExperiencePicker] = useState(false);

  // Re-hydrate fields when the profile resolves (first paint usually
  // arrives before the auth store has a value).
  useEffect(() => {
    if (!profile) return;
    setDisplayName(profile.display_name ?? '');
    setUsername(profile.username ?? '');
    setRegion(profile.region ?? '');
    setBio(profile.bio ?? '');
    setExperience(profile.experience_level ?? '');
    setInterestsText((profile.interests ?? []).join(', '));
    setEmergencyEmail(profile.emergency_contact_email ?? '');
    setEmergencyPhone(profile.emergency_contact_phone ?? '');
  }, [profile]);

  const avatar = useMemo(() => {
    const name = displayName.trim() || profile?.username || 'Hiker';
    return {
      initials: initialsFromName(name),
      color: colorForUid(userId ?? name),
    };
  }, [displayName, profile?.username, userId]);

  const save = async () => {
    if (!userId) return;
    setSaving(true);
    setError(null);
    try {
      const interests = interestsText
        .split(',')
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
      const { error: err } = await supabase
        .from('profiles')
        .update({
          display_name: displayName.trim() || null,
          username: username.trim() || null,
          region: region.trim() || null,
          bio: bio.trim() || null,
          experience_level: experience || null,
          interests: interests.length > 0 ? interests : null,
          emergency_contact_email: emergencyEmail.trim() || null,
          emergency_contact_phone: emergencyPhone.trim() || null,
        })
        .eq('id', userId);
      if (err) throw err;
      await refreshProfile();
      router.back();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  };

  return (
    <ScreenShell scroll={false}>
      <TTAppBar
        big
        title="Edit Profile"
        sub="HIKER · TETHER · CONTACT"
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={
          <IconBtn
            name="check"
            color={tt.ember}
            onPress={() => void save()}
          />
        }
      />
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={{ flex: 1 }}
      >
        <ScrollView
          contentContainerStyle={styles.body}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.avatarRow}>
            <View style={[styles.avatar, { backgroundColor: avatar.color }]}>
              <Text style={styles.avatarText}>{avatar.initials}</Text>
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.avatarLabel}>HIKER AVATAR</Text>
              <Text style={styles.avatarSub}>Photo upload pending</Text>
              <Pressable
                onPress={() => {}}
                style={({ pressed }) => [
                  styles.avatarBtn,
                  pressed && { opacity: 0.85 },
                ]}
              >
                <Icon name="user" size={11} color={tt.ember} />
                <Text style={styles.avatarBtnText}>CHANGE</Text>
              </Pressable>
            </View>
          </View>

          <FormField
            label="Display name"
            icon="user"
            value={displayName}
            onChangeText={setDisplayName}
            placeholder="Matthew B."
          />
          <FormField
            label="Username"
            icon="user"
            value={username}
            onChangeText={setUsername}
            placeholder="matthew_b"
            autoCapitalize="none"
          />
          <FormField
            label="Region"
            icon="pin"
            value={region}
            onChangeText={setRegion}
            placeholder="Drakensberg"
          />
          <FormField
            label="Bio"
            icon="user"
            value={bio}
            onChangeText={setBio}
            placeholder="Multi-day routes, caves, and dawn summits."
            multiline
            numberOfLines={3}
          />
          <FormField
            label="Experience level"
            icon="flame"
            value={experience ? capitalise(experience) : ''}
            onChangeText={() => {}}
            placeholder="Choose"
            onPress={() => setShowExperiencePicker((v) => !v)}
          />
          {showExperiencePicker && (
            <View style={styles.expPicker}>
              {(['beginner', 'intermediate', 'advanced', 'expert'] as const).map((lvl) => (
                <Pressable
                  key={lvl}
                  onPress={() => {
                    setExperience(lvl);
                    setShowExperiencePicker(false);
                  }}
                  style={({ pressed }) => [
                    styles.expRow,
                    pressed && { backgroundColor: tt.surf2 },
                    experience === lvl && { backgroundColor: tt.emberDim },
                  ]}
                >
                  <Text
                    style={[
                      styles.expRowText,
                      experience === lvl && { color: tt.ember },
                    ]}
                  >
                    {capitalise(lvl)}
                  </Text>
                </Pressable>
              ))}
            </View>
          )}
          <FormField
            label="Interests"
            icon="route"
            value={interestsText}
            onChangeText={setInterestsText}
            placeholder="caving, summit, trail-run"
            autoCapitalize="none"
            hint="Comma-separated tags."
          />
          <FormField
            label="Emergency contact · email"
            icon="phone"
            value={emergencyEmail}
            onChangeText={setEmergencyEmail}
            placeholder="someone@example.com"
            keyboardType="email-address"
            autoCapitalize="none"
          />
          <FormField
            label="Emergency contact · phone"
            icon="phone"
            value={emergencyPhone}
            onChangeText={setEmergencyPhone}
            placeholder="+27…"
            keyboardType="phone-pad"
          />

          {error && <ErrorState error={error} />}

          <Pressable
            onPress={() => void save()}
            disabled={saving}
            style={({ pressed }) => [
              styles.cta,
              saving && { opacity: 0.6 },
              pressed && { opacity: 0.9 },
            ]}
          >
            <Text style={styles.ctaText}>{saving ? 'SAVING…' : 'SAVE CHANGES'}</Text>
            <Icon name="check" size={16} color="#1a0d04" strokeWidth={2.6} />
          </Pressable>
        </ScrollView>
      </KeyboardAvoidingView>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { padding: sp.screen, paddingBottom: sp.s11 },
  avatarRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s7,
    marginBottom: sp.s9,
    padding: sp.s7,
    backgroundColor: tt.surf,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: tt.line,
  },
  avatar: {
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    fontFamily: font.uiHeavy,
    fontSize: 22,
    color: '#1a0d04',
    letterSpacing: ls.tight * 22,
  },
  avatarLabel: {
    fontFamily: font.uiBold,
    fontSize: fz.micro,
    color: tt.text3,
    letterSpacing: ls.monoWide * fz.micro,
  },
  avatarSub: {
    marginTop: 4,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text2,
  },
  avatarBtn: {
    marginTop: sp.s3,
    alignSelf: 'flex-start',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 5,
    paddingHorizontal: sp.s4,
    borderRadius: radius.sm,
    backgroundColor: tt.emberDim,
    borderWidth: 1,
    borderColor: 'rgba(255,106,44,0.45)',
  },
  avatarBtnText: {
    fontFamily: font.monoBold,
    fontSize: 10,
    color: tt.ember,
    letterSpacing: ls.monoWide * 10,
  },
  cta: {
    marginTop: sp.s8,
    height: 54,
    borderRadius: 14,
    backgroundColor: tt.ember,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    ...shadow.ember,
  },
  ctaText: {
    fontFamily: font.uiHeavy,
    fontSize: fz.body2,
    letterSpacing: ls.monoWide * fz.body2,
    color: '#1a0d04',
  },
  expPicker: {
    marginTop: -sp.s4,
    marginBottom: sp.s6,
    backgroundColor: tt.surf,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: tt.line2,
    overflow: 'hidden',
  },
  expRow: {
    paddingVertical: sp.s5,
    paddingHorizontal: sp.s6,
    borderBottomWidth: 1,
    borderBottomColor: tt.line,
  },
  expRowText: {
    fontFamily: font.uiBold,
    fontSize: fz.body2,
    color: tt.text,
  },
});
