# kiwi_reader_t: if buf is NULL return the byte length of document idx, else copy it into buf. Returning 0 ends input.
# kiwi_reader_t: buf가 NULL이면 idx번째 문서의 바이트 길이를, 아니면 buf에 복사. 0을 돌려주면 끝.
function read_text(idx::Cint, buf::Ptr{UInt8}, ud::Ptr{Cvoid})::Cint
    texts = unsafe_pointer_to_objref(ud)::Vector{String}
    idx >= length(texts) && return 0
    s = texts[idx+1]
    buf == C_NULL || unsafe_copyto!(buf, pointer(s), ncodeunits(s))
    ncodeunits(s)
end

"""
    extract_words(texts; min_cnt=10, max_word_len=10, min_score=0.25, pos_threshold=-3.0,
                  model=default_model())

Unsupervised extraction of out-of-vocabulary word candidates (e.g. neologisms) from the
corpus `texts`. Returns `(form, score, freq, pos_score)` NamedTuples sorted by score;
`pos_score` indicates how likely the word is a noun. Results can be passed to
`Kiwi(user_words=...)`.

말뭉치 `texts`에서 사전에 없는 단어(신조어) 후보를 비지도 방식으로 추출한다.
`(form, score, freq, pos_score)` NamedTuple 목록을 점수 순으로 돌려준다.
`pos_score`는 명사일 가능성을 나타낸다. 결과는 `Kiwi(user_words=...)`에 넣어 쓸 수 있다.
"""
function extract_words(texts; min_cnt::Integer=10, max_word_len::Integer=10, min_score::Real=0.25,
                       pos_threshold::Real=-3.0, model=default_model())
    docs = String[String(t) for t in texts if !isempty(t)]  # length 0 means end of input to Kiwi / 길이 0은 Kiwi에서 입력 끝을 뜻한다
    reader = @cfunction(read_text, Cint, (Cint, Ptr{UInt8}, Ptr{Cvoid}))
    b = builder(model, 1)  # ponytail: 1 thread so the callback runs only on the calling thread / 콜백을 호출 스레드에서만 부르므로 1스레드
    try
        ws = GC.@preserve docs check(ccall((:kiwi_builder_extract_words, libkiwi), Ptr{Cvoid},
                                           (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Cint, Cint, Cfloat, Cfloat),
                                           b, reader, pointer_from_objref(docs), min_cnt, max_word_len, min_score, pos_threshold))
        try
            map(0:check(ccall((:kiwi_ws_size, libkiwi), Cint, (Ptr{Cvoid},), ws))-1) do i
                (form = unsafe_string(ccall((:kiwi_ws_form, libkiwi), Cstring, (Ptr{Cvoid}, Cint), ws, i)),
                 score = ccall((:kiwi_ws_score, libkiwi), Cfloat, (Ptr{Cvoid}, Cint), ws, i),
                 freq = Int(ccall((:kiwi_ws_freq, libkiwi), Cint, (Ptr{Cvoid}, Cint), ws, i)),
                 pos_score = ccall((:kiwi_ws_pos_score, libkiwi), Cfloat, (Ptr{Cvoid}, Cint), ws, i))
            end
        finally
            ccall((:kiwi_ws_close, libkiwi), Cint, (Ptr{Cvoid},), ws)
        end
    finally
        close_builder(b)
    end
end
