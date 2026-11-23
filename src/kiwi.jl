"""
    Kiwi(; user_words=(), user_dict=nothing, typos=:none, typo_cost_threshold=2.5,
           model=default_model(), num_threads=-1)

Create a Kiwi morphological analyzer.

- `user_words`: user words, as `word => tag` pairs, e.g. `"챗GPT" => "NNP"`.
- `user_dict`: path to a Kiwi user dictionary file (one `word<TAB>tag<TAB>score` per line).
- `typos`: typo correction set. `:none` (default), `:basic`, `:continual` (liaison),
  `:basic_continual`, `:lengthening` (vowel lengthening), `:basic_continual_lengthening`,
  `:dialect`. Enabling correction slows down both construction and analysis.
- `typo_cost_threshold`: only typos whose cost is at most this value are considered.
- `model`: path to the Kiwi model directory; defaults to the bundled base model.
- `num_threads`: number of worker threads; `-1` lets Kiwi choose.

Kiwi 형태소 분석기를 만든다.

- `user_words`: 사용자 단어. `"챗GPT" => "NNP"` 형태의 Pair 목록.
- `user_dict`: Kiwi 사용자 사전 파일 경로 (한 줄에 `단어<TAB>품사<TAB>점수`).
- `typos`: 오타 교정. `:none`(기본), `:basic`, `:continual`(연철), `:basic_continual`,
  `:lengthening`(장음화), `:basic_continual_lengthening`, `:dialect`.
  교정을 켜면 분석기 생성과 분석이 느려진다.
- `typo_cost_threshold`: 이 비용 이하의 오타만 고려한다.
"""
mutable struct Kiwi
    ptr::Ptr{Cvoid}
    typo::Ptr{Cvoid}         # kiwi_prepared_typo_h; C_NULL without typo correction / 오타 교정을 안 쓰면 C_NULL
    option::AnalyzeOption
    function Kiwi(; user_words=(), user_dict=nothing, typos::Symbol=:none, typo_cost_threshold::Real=2.5,
                  model=default_model(), num_threads=-1)
        typos === :none || haskey(TYPO_SETS, typos) ||
            throw(ArgumentError("unknown typos: $typos. Valid values: :none, $(join(keys(TYPO_SETS), ", "))"))
        b = builder(model, num_threads)
        try
            for (word, tag) in user_words
                check(ccall((:kiwi_builder_add_word, libkiwi), Cint, (Ptr{Cvoid}, Cstring, Cstring, Cfloat),
                            b, word, tag, 0f0))
            end
            user_dict === nothing ||
                check(ccall((:kiwi_builder_load_dict, libkiwi), Cint, (Ptr{Cvoid}, Cstring), b, user_dict))
            # Typo correctors are passed via the analyze options, not at build time: passing one at
            # build time crashed in v0.24 and is deprecated since v0.25.
            # 오타 교정기는 빌드 시가 아니라 분석 옵션으로 넘긴다. 빌드 시 전달은 v0.24에서 크래시가 났고
            # v0.25부터 지원 종료 예정이다.
            ptr = check(ccall((:kiwi_builder_build, libkiwi), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Cfloat),
                              b, C_NULL, 0f0))
            typo = if typos === :none
                C_NULL
            else
                # Handles from kiwi_typo_get_default are built-in objects; do not free them.
                # kiwi_typo_get_default의 핸들은 내장 객체라 해제하지 않는다
                t = check(ccall((:kiwi_typo_get_default, libkiwi), Ptr{Cvoid}, (Cint,), TYPO_SETS[typos]))
                check(ccall((:kiwi_typo_prepare, libkiwi), Ptr{Cvoid}, (Ptr{Cvoid},), t))
            end
            opt = AnalyzeOption(MATCH_DEFAULT, C_NULL, 0, 0, 3f0, typo, typo_cost_threshold)
            k = new(ptr, typo, opt)
            finalizer(k) do k
                k.ptr == C_NULL || ccall((:kiwi_close, libkiwi), Cint, (Ptr{Cvoid},), k.ptr)
                k.typo == C_NULL || ccall((:kiwi_prepared_typo_close, libkiwi), Cint, (Ptr{Cvoid},), k.typo)
                k.ptr = k.typo = C_NULL
            end
        finally
            close_builder(b)
        end
    end
end

Base.show(io::IO, ::Kiwi) = print(io, "Kiwi(", unsafe_string(ccall((:kiwi_version, libkiwi), Cstring, ())), ")")

const DEFAULT_KIWI = Ref{Kiwi}()
const DEFAULT_LOCK = ReentrantLock()
default_kiwi() = lock(() -> isassigned(DEFAULT_KIWI) ? DEFAULT_KIWI[] : (DEFAULT_KIWI[] = Kiwi()), DEFAULT_LOCK)
