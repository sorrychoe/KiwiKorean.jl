# KiwiKorean.jl

[한국어](README.ko.md) | English

Korean morphological analysis for Julia, calling the [Kiwi](https://github.com/bab2min/Kiwi) C API directly via `ccall`. No Python or Java required.

## Installation

```julia
using Pkg
Pkg.add("KiwiKorean")  # also downloads the Kiwi model (~90 MB)
```

The Kiwi library comes from [Kiwi_jll](https://github.com/JuliaBinaryWrappers/Kiwi_jll.jl), built by [Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil/tree/master/K/Kiwi) for Linux (glibc and musl), macOS, Windows and FreeBSD. Requires Julia 1.10 or later.

To use your own build of Kiwi instead, point Kiwi_jll at it and restart Julia:

```julia
using Preferences, Kiwi_jll
set_preferences!(Kiwi_jll, "libkiwi_path" => "/path/to/libkiwi.so")
```

## Usage

```julia
using KiwiKorean

tokenize("오늘 날씨가 좋네요")   # [오늘/NNG, 날씨/NNG, 가/JKS, 좋/VA, 네요/EF]
morphs("오늘 날씨가 좋네요")     # ["오늘", "날씨", "가", "좋", "네요"]
pos("오늘 날씨가 좋네요")        # [("오늘", "NNG"), ("날씨", "NNG"), ...]
nouns("오늘 날씨가 좋네요")      # ["오늘", "날씨"]  (NNG, NNP)

morphs(text; tags=("NN", "VV", "VA"))  # keep only these tag prefixes

split_sentences("안녕하세요. 반갑습니다!")  # ["안녕하세요.", "반갑습니다!"]
space("아버지가방에들어가신다")           # "아버지가 방에 들어가신다"
```

Without a `Kiwi` argument, a default analyzer is created on first use and reused. Pass your own `Kiwi` as the first argument to use custom settings: `nouns(k, text)`.

### Lemmas (dictionary forms)

Predicates (VV, VA, VX, VCP, VCN) get "다" appended to their stem. Kiwi already restores irregular stems.

```julia
morphs("걸어서 갔다"; lemma=true)   # ["걷다", "어서", "가다", "었", "다"]
lemma(tokenize("좋네요")[1])        # "좋다"
```

### Character positions

Each `Token` has a `span` of byte indices into the original text, so `text[t.span]` returns its surface form. Contracted morphemes share a span (갔 → 가/VV + 었/EP).

```julia
t = "학교에 갔다"
[(x.form, t[x.span]) for x in tokenize(t)]
# [("학교", "학교"), ("에", "에"), ("가", "갔"), ("었", "갔"), ("다", "다")]
```

### User dictionary

```julia
k = Kiwi(user_words=["뉴진스님" => "NNP"], user_dict="my_dict.txt")  # file: word<TAB>tag<TAB>score
nouns(k, "뉴진스님이 왔다")  # ["뉴진스님"]
```

### Typo correction

```julia
k = Kiwi(typos=:basic_continual_lengthening)
pos(k, "맛있지 않았던것 가태")  # ... ("같", "VA"), ("애", "EF")
```

Typo sets: `:basic`, `:continual`, `:basic_continual`, `:lengthening`, `:basic_continual_lengthening`, `:dialect`. Building and analysis get slower when typo correction is on.

### New word extraction

Unsupervised extraction of out-of-dictionary word candidates from a corpus. Results can be fed into the user dictionary.

```julia
cands = extract_words(texts; min_cnt=10, min_score=0.25)
# [(form = "...", score = ..., freq = ..., pos_score = ...), ...]
k = Kiwi(user_words=[w.form => "NNP" for w in cands if w.pos_score > 0])
```

### Stopwords

The package does not ship a stopword list; define one for your corpus and filter the tokens:

```julia
stopwords = Set(["것", "수", "등", "때"])  # your own list
filter(∉(stopwords), nouns(text))
```

`Languages.jl` also has a Korean list (`stopwords(Languages.Korean())`), but it mixes in punctuation and multi-word entries, so review it before use.

## With TextAnalysis.jl

```julia
using TextAnalysis
crps = Corpus([TokenDocument(nouns(t)) for t in texts])
update_lexicon!(crps)
m = DocumentTermMatrix(crps)
tf_idf(m)
```

Avoid TextAnalysis's `prepare!(doc, strip_stopwords)` and `stem!` on Korean text: filter stopwords at the token level and use `lemma=true` instead.

## License

MIT (see [LICENSE](LICENSE)). Kiwi (v0.25.0), its library from Kiwi_jll and the model downloaded at install time, is Apache-2.0.
