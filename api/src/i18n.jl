module ApiI18n

using HTTP

export normalize_locale, request_locale, with_api_locale, current_api_locale, amsg

function normalize_locale(raw)::String
    s = lowercase(strip(string(raw === nothing ? "" : raw)))
    startswith(s, "es") && return "es"
    return "en"
end

current_api_locale()::String = get(task_local_storage(), :garden_api_locale, "en")

function with_api_locale(f, locale::AbstractString)
    norm = normalize_locale(locale)
    return task_local_storage(f, :garden_api_locale, norm)
end

function request_locale(req::HTTP.Request)::String
    qp = HTTP.queryparams(HTTP.URI(req.target))
    if haskey(qp, "locale") && !isempty(strip(qp["locale"]))
        return normalize_locale(qp["locale"])
    end
    hdr = HTTP.header(req, "Accept-Language", "")
    isempty(hdr) || return normalize_locale(hdr)
    return "en"
end

const MESSAGES = Dict{String, Dict{String, String}}(
    "en" => Dict(
        "unauthorized" => "Authentication required",
        "invalid_credentials" => "Invalid email or password",
        "conflict_account" => "Email or username already exists",
        "rate_limit_auth" => "Too many authentication attempts; please retry later.",
        "rate_limit_exec" => "Execution rate limit exceeded; please retry shortly.",
        "invalid_json" => "Request body must be a JSON object",
        "malformed_json" => "Malformed JSON request body",
        "validation_failed" => "Validation failed",
        "not_found_algo" => "Algorithm '{slug}' not found",
        "not_found_exercise" => "Exercise '{id}' not found",
        "not_found_experiment" => "Experiment '{id}' not found",
        "not_found_route" => "Route '{target}' not found",
        "forbidden_experiment" => "You do not have access to this experiment",
        "runner_unavailable" => "Execution sandbox is currently unavailable",
        "runner_timeout" => "Execution timed out after {ms} ms",
        "runner_timeout_hint" => "Check for infinite loops or reduce input size.",
        "runner_stdout" => "Execution output exceeded maximum byte limit",
        "runner_stdout_hint" => "Reduce input size or trace volume.",
        "internal_error" => "Internal server error",
        "field_string" => "must be a string",
        "field_len" => "must be between 1 and {max} characters",
        "field_email" => "must be a valid email address",
        "field_username" => "must be 3-32 alphanumeric/underscore/dot/dash chars",
        "field_min_len" => "must be at least {min} characters",
        "field_max_len" => "must be at most {max} characters",
        "field_required" => "is required",
        "field_nonempty" => "must not be empty",
        "field_max_bytes" => "exceeds {max} bytes",
        "field_object" => "must be an object",
    ),
    "es" => Dict(
        "unauthorized" => "Se requiere iniciar sesión",
        "invalid_credentials" => "Correo electrónico o contraseña incorrectos",
        "conflict_account" => "El correo electrónico o nombre de usuario ya existe",
        "rate_limit_auth" => "Demasiados intentos de autenticación; inténtalo de nuevo más tarde.",
        "rate_limit_exec" => "Límite de ejecuciones excedido; espera unos segundos.",
        "invalid_json" => "El cuerpo de la solicitud debe ser un objeto JSON",
        "malformed_json" => "El JSON de la solicitud es inválido",
        "validation_failed" => "Error de validación",
        "not_found_algo" => "No se encontró el algoritmo '{slug}'",
        "not_found_exercise" => "No se encontró el ejercicio '{id}'",
        "not_found_experiment" => "No se encontró el experimento '{id}'",
        "not_found_route" => "No se encontró la ruta '{target}'",
        "forbidden_experiment" => "No tienes acceso a este experimento",
        "runner_unavailable" => "El sandbox de ejecución no está disponible en este momento",
        "runner_timeout" => "La ejecución agotó el tiempo límite después de {ms} ms",
        "runner_timeout_hint" => "Revisa si existen bucles infinitos o reduce el tamaño de entrada.",
        "runner_stdout" => "La salida de la ejecución superó el tamaño máximo permitido",
        "runner_stdout_hint" => "Reduce el tamaño de entrada o la cantidad de eventos.",
        "internal_error" => "Error interno del servidor",
        "field_string" => "debe ser una cadena de texto",
        "field_len" => "debe tener entre 1 y {max} caracteres",
        "field_email" => "debe ser un correo electrónico válido",
        "field_username" => "debe tener entre 3 y 32 caracteres alfanuméricos, _, . o -",
        "field_min_len" => "debe tener al menos {min} caracteres",
        "field_max_len" => "debe tener máximo {max} caracteres",
        "field_required" => "es obligatorio",
        "field_nonempty" => "no debe estar vacío",
        "field_max_bytes" => "excede {max} bytes",
        "field_object" => "debe ser un objeto JSON",
    ),
)

"""
    amsg(key, vars...; locale = current_api_locale()) -> String

Resolve and interpolate a localized API error or diagnostic message.
"""
function amsg(key::AbstractString, vars::Pair...; locale::AbstractString = current_api_locale())::String
    norm = normalize_locale(locale)
    table = get(MESSAGES, norm, MESSAGES["en"])
    k_str = String(key)
    template = get(table, k_str, get(MESSAGES["en"], k_str, k_str))
    for (k, v) in vars
        template = replace(template, "{$(k)}" => string(v))
    end
    return template
end

function amsg(loc::AbstractString, key::AbstractString, vars::Pair...)::String
    return amsg(key, vars...; locale=loc)
end

end
