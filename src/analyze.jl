"""
    Token(form, tag, span)

형태소 하나. `form`은 형태, `tag`는 세종 품사 태그, `span`은 원문에서의 바이트 인덱스 범위로
`text[t.span]`이 해당 표층형을 돌려준다. 축약(예: "했" → 하/VV + 었/EP)에서는
여러 형태소가 같은 `span`을 공유할 수 있다.
"""
struct Token
    form::String
    tag::String
    span::UnitRange{Int}
end
Base.show(io::IO, t::Token) = print(io, t.form, "/", t.tag)

const PREDICATE_TAGS = ("VV", "VA", "VX", "VCP", "VCN")

"""
    lemma(t::Token) -> String

용언(동사 VV, 형용사 VA, 보조용언 VX, 지정사 VCP·VCN)이면 어간에 "다"를 붙인 기본형을,
아니면 형태를 그대로 돌려준다. Kiwi가 불규칙 활용 어간을 이미 복원하므로("걸어" → 걷/VV-I)
"다"만 붙이면 된다.
"""
lemma(t::Token) = any(p -> startswith(t.tag, p), PREDICATE_TAGS) ? t.form * "다" : t.form

# UTF-16 오프셋 u(0부터)에 대응하는 바이트 인덱스: m[u+1]. 끝은 ncodeunits(s)+1.
function utf16_byte_map(s::String)
    m = Int[]
    for i in eachindex(s)
        push!(m, i)
        c = s[i]
        isvalid(c) && codepoint(c) > 0xffff && push!(m, i)  # 서로게이트 쌍은 UTF-16 두 칸
    end
    push!(m, ncodeunits(s) + 1)
end

function byte_span(m, s, p, l)
    b = m[p+1]
    l == 0 ? (b:b-1) : (b:prevind(s, m[p+l+1]))
end

"""
    tokenize([kiwi], text) -> Vector{Token}

`text`를 형태소 분석해 최상위 결과를 반환한다. `kiwi`를 생략하면 기본 분석기를 쓴다.
"""
function tokenize(k::Kiwi, text::AbstractString)
    s = String(text)
    r = check(ccall((:kiwi_analyze, libkiwi), Ptr{Cvoid}, (Ptr{Cvoid}, Cstring, Cint, AnalyzeOption, Ptr{Cvoid}),
                    k.ptr, s, 1, k.option, C_NULL))
    try
        n = check(ccall((:kiwi_res_word_num, libkiwi), Cint, (Ptr{Cvoid}, Cint), r, 0))
        m = utf16_byte_map(s)
        map(0:n-1) do i
            # 형태소 위치는 UTF-8 API에서도 UTF-16 단위다
            p = ccall((:kiwi_res_position, libkiwi), Cint, (Ptr{Cvoid}, Cint, Cint), r, 0, i)
            l = ccall((:kiwi_res_length, libkiwi), Cint, (Ptr{Cvoid}, Cint, Cint), r, 0, i)
            Token(unsafe_string(ccall((:kiwi_res_form, libkiwi), Cstring, (Ptr{Cvoid}, Cint, Cint), r, 0, i)),
                  unsafe_string(ccall((:kiwi_res_tag, libkiwi), Cstring, (Ptr{Cvoid}, Cint, Cint), r, 0, i)),
                  byte_span(m, s, p, l))
        end
    finally
        ccall((:kiwi_res_close, libkiwi), Cint, (Ptr{Cvoid},), r)
    end
end

# tags: 남길 품사 태그의 접두어 목록. ("NN",)은 NNG·NNP·NNB를, ("VV",)는 VV·VV-I·VV-R를 남긴다.
keep(t::Token, tags) = tags === nothing || any(p -> startswith(t.tag, p), tags)

"""
    morphs([kiwi], text; tags=nothing, lemma=false) -> Vector{String}

형태소 문자열 목록. `tags`(태그 접두어 목록)를 주면 해당 품사만 남긴다.
`lemma=true`면 용언을 기본형("좋" → "좋다")으로 돌려준다.
"""
morphs(k::Kiwi, text::AbstractString; tags=nothing, lemma::Bool=false) =
    [lemma ? KiwiKorean.lemma(t) : t.form for t in tokenize(k, text) if keep(t, tags)]

"""
    pos([kiwi], text; tags=nothing, lemma=false) -> Vector{Tuple{String,String}}

`(형태, 품사)` 튜플 목록.
"""
pos(k::Kiwi, text::AbstractString; tags=nothing, lemma::Bool=false) =
    [(lemma ? KiwiKorean.lemma(t) : t.form, t.tag) for t in tokenize(k, text) if keep(t, tags)]

"""
    nouns([kiwi], text) -> Vector{String}

일반명사(NNG)와 고유명사(NNP).
"""
nouns(k::Kiwi, text::AbstractString) = morphs(k, text; tags=("NNG", "NNP"))

"""
    split_sentences([kiwi], text) -> Vector{String}

문장 단위로 분리한다.
"""
function split_sentences(k::Kiwi, text::AbstractString)
    s = String(text)
    ss = check(ccall((:kiwi_split_into_sents, libkiwi), Ptr{Cvoid}, (Ptr{Cvoid}, Cstring, Cint, Ptr{Cvoid}),
                     k.ptr, s, MATCH_DEFAULT, C_NULL))
    try
        n = check(ccall((:kiwi_ss_size, libkiwi), Cint, (Ptr{Cvoid},), ss))
        map(0:n-1) do i
            # 문장 위치는 UTF-8 API에서 바이트 오프셋 (형태소 위치와 단위가 다름)
            b = ccall((:kiwi_ss_begin_position, libkiwi), Cint, (Ptr{Cvoid}, Cint), ss, i)
            e = ccall((:kiwi_ss_end_position, libkiwi), Cint, (Ptr{Cvoid}, Cint), ss, i)
            String(codeunits(s)[b+1:e])
        end
    finally
        ccall((:kiwi_ss_close, libkiwi), Cint, (Ptr{Cvoid},), ss)
    end
end

"""
    space([kiwi], text; reset=false) -> String

띄어쓰기를 교정한다. `reset=true`면 이미 띄어 쓴 부분을 붙이는 교정도 한다.
"""
function space(k::Kiwi, text::AbstractString; reset::Bool=false)
    p = check(ccall((:kiwi_space, libkiwi), Ptr{UInt8}, (Ptr{Cvoid}, Cstring, Cint), k.ptr, text, reset))
    try
        unsafe_string(p)
    finally
        ccall((:kiwi_free_string, libkiwi), Cint, (Ptr{UInt8},), p)
    end
end

for f in (:tokenize, :morphs, :pos, :nouns, :split_sentences, :space)
    @eval $f(text::AbstractString; kw...) = $f(default_kiwi(), text; kw...)
end
