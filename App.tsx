import { useRef, useState } from 'react';
import { SafeAreaView, StyleSheet, Text, TextInput } from 'react-native';

// The bug needs a paragraph after the one being edited.
const INITIAL_TEXT = '첫째 줄\n둘째 줄입니다\n셋째 줄입니다';
const FIRST_PARAGRAPH_END = INITIAL_TEXT.indexOf('\n');

/**
 * Multiline TextInput with later paragraphs. Focus puts the caret at the end of the first paragraph,
 * then typing Korean there (e.g. ㅎ ㅏ ㄴ → 한) shifts the whole text down by the height of the first paragraph on iOS 27.
 */
function PrefilledInput({ testID, scrollEnabled }: { testID: string; scrollEnabled: boolean }) {
  const [text, setText] = useState(INITIAL_TEXT);
  const ref = useRef<TextInput>(null);

  return (
    <TextInput
      ref={ref}
      testID={testID}
      accessibilityLabel={testID}
      style={styles.input}
      multiline
      scrollEnabled={scrollEnabled}
      value={text}
      onChangeText={setText}
      onFocus={() =>
        setTimeout(() => ref.current?.setSelection(FIRST_PARAGRAPH_END, FIRST_PARAGRAPH_END), 50)
      }
    />
  );
}

function App() {
  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.label}>multiline, scrollEnabled=false</Text>
      <PrefilledInput testID="input-noscroll" scrollEnabled={false} />
      <Text style={styles.label}>multiline, scrollEnabled=true</Text>
      <PrefilledInput testID="input-scroll" scrollEnabled />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
    backgroundColor: 'white',
  },
  label: {
    marginTop: 16,
    marginBottom: 8,
    fontSize: 13,
    color: '#666',
  },
  input: {
    minHeight: 100,
    padding: 12,
    fontSize: 17,
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 8,
  },
});

export default App;
