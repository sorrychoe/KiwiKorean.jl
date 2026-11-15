"""
    KiwiKorean

Kiwi(https://github.com/bab2min/Kiwi) C API를 `ccall`로 호출하는 한국어 형태소 분석 패키지.
"""
module KiwiKorean

using Artifacts

export Kiwi, Token, tokenize, morphs, pos, nouns, lemma, split_sentences, space, extract_words

include("libkiwi.jl")   # 라이브러리·모델 로딩, 오류 처리, C 구조체와 상수
include("kiwi.jl")      # Kiwi 분석기 생성과 기본 분석기
include("analyze.jl")   # 형태소 분석, 기본형, 문장 분리, 띄어쓰기
include("extract.jl")   # 신조어 추출

end # module
