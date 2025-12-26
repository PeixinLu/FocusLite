# App Search Matching Specification

## Goals
- Provide high-quality fuzzy matching for macOS app names.
- Cover English, Chinese, pinyin (full and initials), English acronym, and mixed queries.
- Produce explainable ranking with a debug score breakdown.
- Avoid main-thread I/O or heavy recomputation.

## Scope
- Applies to the app name matching used by AppSearchProvider.
- Query and app names are treated as user-facing strings (not bundle IDs).
- Pinyin strategy defaults to **Plan A** (alias table), with **Plan B** available.

## Plan A (Default, No Dependencies)
### Pinyin Strategy
- Use a built-in alias table for common apps (e.g., 微信, 支付宝, QQ音乐, 网易云音乐).
- Support user-defined aliases stored in a JSON file:
  - Path: `~/Library/Application Support/FocusLite/aliases.json`
  - Schema: `{ "aliases": { "微信": ["weixin", "wx"] } }`
- For names not in alias lists, no pinyin is generated.

### Tradeoffs
- Pros: zero dependencies, fast, predictable.
- Cons: limited coverage beyond known aliases.

## Plan B (Optional, Small Dependency)
### Pinyin Strategy
- Use the built-in `CFStringTransform` to generate pinyin full + initials for all Chinese names.
- Prefer alias table if provided; fall back to system pinyin conversion.

### Tradeoffs
- Pros: broad coverage without external dependency.
- Cons: relies on system transform; may not match brand-specific pronunciations.

## Normalization
### Query Normalization
- Lowercase.
- Fold width and diacritics.
- Remove punctuation and whitespace, but **retain Chinese characters**.
- Convert full-width to half-width.
- Example:
  - "Visual Studio" -> "visualstudio"
  - "微信" -> "微信"

### Name Normalization
- Same rules as query normalization.
- Keep original name for display and tie-breaks.

## Tokenization
- Split by whitespace, punctuation, and symbol boundaries.
- Split camelCase and PascalCase into tokens.
- Example:
  - "VisualStudioCode" -> ["visual", "studio", "code"]
  - "Adobe Photoshop" -> ["adobe", "photoshop"]
- For Chinese strings, tokens remain as the full name.

## Acronym Strategy
- English acronym: take the first letter of each English token.
  - "Visual Studio Code" -> "vsc"
- Chinese acronym (Plan A):
  - From alias list only.

## Match Types and Scores
Scoring is deterministic and explained in MatchDebug.

1) Exact match (normalized equality)
   - Score: 1.00
2) Prefix match (name starts with query)
   - Score: 0.95
3) Substring match (continuous)
   - Score: 0.90
4) Token match (all tokens covered)
   - Score: 0.88
5) Acronym match (English initials)
   - Score: 0.86
6) Pinyin full match (alias)
   - Score: 0.85
7) Pinyin initials match (alias)
   - Score: 0.83
8) Fuzzy subsequence match
   - Score: 0.60 ~ 0.84

### Fuzzy Subsequence Scoring
- Higher score if:
  - Matched characters are closer (smaller gaps).
  - Match starts earlier.
  - More consecutive matches.
  - Match ratio is higher.

### Mixed Query Support
- Query can contain multiple tokens (e.g., "wx weixin").
- At least one token must match; multiple token hits add a bonus.

## Tie-break Rules (Deterministic)
1) Higher score
2) Shorter app name length
3) Alphabetical by original name (localized compare)

## Debug Output
Each match generates a `MatchDebug` entry:
- `types`: [MatchType]
- `scoreBreakdown`: [(MatchType, score)]
- `positions`: [Int] (indices of match)
- `normalizedQuery`, `normalizedName`

Debug output is **only printed in DEBUG builds**.

## Performance Constraints
- App index building and alias loading must be off the main thread.
- Cached name index fields are stored on disk.
- Matching runs in-memory without I/O.
