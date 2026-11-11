module GardenJSON

export parse_json, to_json

function parse_json(input::AbstractString)::Any
    bytes = Vector{UInt8}(codeunits(String(input)))
    pos = skip_ws(bytes, 1)
    if pos > length(bytes)
        throw(ArgumentError("Empty JSON input"))
    end
    val, next_pos = parse_value(bytes, pos)
    end_pos = skip_ws(bytes, next_pos)
    if end_pos <= length(bytes)
        throw(ArgumentError("Unexpected trailing characters in JSON at byte $end_pos"))
    end
    return val
end

function skip_ws(bytes::Vector{UInt8}, pos::Int)::Int
    n = length(bytes)
    while pos <= n
        b = bytes[pos]
        if b == 0x20 || b == 0x09 || b == 0x0a || b == 0x0d
            pos += 1
        else
            break
        end
    end
    return pos
end

function parse_value(bytes::Vector{UInt8}, pos::Int)::Tuple{Any, Int}
    pos > length(bytes) && throw(ArgumentError("Unexpected end of JSON input"))
    b = bytes[pos]
    if b == 0x7b # '{'
        return parse_object(bytes, pos)
    elseif b == 0x5b # '['
        return parse_array(bytes, pos)
    elseif b == 0x22 # '"'
        return parse_string(bytes, pos)
    elseif b == 0x74 # 't'
        return parse_literal(bytes, pos, "true", true)
    elseif b == 0x66 # 'f'
        return parse_literal(bytes, pos, "false", false)
    elseif b == 0x6e # 'n'
        return parse_literal(bytes, pos, "null", nothing)
    elseif b == 0x2d || (0x30 <= b <= 0x39)
        return parse_number(bytes, pos)
    else
        throw(ArgumentError("Unexpected byte 0x$(string(b, base=16)) at position $pos"))
    end
end

function parse_literal(bytes::Vector{UInt8}, pos::Int, lit::String, val::Any)::Tuple{Any, Int}
    lit_bytes = codeunits(lit)
    end_pos = pos + length(lit_bytes) - 1
    if end_pos > length(bytes)
        throw(ArgumentError("Truncated literal '$lit' at position $pos"))
    end
    for i in eachindex(lit_bytes)
        if bytes[pos + i - 1] != lit_bytes[i]
            throw(ArgumentError("Invalid literal at position $pos"))
        end
    end
    return val, end_pos + 1
end

function parse_object(bytes::Vector{UInt8}, pos::Int)::Tuple{Dict{String, Any}, Int}
    obj = Dict{String, Any}()
    pos = skip_ws(bytes, pos + 1)
    if pos <= length(bytes) && bytes[pos] == 0x7d # '}'
        return obj, pos + 1
    end
    while true
        pos > length(bytes) && throw(ArgumentError("Unterminated JSON object"))
        bytes[pos] != 0x22 && throw(ArgumentError("Expected string key at position $pos"))
        key, pos = parse_string(bytes, pos)
        pos = skip_ws(bytes, pos)
        if pos > length(bytes) || bytes[pos] != 0x3a # ':'
            throw(ArgumentError("Expected ':' after key at position $pos"))
        end
        pos = skip_ws(bytes, pos + 1)
        val, pos = parse_value(bytes, pos)
        obj[key] = val
        pos = skip_ws(bytes, pos)
        pos > length(bytes) && throw(ArgumentError("Unterminated JSON object"))
        if bytes[pos] == 0x7d # '}'
            return obj, pos + 1
        elseif bytes[pos] == 0x2c # ','
            pos = skip_ws(bytes, pos + 1)
        else
            throw(ArgumentError("Expected ',' or '}' in object at position $pos"))
        end
    end
end

function parse_array(bytes::Vector{UInt8}, pos::Int)::Tuple{Vector{Any}, Int}
    arr = Any[]
    pos = skip_ws(bytes, pos + 1)
    if pos <= length(bytes) && bytes[pos] == 0x5d # ']'
        return arr, pos + 1
    end
    while true
        val, pos = parse_value(bytes, pos)
        push!(arr, val)
        pos = skip_ws(bytes, pos)
        pos > length(bytes) && throw(ArgumentError("Unterminated JSON array"))
        if bytes[pos] == 0x5d # ']'
            return arr, pos + 1
        elseif bytes[pos] == 0x2c # ','
            pos = skip_ws(bytes, pos + 1)
        else
            throw(ArgumentError("Expected ',' or ']' in array at position $pos"))
        end
    end
end

function parse_string(bytes::Vector{UInt8}, pos::Int)::Tuple{String, Int}
    pos += 1 # skip opening '"'
    io = IOBuffer()
    n = length(bytes)
    while pos <= n
        b = bytes[pos]
        if b == 0x22 # '"'
            return String(take!(io)), pos + 1
        elseif b == 0x5c # '\'
            pos += 1
            pos > n && throw(ArgumentError("Unterminated escape sequence"))
            esc = bytes[pos]
            if esc == 0x22
                write(io, UInt8('"'))
            elseif esc == 0x5c
                write(io, UInt8('\\'))
            elseif esc == 0x2f
                write(io, UInt8('/'))
            elseif esc == 0x62
                write(io, UInt8('\b'))
            elseif esc == 0x66
                write(io, UInt8('\f'))
            elseif esc == 0x6e
                write(io, UInt8('\n'))
            elseif esc == 0x72
                write(io, UInt8('\r'))
            elseif esc == 0x74
                write(io, UInt8('\t'))
            elseif esc == 0x75 # 'u'
                pos + 4 > n && throw(ArgumentError("Incomplete unicode escape"))
                hex_str = String(bytes[(pos + 1):(pos + 4)])
                cp = parse(UInt32, hex_str; base=16)
                pos += 4
                if 0xD800 <= cp <= 0xDBFF
                    if pos + 6 <= n && bytes[pos + 1] == 0x5c && bytes[pos + 2] == 0x75
                        low_hex = String(bytes[(pos + 3):(pos + 6)])
                        low = parse(UInt32, low_hex; base=16)
                        if 0xDC00 <= low <= 0xDFFF
                            cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                            pos += 6
                        end
                    end
                end
                print(io, Char(cp))
            else
                throw(ArgumentError("Invalid escape character at position $pos"))
            end
            pos += 1
        elseif b < 0x20
            throw(ArgumentError("Unescaped control character in JSON string at position $pos"))
        else
            write(io, b)
            pos += 1
        end
    end
    throw(ArgumentError("Unterminated JSON string"))
end

function parse_number(bytes::Vector{UInt8}, pos::Int)::Tuple{Union{Int64, Float64}, Int}
    start = pos
    n = length(bytes)
    is_float = false
    if bytes[pos] == 0x2d
        pos += 1
    end
    pos > n && throw(ArgumentError("Invalid number at position $start"))
    if bytes[pos] == 0x30
        pos += 1
    elseif 0x31 <= bytes[pos] <= 0x39
        while pos <= n && 0x30 <= bytes[pos] <= 0x39
            pos += 1
        end
    else
        throw(ArgumentError("Invalid number at position $start"))
    end
    if pos <= n && bytes[pos] == 0x2e # '.'
        is_float = true
        pos += 1
        (pos > n || !(0x30 <= bytes[pos] <= 0x39)) && throw(ArgumentError("Invalid decimal in number at $start"))
        while pos <= n && 0x30 <= bytes[pos] <= 0x39
            pos += 1
        end
    end
    if pos <= n && (bytes[pos] == 0x65 || bytes[pos] == 0x45) # 'e' / 'E'
        is_float = true
        pos += 1
        if pos <= n && (bytes[pos] == 0x2b || bytes[pos] == 0x2d)
            pos += 1
        end
        (pos > n || !(0x30 <= bytes[pos] <= 0x39)) && throw(ArgumentError("Invalid exponent in number at $start"))
        while pos <= n && 0x30 <= bytes[pos] <= 0x39
            pos += 1
        end
    end
    num_str = String(bytes[start:(pos - 1)])
    if is_float
        return parse(Float64, num_str), pos
    end
    parsed = tryparse(Int64, num_str)
    return isnothing(parsed) ? parse(Float64, num_str) : parsed, pos
end

function to_json(val)::String
    io = IOBuffer()
    write_json(io, val)
    return String(take!(io))
end

write_json(io::IO, ::Nothing) = write(io, "null")
write_json(io::IO, v::Bool) = write(io, v ? "true" : "false")
write_json(io::IO, v::Integer) = print(io, Int64(v))
function write_json(io::IO, v::AbstractFloat)
    if isnan(v) || isinf(v)
        write(io, "null")
    else
        print(io, Float64(v))
    end
end
write_json(io::IO, v::Symbol) = write_json(io, String(v))

function write_json(io::IO, s::AbstractString)
    write(io, '"')
    for ch in s
        if ch == '"'
            write(io, "\\\"")
        elseif ch == '\\'
            write(io, "\\\\")
        elseif ch == '\b'
            write(io, "\\b")
        elseif ch == '\f'
            write(io, "\\f")
        elseif ch == '\n'
            write(io, "\\n")
        elseif ch == '\r'
            write(io, "\\r")
        elseif ch == '\t'
            write(io, "\\t")
        elseif UInt32(ch) < 0x20
            write(io, "\\u00", string(UInt32(ch); base=16, pad=2))
        else
            print(io, ch)
        end
    end
    write(io, '"')
end

function write_json(io::IO, arr::Union{AbstractVector, Tuple})
    write(io, '[')
    first = true
    for item in arr
        first || write(io, ',')
        first = false
        write_json(io, item)
    end
    write(io, ']')
end

function write_json(io::IO, dict::AbstractDict)
    write(io, '{')
    first = true
    for (k, v) in dict
        first || write(io, ',')
        first = false
        write_json(io, string(k))
        write(io, ':')
        write_json(io, v)
    end
    write(io, '}')
end

function write_json(io::IO, nt::NamedTuple)
    write(io, '{')
    first = true
    for (k, v) in pairs(nt)
        first || write(io, ',')
        first = false
        write_json(io, String(k))
        write(io, ':')
        write_json(io, v)
    end
    write(io, '}')
end

end

