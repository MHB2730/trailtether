// Trailtether — FormField.
//
// Labeled input used on Edit Profile and Sign In screens. The label is
// a tactical mono-caps eyebrow above the input. The input itself sits
// on a `surf` background with a single-line border that turns ember on
// focus. Optional leading icon + trailing pill.

import React, { useState } from 'react';
import {
  KeyboardTypeOptions,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  TextInputProps,
  View,
  ViewStyle,
} from 'react-native';
import { Icon, type IconName } from '@components/Icon';
import { font, fz, ls, radius, sp, tt } from '@theme/tokens';

export interface FormFieldProps {
  label: string;
  value: string;
  onChangeText: (text: string) => void;
  placeholder?: string;
  icon?: IconName;
  trailing?: React.ReactNode;
  multiline?: boolean;
  numberOfLines?: number;
  secureTextEntry?: boolean;
  keyboardType?: KeyboardTypeOptions;
  autoCapitalize?: TextInputProps['autoCapitalize'];
  editable?: boolean;
  hint?: string;
  style?: ViewStyle;
  onPress?: () => void; // for "tap to open picker" fields
}

export function FormField({
  label,
  value,
  onChangeText,
  placeholder,
  icon,
  trailing,
  multiline = false,
  numberOfLines,
  secureTextEntry,
  keyboardType,
  autoCapitalize = 'sentences',
  editable = true,
  hint,
  style,
  onPress,
}: FormFieldProps) {
  const [focused, setFocused] = useState(false);
  const inner = (
    <View
      style={[
        styles.field,
        focused && styles.fieldFocused,
        !editable && styles.fieldReadOnly,
      ]}
    >
      {icon && (
        <View style={{ marginRight: sp.s3 }}>
          <Icon name={icon} size={14} color={focused ? tt.ember : tt.text3} />
        </View>
      )}
      <TextInput
        value={value}
        onChangeText={onChangeText}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        placeholder={placeholder}
        placeholderTextColor={tt.text3}
        multiline={multiline}
        numberOfLines={numberOfLines}
        secureTextEntry={secureTextEntry}
        keyboardType={keyboardType}
        autoCapitalize={autoCapitalize}
        editable={editable && !onPress}
        pointerEvents={onPress ? 'none' : 'auto'}
        style={[
          styles.input,
          multiline && { textAlignVertical: 'top', minHeight: 90 },
        ]}
        underlineColorAndroid="transparent"
        selectionColor={tt.ember}
      />
      {trailing}
    </View>
  );

  return (
    <View style={[{ marginBottom: sp.s6 }, style]}>
      <Text style={styles.label}>{label}</Text>
      {onPress ? (
        <Pressable onPress={onPress} style={({ pressed }) => pressed && { opacity: 0.85 }}>
          {inner}
        </Pressable>
      ) : (
        inner
      )}
      {hint && <Text style={styles.hint}>{hint}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  label: {
    fontFamily: font.uiBold,
    fontSize: fz.micro,
    color: tt.text3,
    letterSpacing: ls.monoWide * fz.micro,
    textTransform: 'uppercase',
    marginBottom: sp.s2,
  },
  field: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: tt.surf,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: tt.line2,
    paddingHorizontal: sp.s6,
    paddingVertical: sp.s4,
    minHeight: 46,
  },
  fieldFocused: {
    borderColor: tt.ember,
    backgroundColor: tt.surf2,
  },
  fieldReadOnly: {
    opacity: 0.85,
  },
  input: {
    flex: 1,
    fontFamily: font.uiSemi,
    fontSize: fz.body2,
    color: tt.text,
    paddingVertical: 0,
    paddingHorizontal: 0,
  },
  hint: {
    marginTop: sp.s2,
    fontFamily: font.uiMed,
    fontSize: fz.caption,
    color: tt.text3,
  },
});
