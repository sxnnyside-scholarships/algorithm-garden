module Security

using Dates
using HTTP
using Random
using SHA

export hash_password,
    verify_password,
    generate_bearer_token,
    hash_token,
    extract_bearer_token,
    constant_time_equal,
    RateLimiter,
    check_rate_limit!,
    client_key

function constant_time_equal(a::AbstractVector{UInt8}, b::AbstractVector{UInt8})::Bool
    length(a) == length(b) || return false
    diff::UInt8 = 0x00
    @inbounds for (ai, bi) in zip(a, b)
        diff |= xor(ai, bi)
    end
    return diff == 0x00
end

# PBKDF2-HMAC-SHA256 (NIST SP 800-132) with OS CSPRNG salt
function _pbkdf2_hmac_sha256(
    password::AbstractVector{UInt8},
    salt::AbstractVector{UInt8},
    iterations::Integer,
    dk_len::Integer = 32,
)::Vector{UInt8}
    pw = Vector{UInt8}(password)
    salt_vec = Vector{UInt8}(salt)
    blocks = cld(Int(dk_len), 32)
    out = UInt8[]
    sizehint!(out, blocks * 32)
    for block_idx in 1:blocks
        be_block = UInt8[
            UInt8((block_idx >> 24) & 0xff),
            UInt8((block_idx >> 16) & 0xff),
            UInt8((block_idx >> 8) & 0xff),
            UInt8(block_idx & 0xff),
        ]
        u = SHA.hmac_sha256(pw, vcat(salt_vec, be_block))
        t = copy(u)
        for _ in 2:Int(iterations)
            u = SHA.hmac_sha256(pw, u)
            @inbounds for j in eachindex(t)
                t[j] = xor(t[j], u[j])
            end
        end
        append!(out, t)
    end
    return out[1:Int(dk_len)]
end

function hash_password(password::AbstractString, iterations::Integer)::String
    salt = rand(RandomDevice(), UInt8, 16)
    dk = _pbkdf2_hmac_sha256(Vector{UInt8}(codeunits(String(password))), salt, iterations, 32)
    return "pbkdf2_sha256\$$(iterations)\$$(bytes2hex(salt))\$$(bytes2hex(dk))"
end

function verify_password(password::AbstractString, stored::AbstractString)::Bool
    parts = split(stored, '$')
    length(parts) == 4 || return false
    parts[1] == "pbkdf2_sha256" || return false
    iterations = tryparse(Int, parts[2])
    (iterations === nothing || iterations < 10_000) && return false
    salt = try
        hex2bytes(String(parts[3]))
    catch
        return false
    end
    expected = try
        hex2bytes(String(parts[4]))
    catch
        return false
    end
    actual = _pbkdf2_hmac_sha256(Vector{UInt8}(codeunits(String(password))), salt, iterations, length(expected))
    return constant_time_equal(actual, expected)
end

function generate_bearer_token()::String
    raw = rand(RandomDevice(), UInt8, 32)
    return "ag_" * bytes2hex(raw)
end

function hash_token(token::AbstractString, secret::AbstractVector{UInt8})::String
    digest = SHA.hmac_sha256(Vector{UInt8}(secret), Vector{UInt8}(codeunits(String(token))))
    return bytes2hex(digest)
end

function extract_bearer_token(req::HTTP.Request)::Union{Nothing, String}
    auth = HTTP.header(req, "Authorization", "")
    isempty(auth) && return nothing
    parts = split(strip(auth), ' '; limit=2)
    length(parts) == 2 || return nothing
    lowercase(parts[1]) == "bearer" || return nothing
    tok = strip(parts[2])
    return isempty(tok) ? nothing : String(tok)
end

mutable struct RateBucket
    count::Int
    window_start::Float64
end

struct RateLimiter
    lock::ReentrantLock
    buckets::Dict{String, RateBucket}
end

RateLimiter() = RateLimiter(ReentrantLock(), Dict{String, RateBucket}())

function check_rate_limit!(
    limiter::RateLimiter,
    key::String;
    limit::Int,
    window_seconds::Int,
)::Tuple{Bool, Int}
    now_s = time()
    lock(limiter.lock) do
        b = get(limiter.buckets, key, nothing)
        if b === nothing || (now_s - b.window_start) >= window_seconds
            limiter.buckets[key] = RateBucket(1, now_s)
            return true, 0
        elseif b.count < limit
            b.count += 1
            return true, 0
        else
            retry_after = max(1, ceil(Int, window_seconds - (now_s - b.window_start)))
            return false, retry_after
        end
    end
end

function client_key(req::HTTP.Request)::String
    fwd = HTTP.header(req, "X-Forwarded-For", "")
    if !isempty(fwd)
        return strip(split(fwd, ',')[1])
    end
    real_ip = HTTP.header(req, "X-Real-IP", "")
    return isempty(real_ip) ? "local" : strip(real_ip)
end

end

