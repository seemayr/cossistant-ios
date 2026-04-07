## Localization

The SDK uses an internal system called "RString" to localize using non-hardcoded strings.
All keys from Localizable.xcstrings are referenced as RString enum cases (in R.swift).
They can be accessed throughout the SDK using `R.string(.keyValue, someParam1, someParam2, ...)`

Localize user-facing strings (used in views, alerts, labels, ...).
There's no need to localize strings that are just used for debugging purposes (print statements, logging, ...).

The SDK supports the following languages:
- English (en)
- German (de)
- Spanish (es)
- French (fr)
- Italian (it)

When adding new localization strings, always add translations for ALL supported languages.
Take into consideration placeholders like `%@` etc, if they are used.

### Translation Tone

Strings should feel clear, natural, and approachable — like the kind of language you'd find in an Apple product. Not corporate-stiff, not overly casual. Think helpful, warm, and human.

- Write the way you'd explain something to a friend — polite but not formal.
- Avoid jargon, technical terms, or overly verbose phrasing.
- Keep it concise. If a shorter sentence says the same thing, use it.

Cultural awareness checks:
- Does the translation handle pop-culture phrases appropriately?
- Are English terms kept when they're commonly used in the target language (e.g. "Chat", "Feedback")?
- Does it avoid literal translations of idioms that lose meaning?
- What sounds most natural to a native speaker of the target language?

Penalize translations that:
- Translate widely-understood English terms literally when the English term is standard
- Sound overly formal, bureaucratic, or robotic
- Use slang or colloquialisms that feel forced
- Lose the friendly, approachable tone of the original

### Length Check

Try to match the length of the original (English) version so that layouts don't shift too much when switching languages.
Depending on where a string is used, longer text can cause layout issues (oversized buttons, unintended line breaks, overflows).
Always understand where and how a localization is used before translating.

Example:
A short label like "Send" is used in a compact chat input button.
Avoid unnecessarily long translations like "Nachricht absenden" (German) since it takes much more horizontal space.
A shorter translation like "Senden" matches the original length better and still follows all rules above.

### Structure of Localizable.xcstrings

The Localizable.xcstrings file is a JSON file with the following structure:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "key_name" : {
      "comment" : "Short sentence explaining the context/usage of this string.",
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Deutscher Text"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "English text"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Texto en español"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Texte en français"
          }
        },
        "it" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Testo in italiano"
          }
        }
      }
    }
  }
}
```

Key points:
- Each string key must have translations for ALL supported languages
- `extractionState` should be set to `"manual"`
- `state` in stringUnit should be `"translated"`
- Parameter placeholders: use `%@` for all placeholders
- Multiple parameters use positional formatting: `%1$@`, `%2$@`, etc.
- Add a short `comment` to every key explaining context/usage — it should help translate to new languages without checking the code first

### Localization Key Naming

**Important:** When choosing a key name, pick one that clearly describes WHERE or HOW the string is used (not WHAT it says).

For example, a label shown when the AI agent is processing a response:
- Good: `ai_phase_thinking`
- Bad: `the_agent_is_thinking`

For very common, simple terms that are reused throughout the SDK ("close", "retry", "send", ...) it's fine to use general key names. Reuse these across the SDK instead of creating a dedicated RString entry for every occurrence.
For specific texts appearing only at certain points, follow the naming guide above.

### Adding New Localization Strings

To add a new localized string, follow these steps:

**Step 1: Add to Localizable.xcstrings**

Add your new key within the `strings` object with all supported languages:

```json
"rating_prompt" : {
  "comment" : "Prompt asking the user to rate the conversation after it's resolved.",
  "extractionState" : "manual",
  "localizations" : {
    "de" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Wie war dein Erlebnis?"
      }
    },
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "How was your experience?"
      }
    },
    "es" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "¿Cómo fue tu experiencia?"
      }
    },
    "fr" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Comment était votre expérience ?"
      }
    },
    "it" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Com'è stata la tua esperienza?"
      }
    }
  }
}
```

**Step 2: Add to R.swift**

Add the corresponding enum case to the RString enum in R.swift:

```swift
enum RString: String, CaseIterable {
    // ... existing cases ...
    case rating_prompt
    // ... more cases ...
}
```

**Step 3: Use in SwiftUI code**

```swift
// Simple string without parameters
Text(R.string(.rating_prompt))

// String with single parameter
Text(R.string(.typing_indicator, agentName))

// String with multiple parameters
Text(R.string(.attachment_error_too_large, fileName, maxSize))
```
