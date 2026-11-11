module ApiErrors

using HTTP
using JSON3
using ..ApiI18n

export ApiException, json_response, json_ok, json_error, parse_json_body, require_nonempty_str

"""
    ApiException{D} <: Exception

Structured HTTP API error carrying status code, machine-readable `code`, localized
`message`, and optional validation `details`.
"""
struct ApiException{D} <: Exception
    status::Int
    code::String
    message::String
    details::D
end

function ApiException(status::Integer, code::AbstractString, message::AbstractString)
    return ApiException{Nothing}(Int(status), String(code), String(message), nothing)
end

function ApiException(status::Integer, code::AbstractString, message::AbstractString, details)
    return ApiException{typeof(details)}(Int(status), String(code), String(message), details)
end

"""
    json_response(status::Integer, body; headers = Pair{String, String}[]) -> HTTP.Response

Serialize `body` to JSON with UTF-8 headers.
"""
function json_response(
    status::Integer,
    body;
    headers::AbstractVector{<:Pair} = Pair{String, String}[],
)
    hdrs = Pair{String, String}["Content-Type" => "application/json; charset=utf-8"]
    for (k, v) in headers
        push!(hdrs, String(k) => String(v))
    end
    return HTTP.Response(Int(status), hdrs, JSON3.write(body))
end

"""
    json_ok(data; status = 200) -> HTTP.Response

Wrap `data` in the standard `{"data": ...}` success envelope.
"""
json_ok(data; status::Integer = 200) = json_response(status, Dict("data" => data))

"""
    json_error(status::Integer, code::AbstractString, message::AbstractString; details = nothing, headers = Pair{String, String}[]) -> HTTP.Response

Serialize a structured API error envelope.
"""
function json_error(
    status::Integer,
    code::AbstractString,
    message::AbstractString;
    details = nothing,
    headers::AbstractVector{<:Pair} = Pair{String, String}[],
)
    code_str = String(code)
    err_obj = Dict{String, Any}("code" => code_str, "message" => String(message))
    if code_str == "validation_failed" && details !== nothing
        err_obj["details"] = details
    end
    return json_response(status, Dict("error" => err_obj); headers=headers)
end

function parse_json_body(req::HTTP.Request)::Dict{String, Any}
    raw = String(req.body)
    if isempty(strip(raw))
        throw(ApiException(400, "invalid_json", amsg("invalid_json")))
    end
    parsed = try
        JSON3.read(raw, Dict{String, Any})
    catch
        throw(ApiException(400, "invalid_json", amsg("malformed_json")))
    end
    parsed isa Dict || throw(ApiException(400, "invalid_json", amsg("invalid_json")))
    return parsed
end

function require_nonempty_str(
    body::AbstractDict,
    field::AbstractString;
    max_len::Integer = 512,
)::String
    f = String(field)
    if !haskey(body, f) || !(body[f] isa AbstractString)
        throw(ApiException(422, "validation_failed", amsg("validation_failed"), Dict(f => amsg("field_string"))))
    end
    val = strip(String(body[f]))
    if isempty(val) || length(val) > max_len
        throw(
            ApiException(
                422,
                "validation_failed",
                amsg("validation_failed"),
                Dict(f => amsg("field_len", "max" => max_len)),
            ),
        )
    end
    return String(val)
end

end
