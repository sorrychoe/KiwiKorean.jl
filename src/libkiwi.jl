# Path of libkiwi, copied from Kiwi_jll at load time (Kiwi_jll fills it in its own __init__).
# Kiwi_jll defines it only on the platforms it is built for; elsewhere `builder` reports that.
# libkiwi 경로. Kiwi_jll이 자체 __init__에서 채운 값을 로드 시점에 가져온다.
# Kiwi_jll은 빌드된 플랫폼에서만 이를 정의하며, 그 밖의 플랫폼에서는 `builder`가 알려 준다.
libkiwi::String = ""
__init__() = isdefined(Kiwi_jll, :libkiwi) && (global libkiwi = Kiwi_jll.libkiwi)

default_model() = joinpath(artifact"kiwi_model", "models", "cong", "base")

function kiwi_error()
    p = ccall((:kiwi_error, libkiwi), Ptr{UInt8}, ())
    msg = p == C_NULL ? "unknown error / 알 수 없는 오류" : unsafe_string(p)
    ccall((:kiwi_clear_error, libkiwi), Cvoid, ())
    error("Kiwi: ", msg)
end
check(p::Ptr) = p == C_NULL ? kiwi_error() : p
check(r::Integer) = r < 0 ? kiwi_error() : r

# Same memory layout as kiwi_analyze_option_t in capi.h.
# capi.h의 kiwi_analyze_option_t와 같은 메모리 배치
struct AnalyzeOption
    match_options::Cint
    blocklist::Ptr{Cvoid}
    open_ending::Cint
    allowed_dialects::Cint
    dialect_cost::Cfloat
    typo_transformer::Ptr{Cvoid}
    typo_threshold::Cfloat
end

const BUILD_DEFAULT = Cint(15)
# KIWI_MATCH_ALL_WITH_NORMALIZING: URL|EMAIL|HASHTAG|MENTION|SERIAL|EMOJI|Z_CODA|NORMALIZE_CODA
const MATCH_DEFAULT = Cint(0x3f | 1 << 23 | 1 << 16)

# KIWI_TYPO_* enum values.
# KIWI_TYPO_* 열거형
const TYPO_SETS = Dict(:basic => 1, :continual => 2, :basic_continual => 3, :lengthening => 4,
                       :basic_continual_lengthening => 5, :dialect => 6)

function builder(model, num_threads)
    Kiwi_jll.is_available() ||
        error("Kiwi_jll is not available on this platform ($(Sys.MACHINE)). / " *
              "이 플랫폼($(Sys.MACHINE))에서는 Kiwi_jll을 쓸 수 없습니다.")
    check(ccall((:kiwi_builder_init, libkiwi), Ptr{Cvoid}, (Cstring, Cint, Cint, Cint),
                model, num_threads, BUILD_DEFAULT, 0))
end
close_builder(b) = ccall((:kiwi_builder_close, libkiwi), Cint, (Ptr{Cvoid},), b)
