# KiwiKorean.jl

한국어 | [English](README.md)

[Kiwi](https://github.com/bab2min/Kiwi) 한국어 형태소 분석기를 C API(`ccall`)로 직접 호출하는 Julia 패키지입니다.

## 설치

```julia
using Pkg
Pkg.add("KiwiKorean")  # 설치 시 Kiwi 모델(약 90MB)도 받는다
```

Kiwi 라이브러리는 [Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil/tree/master/K/Kiwi)이 빌드한 [Kiwi_jll](https://github.com/JuliaBinaryWrappers/Kiwi_jll.jl)을 통해 Kiwi를 다운받습니다. Linux(glibc, musl), macOS, Windows, FreeBSD를 지원하며 Julia 1.10 이상이 필요합니다.

직접 빌드한 Kiwi를 사용하길 희망하신다면, Kiwi_jll에 경로를 지정하고 Julia를 다시 시작하면 됩니다.

```julia
using Preferences, Kiwi_jll
set_preferences!(Kiwi_jll, "libkiwi_path" => "/path/to/libkiwi.so")
```

## 사용법

```julia
using KiwiKorean

tokenize("오늘 날씨가 좋네요")   # [오늘/NNG, 날씨/NNG, 가/JKS, 좋/VA, 네요/EF]
morphs("오늘 날씨가 좋네요")     # ["오늘", "날씨", "가", "좋", "네요"]
pos("오늘 날씨가 좋네요")        # [("오늘", "NNG"), ("날씨", "NNG"), ...]
nouns("오늘 날씨가 좋네요")      # ["오늘", "날씨"]  (NNG, NNP)

morphs(text; tags=("NN", "VV", "VA"))  # 품사 태그 접두어로 거르기

split_sentences("안녕하세요. 반갑습니다!")  # ["안녕하세요.", "반갑습니다!"]
space("아버지가방에들어가신다")           # "아버지가 방에 들어가신다"
```

`Kiwi` 인자를 생략하면 처음 호출할 때 기본 분석기를 만들어 계속 쓰게 됩니다. 설정을 바꾸려면 직접 만든 `Kiwi`를 첫 인자로 넘기면 됩니다: `nouns(k, text)`.

### 용언 기본형 복원

용언(VV, VA, VX, VCP, VCN)은 어간에 "다"를 붙여 기본형으로 반환합니다. 불규칙 활용 어간은 Kiwi가 복원합니다.

```julia
morphs("걸어서 갔다"; lemma=true)   # ["걷다", "어서", "가다", "었", "다"]
lemma(tokenize("좋네요")[1])        # "좋다"
```

### 형태소 위치

각 `Token`의 `span`은 원문의 바이트 인덱스 범위라서 `text[t.span]`이 표층형을 돌려줍니다. 축약된 형태소는 같은 범위를 공유합니다(갔 → 가/VV + 었/EP).

```julia
t = "학교에 갔다"
[(x.form, t[x.span]) for x in tokenize(t)]
# [("학교", "학교"), ("에", "에"), ("가", "갔"), ("었", "갔"), ("다", "다")]
```

### 사용자 사전

```julia
k = Kiwi(user_words=["뉴진스님" => "NNP"], user_dict="my_dict.txt")  # 파일: 단어<TAB>품사<TAB>점수
nouns(k, "뉴진스님이 왔다")  # ["뉴진스님"]
```

### 오타 교정

```julia
k = Kiwi(typos=:basic_continual_lengthening)
pos(k, "맛있지 않았던것 가태")  # ... ("같", "VA"), ("애", "EF")
```

오타 집합: `:basic`, `:continual`(연철), `:basic_continual`, `:lengthening`(장음화), `:basic_continual_lengthening`, `:dialect`. 오타 교정을 켜면 분석기 생성과 분석이 느려질 수 있습니다.

### 신조어 추출

말뭉치에서 사전에 없는 단어 후보를 비지도 방식으로 추출합니다. 결과를 사용자 사전에 넣을 수 있습니다.

```julia
cands = extract_words(texts; min_cnt=10, min_score=0.25)
# [(form = "...", score = ..., freq = ..., pos_score = ...), ...]
k = Kiwi(user_words=[w.form => "NNP" for w in cands if w.pos_score > 0])
```

### 불용어

패키지에는 불용어 목록이 없습니다. 분석할 말뭉치에 맞게 직접 정의해 토큰을 거를 수 있습니다.

```julia
stopwords = Set(["것", "수", "등", "때"])  # 직접 정한 목록
filter(∉(stopwords), nouns(text))
```

`Languages.jl`에도 한국어 목록(`stopwords(Languages.Korean())`)이 있지만 문장부호와 여러 단어로 된 항목이 섞여 있으니 검토한 뒤 사용합니다.

## TextAnalysis.jl과 함께 쓰기

```julia
using TextAnalysis
crps = Corpus([TokenDocument(nouns(t)) for t in texts])
update_lexicon!(crps)
m = DocumentTermMatrix(crps)
tf_idf(m)
```

한국어 텍스트에는 TextAnalysis의 `prepare!(doc, strip_stopwords)`와 `stem!`을 쓰지 않습니다. 불용어는 토큰 단위로 거르고, 어간 추출 대신 `lemma=true`를 사용합니다.

## 라이선스

MIT ([LICENSE](LICENSE) 참고). Kiwi(v0.25.0)는 Kiwi_jll의 라이브러리와 설치 시 내려받는 모델 모두 Apache-2.0입니다.
