module RunnerI18n

export normalize_locale, with_locale, current_locale, rmsg

function normalize_locale(raw)::String
    s = lowercase(strip(string(raw === nothing ? "" : raw)))
    startswith(s, "es") && return "es"
    return "en"
end

current_locale()::String = get(task_local_storage(), :garden_locale, "en")

function with_locale(f, locale::AbstractString)
    norm = normalize_locale(locale)
    return task_local_storage(f, :garden_locale, norm)
end

const MESSAGES = Dict{String, Dict{String, String}}(
    "en" => Dict(
        "timeout_msg" => "Execution exceeded time limit",
        "max_events_msg" => "Execution exceeded maximum event limit",
        "max_events_count" => "Execution exceeded maximum trace events ({max})",
        "syntax_fallback" => "Syntax error",
        "syntax_near_line" => "Check syntax near line {line}.",
        "forbidden_symbol" => "Restricted symbol '{sym}' is not allowed in the sandbox",
        "forbidden_import" => "External package imports ('using'/'import') are disabled in the sandbox",
        "forbidden_macro" => "Restricted macro '{mac}' is not allowed in the sandbox",
        "forbidden_module" => "Module declarations are not allowed in the sandbox",
        "empty_payload" => "Empty request payload",
        "empty_payload_hint" => "Send a valid JSON payload to stdin.",
        "malformed_json" => "Malformed JSON request: {err}",
        "malformed_json_hint" => "Verify JSON request encoding.",
        "syntax_hint" => "Check parentheses, quotes, and 'end' keywords.",
        "timeout_hint" => "Check for infinite loops or reduce input size.",
        "limit_hint" => "Reduce the number of operations or array/grid size.",
        "contract_hint" => "Review the required function signature and allowed GardenRunner APIs.",
        "bounds_hint" => "An index was outside valid bounds. Remember Julia arrays and grids are 1-indexed.",
        "undef_hint" => "A variable or function name is undefined. Check spelling and scope.",
        "method_hint" => "Function called with incompatible argument types.",
        "generic_hint" => "Inspect the error message and trace line number.",
        "values_array" => "'params.values' must be an array of integers",
        "values_empty" => "'params.values' must not be empty",
        "values_too_long" => "'params.values' length must be <= 500",
        "size_range" => "'params.size' must be between 2 and 500",
        "unsupported_dist" => "Unsupported sorting distribution '{dist}'",
        "coord_format" => "Coordinate '{label}' must be [row, col]",
        "grid_dims" => "Grid dimensions must be between 2x2 and 60x60",
        "weight_entry" => "Weight entry must be [row, col, cost]",
        "weight_positive" => "Cell weight must be positive",
        "missing_fn" => "Missing required function '{sig}'",
        "find_path_return" => "'find_path(grid)' must return a Vector of (row, col) tuples",
        "unknown_garden" => "Unknown garden '{garden}'",
        "grid_min_dims" => "Grid dimensions must be at least 2x2",
        "start_goal_wall" => "Start and goal cells cannot be walls",
        "coord_oob" => "Coordinate {label} = ({r}, {c}) is out of bounds for ({rows}, {cols})",
        "target_blocked" => "Target cell {cell} is blocked or out of bounds",
        "cell_oob" => "Cell {cell} is out of bounds",
        "path_blocked" => "Path contains blocked or out-of-bounds cell {cell}",
        "path_not_contiguous" => "Path is not contiguous between {prev} and {cell}",
        "pq_empty" => "Cannot dequeue from empty MinPriorityQueue",
        "invalid_range" => "Invalid range [{lo}, {hi}]: lower bound exceeds upper bound",
        "sort_pass" => "Sorted output matches expected order.",
        "sort_fail" => "Expected {expected}, got {actual}.",
        "path_unreachable_ok" => "Correctly reported unreachable goal.",
        "path_unreachable_fail" => "Expected empty path for unreachable goal.",
        "path_endpoints" => "Path must start at {start} and end at {goal}.",
        "path_cost" => "Expected optimal path cost {expected}, got {actual}.",
        "path_valid" => "Valid path found.",
        "cellular_dims" => "Cellular grid dimensions must be between 2x2 and 48x48",
        "cellular_matrix_size" => "Cellular grid matrix dimensions must match rows x cols",
        "cellular_gens_fail" => "Expected at least {expected} recorded generations, got {actual}.",
        "cellular_cells_fail" => "Final cellular state does not match expected pattern.",
        "cellular_valid" => "Cellular evolution matches expected generations and pattern.",
        "graph_min_nodes" => "Graph must contain at least 2 vertices",
        "graph_vertex_oob" => "Vertex {v} is out of bounds for this graph",
        "graph_path_fail" => "Expected vertex path {expected}, got {actual}.",
        "graph_mst_fail" => "Expected MST total weight {expected}, got {actual}.",
        "graph_comp_fail" => "Connected component assignments do not match expected clusters.",
        "graph_valid" => "Graph analysis matches expected output.",
        "fractal_bounds" => "Fractal bounds must satisfy x_max > x_min and y_max > y_min",
        "fractal_row_oob" => "Fractal row {row} is out of bounds for height {height}",
        "fractal_row_width" => "Fractal scanline length must equal width ({width}), got {got}",
        "fractal_segment_shape" => "Each fractal segment must provide [x1, y1, x2, y2]",
        "fractal_verify_fail" => "Fractal output failed expected pixel/segment verification.",
        "fractal_valid" => "Fractal computation matches expected escape/geometry checks.",
        "evolution_genome_len" => "Genome length must equal {expected}, got {got}",
        "evolution_empty_pop" => "Population passed to record_generation! must not be empty",
        "evolution_fitness_mismatch" => "Population length and fitness vector length must match",
        "evolution_verify_fail" => "Expected best fitness >= {expected}, got {actual}.",
        "evolution_valid" => "Evolutionary run reached target fitness convergence.",
    ),
    "es" => Dict(
        "timeout_msg" => "La ejecución superó el tiempo límite",
        "max_events_msg" => "La ejecución superó el límite máximo de eventos",
        "max_events_count" => "La ejecución superó el límite máximo de eventos ({max})",
        "syntax_fallback" => "Error de sintaxis",
        "syntax_near_line" => "Revisa la sintaxis cerca de la línea {line}.",
        "forbidden_symbol" => "El símbolo restringido '{sym}' no está permitido en el sandbox",
        "forbidden_import" => "La importación de paquetes externos ('using'/'import') está deshabilitada en el sandbox",
        "forbidden_macro" => "La macro restringida '{mac}' no está permitida en el sandbox",
        "forbidden_module" => "Las declaraciones de módulos no están permitidas en el sandbox",
        "empty_payload" => "La solicitud está vacía",
        "empty_payload_hint" => "Envía un objeto JSON válido por stdin.",
        "malformed_json" => "JSON de solicitud inválido: {err}",
        "malformed_json_hint" => "Verifica la codificación del JSON enviado.",
        "syntax_hint" => "Revisa paréntesis, comillas y palabras clave 'end'.",
        "timeout_hint" => "Verifica si hay bucles infinitos o reduce el tamaño de entrada.",
        "limit_hint" => "Reduce la cantidad de operaciones o el tamaño del arreglo/grid.",
        "contract_hint" => "Revisa la firma de función requerida y las funciones permitidas de GardenRunner.",
        "bounds_hint" => "Un índice salió de los límites válidos. Recuerda que en Julia los índices inician en 1.",
        "undef_hint" => "Una variable o función no está definida. Verifica escritura y alcance.",
        "method_hint" => "Función llamada con tipos de argumentos incompatibles.",
        "generic_hint" => "Inspecciona el mensaje de error y el número de línea indicado.",
        "values_array" => "'params.values' debe ser un arreglo de enteros",
        "values_empty" => "'params.values' no debe estar vacío",
        "values_too_long" => "La longitud de 'params.values' debe ser <= 500",
        "size_range" => "'params.size' debe estar entre 2 y 500",
        "unsupported_dist" => "Distribución de ordenamiento no soportada '{dist}'",
        "coord_format" => "La coordenada '{label}' debe tener formato [fila, columna]",
        "grid_dims" => "Las dimensiones del grid deben estar entre 2x2 y 60x60",
        "weight_entry" => "Cada entrada de peso debe tener formato [fila, columna, costo]",
        "weight_positive" => "El peso de la celda debe ser positivo",
        "missing_fn" => "Falta la función requerida '{sig}'",
        "find_path_return" => "'find_path(grid)' debe devolver un Vector de tuplas (fila, columna)",
        "unknown_garden" => "Jardín desconocido '{garden}'",
        "grid_min_dims" => "Las dimensiones del grid deben ser al menos 2x2",
        "start_goal_wall" => "Las celdas de inicio y meta no pueden ser muros",
        "coord_oob" => "La coordenada {label} = ({r}, {c}) está fuera de rango para ({rows}, {cols})",
        "target_blocked" => "La celda destino {cell} está bloqueada o fuera de rango",
        "cell_oob" => "La celda {cell} está fuera de rango",
        "path_blocked" => "El camino contiene una celda bloqueada o fuera de rango {cell}",
        "path_not_contiguous" => "El camino no es contiguo entre {prev} y {cell}",
        "pq_empty" => "No se puede desencolar de una MinPriorityQueue vacía",
        "invalid_range" => "Rango inválido [{lo}, {hi}]: el límite inferior excede el superior",
        "sort_pass" => "La salida ordenada coincide con el orden esperado.",
        "sort_fail" => "Se esperaba {expected}, se obtuvo {actual}.",
        "path_unreachable_ok" => "Se reportó correctamente la meta inalcanzable.",
        "path_unreachable_fail" => "Se esperaba un camino vacío para una meta inalcanzable.",
        "path_endpoints" => "El camino debe iniciar en {start} y terminar en {goal}.",
        "path_cost" => "Se esperaba costo óptimo {expected}, se obtuvo {actual}.",
        "path_valid" => "Camino válido encontrado.",
        "cellular_dims" => "Las dimensiones de la grilla celular deben estar entre 2x2 y 48x48",
        "cellular_matrix_size" => "La matriz celular debe coincidir con filas x columnas",
        "cellular_gens_fail" => "Se esperaban al menos {expected} generaciones registradas, se obtuvieron {actual}.",
        "cellular_cells_fail" => "El estado celular final no coincide con el patrón esperado.",
        "cellular_valid" => "La evolución celular coincide con las generaciones y el patrón esperados.",
        "graph_min_nodes" => "El grafo debe contener al menos 2 vértices",
        "graph_vertex_oob" => "El vértice {v} está fuera de rango para este grafo",
        "graph_path_fail" => "Se esperaba el recorrido de vértices {expected}, se obtuvo {actual}.",
        "graph_mst_fail" => "Se esperaba peso total del MST {expected}, se obtuvo {actual}.",
        "graph_comp_fail" => "Las componentes conexas asignadas no coinciden con los grupos esperados.",
        "graph_valid" => "El análisis de grafo coincide con el resultado esperado.",
        "fractal_bounds" => "Los límites del plano fractal deben cumplir x_max > x_min e y_max > y_min",
        "fractal_row_oob" => "La fila fractal {row} está fuera de rango para altura {height}",
        "fractal_row_width" => "La longitud de la fila fractal debe igualar el ancho ({width}), se recibió {got}",
        "fractal_segment_shape" => "Cada segmento fractal debe proveer [x1, y1, x2, y2]",
        "fractal_verify_fail" => "La salida fractal no superó las verificaciones de píxeles/segmentos.",
        "fractal_valid" => "El cálculo fractal coincide con las cotas de escape/geometría esperadas.",
        "evolution_genome_len" => "La longitud del genoma debe ser {expected}, se recibió {got}",
        "evolution_empty_pop" => "La población enviada a record_population! no debe estar vacía",
        "evolution_fitness_mismatch" => "La longitud de población y fitness debe coincidir",
        "evolution_verify_fail" => "Se esperaba mejor fitness >= {expected}, se obtuvo {actual}.",
        "evolution_valid" => "La corrida evolutiva alcanzó la convergencia esperada.",
    ),
)

"""
    rmsg(key, vars...; locale=current_locale()) -> String

Resolve and interpolate a localized diagnostic message for `GardenRunner`.
"""
function rmsg(key::AbstractString, vars::Pair...; locale::AbstractString = current_locale())::String
    loc = normalize_locale(locale)
    table = get(MESSAGES, loc, MESSAGES["en"])
    template = get(table, key, get(MESSAGES["en"], key, key))
    for (k, v) in vars
        template = replace(template, "{$(k)}" => string(v))
    end
    return template
end

end
