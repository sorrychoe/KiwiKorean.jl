const ARTIFACTS_TOML = joinpath(@__DIR__, "..", "Artifacts.toml")

# Set in __init__. Can be overridden with ENV["KIWI_LIB"] (for platforms without an artifact, e.g. Windows).
# __init__에서 설정. ENV["KIWI_LIB"]로 덮어쓸 수 있다 (Windows 등 아티팩트가 없는 플랫폼용).
libkiwi::String = ""

function artifact_dir(name)
    h = artifact_hash(name, ARTIFACTS_TOML)
    h === nothing && error("이 플랫폼용 Kiwi 아티팩트($name)가 없습니다. " *
                           "Kiwi 릴리스를 직접 받아 ENV[\"KIWI_LIB\"]에 libkiwi 경로를 지정하세요.")
    path = artifact_path(h)
    isdir(path) || error("Kiwi 아티팩트($name)가 설치되지 않았습니다. `using Pkg; Pkg.instantiate()`를 실행하세요.")
    path
end

function __init__()
    global libkiwi = get(ENV, "KIWI_LIB", "")
    if isempty(libkiwi) && artifact_hash("kiwi_lib", ARTIFACTS_TOML) !== nothing
        libkiwi = joinpath(artifact_dir("kiwi_lib"), "lib", Sys.isapple() ? "libkiwi.dylib" : "libkiwi.so")
    end
end

default_model() = joinpath(artifact_dir("kiwi_model"), "models", "cong", "base")

function kiwi_error()
    p = ccall((:kiwi_error, libkiwi), Ptr{UInt8}, ())
    msg = p == C_NULL ? "알 수 없는 오류" : unsafe_string(p)
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

builder(model, num_threads) =
    check(ccall((:kiwi_builder_init, libkiwi), Ptr{Cvoid}, (Cstring, Cint, Cint, Cint),
                model, num_threads, BUILD_DEFAULT, 0))
close_builder(b) = ccall((:kiwi_builder_close, libkiwi), Cint, (Ptr{Cvoid},), b)
