module CatalogSeed

export GARDENS_SEED, ALGORITHMS_SEED, EXERCISES_SEED

include("catalog_seed_phase6.jl")

const CORE_GARDENS_SEED = [
    (
        slug = "sorting",
        name = "Sorting Garden",
        description = "Explora algoritmos de ordenamiento comparativos, observa intercambios, comparaciones y subarreglos activos en tiempo real.",
        sort_order = 1,
    ),
    (
        slug = "pathfinding",
        name = "Pathfinding Garden",
        description = "Experimenta con algoritmos de búsqueda de caminos sobre grids interactivos con obstáculos, pesos y heurísticas.",
        sort_order = 2,
    ),
]

const CORE_ALGORITHMS_SEED = [
    (
        slug = "bubble-sort",
        garden_slug = "sorting",
        name = "Bubble Sort",
        summary = "Ordenamiento por burbujeo adyacente: compara e intercambia pares vecinos hasta estabilizar el arreglo.",
        difficulty = "beginner",
        concept = "Invariante por pasadas e intercambios adyacentes O(n²)",
        explanation = """
Bubble Sort recorre repetidamente el arreglo comparando elementos adyacentes e intercambiándolos cuando están fuera de orden.
En cada pasada, el elemento mayor sin ordenar "burbujea" hacia su posición definitiva al final del arreglo.
""",
        visualization_guide = "Las barras resaltadas en ámbar indican comparaciones (`compare`); los intercambios (`swap`) animan el cruce y las barras verdes señalan posiciones ya ordenadas.",
        default_params_json = """{"size":18,"distribution":"random","seed":42}""",
        reference_code = """
function sort_algorithm!(arr)
    n = length(arr)
    for i in 1:(n - 1)
        swapped = false
        mark_range!(arr, 1, n - i + 1)
        for j in 1:(n - i)
            if compare(arr, j, j + 1) > 0
                swap!(arr, j, j + 1)
                swapped = true
            end
        end
        mark_sorted!(arr, n - i + 1)
        if !swapped
            for k in 1:(n - i)
                mark_sorted!(arr, k)
            end
            break
        end
    end
    mark_sorted!(arr, 1)
end
""",
    ),
    (
        slug = "selection-sort",
        garden_slug = "sorting",
        name = "Selection Sort",
        summary = "Selecciona el mínimo del subarreglo restante en cada iteración y realiza a lo sumo un intercambio por pasada.",
        difficulty = "beginner",
        concept = "Búsqueda del mínimo y reducción lineal del subarreglo O(n²)",
        explanation = """
Selection Sort divide el arreglo en una parte ordenada a la izquierda y una sin ordenar a la derecha.
En cada paso busca el índice del elemento mínimo en el tramo sin ordenar y lo intercambia con el primer elemento de ese tramo.
""",
        visualization_guide = "El rango activo muestra el tramo pendiente, el marcador de pivote sigue al candidato mínimo actual y cada barra fijada cambia a estado ordenado.",
        default_params_json = """{"size":18,"distribution":"random","seed":7}""",
        reference_code = """
function sort_algorithm!(arr)
    n = length(arr)
    for i in 1:(n - 1)
        mark_range!(arr, i, n)
        min_idx = i
        mark_pivot!(arr, min_idx)
        for j in (i + 1):n
            if compare(arr, j, min_idx) < 0
                min_idx = j
                mark_pivot!(arr, min_idx)
            end
        end
        if min_idx != i
            swap!(arr, i, min_idx)
        end
        mark_sorted!(arr, i)
    end
    mark_sorted!(arr, n)
end
""",
    ),
    (
        slug = "insertion-sort",
        garden_slug = "sorting",
        name = "Insertion Sort",
        summary = "Construye el arreglo ordenado insertando cada nuevo elemento en su posición correcta respecto a los anteriores.",
        difficulty = "beginner",
        concept = "Inserción incremental y alta eficiencia en arreglos casi ordenados",
        explanation = """
Insertion Sort toma cada elemento a partir de la segunda posición y lo desplaza hacia la izquierda mientras sea menor que su predecesor.
Es muy eficiente en arreglos pequeños o casi ordenados, alcanzando complejidad O(n) en el mejor caso.
""",
        visualization_guide = "Observa cómo el elemento clave se desplaza mediante escrituras e intercambios sobre el prefijo ordenado.",
        default_params_json = """{"size":18,"distribution":"nearly_sorted","seed":11}""",
        reference_code = """
function sort_algorithm!(arr)
    n = length(arr)
    mark_sorted!(arr, 1)
    for i in 2:n
        mark_range!(arr, 1, i)
        j = i
        while j > 1 && compare(arr, j - 1, j) > 0
            swap!(arr, j - 1, j)
            j -= 1
        end
        mark_sorted!(arr, i)
    end
end
""",
    ),
    (
        slug = "merge-sort",
        garden_slug = "sorting",
        name = "Merge Sort",
        summary = "Divide y vencerás recursivo con complejidad garantizada O(n log n) mediante mezcla ordenada de mitades.",
        difficulty = "intermediate",
        concept = "Divide y vencerás y mezcla estable O(n log n)",
        explanation = """
Merge Sort divide recursivamente el arreglo en dos mitades hasta alcanzar subarreglos de tamaño 1, y luego los combina en orden ascendente.
""",
        visualization_guide = "Los rangos activos destacan cada subarreglo en mezcla y las escrituras reflejan la reconstrucción ordenada in-place.",
        default_params_json = """{"size":20,"distribution":"random","seed":19}""",
        reference_code = """
function merge_ranges!(arr, lo, mid, hi)
    mark_range!(arr, lo, hi)
    left = [arr[i] for i in lo:mid]
    right = [arr[j] for j in (mid + 1):hi]
    i = 1
    j = 1
    k = lo
    while i <= length(left) && j <= length(right)
        if left[i] <= right[j]
            arr[k] = left[i]
            i += 1
        else
            arr[k] = right[j]
            j += 1
        end
        k += 1
    end
    while i <= length(left)
        arr[k] = left[i]
        i += 1
        k += 1
    end
    while j <= length(right)
        arr[k] = right[j]
        j += 1
        k += 1
    end
end

function mergesort_rec!(arr, lo, hi)
    if lo >= hi
        return
    end
    mid = (lo + hi) ÷ 2
    mergesort_rec!(arr, lo, mid)
    mergesort_rec!(arr, mid + 1, hi)
    merge_ranges!(arr, lo, mid, hi)
end

function sort_algorithm!(arr)
    n = length(arr)
    mergesort_rec!(arr, 1, n)
    for i in 1:n
        mark_sorted!(arr, i)
    end
end
""",
    ),
    (
        slug = "quick-sort",
        garden_slug = "sorting",
        name = "Quick Sort",
        summary = "Particiona el arreglo alrededor de un pivote para ordenar subarreglos de forma recursiva.",
        difficulty = "intermediate",
        concept = "Partición de Lomuto/Hoare, elección de pivote y recursividad",
        explanation = """
Quick Sort selecciona un pivote, reordena los elementos menores a su izquierda y los mayores a su derecha, y aplica recursivamente el mismo proceso en cada partición.
""",
        visualization_guide = "El marcador de pivote indica el elemento de referencia actual y el rango resalta la partición en curso.",
        default_params_json = """{"size":20,"distribution":"random","seed":23}""",
        reference_code = """
function partition!(arr, lo, hi)
    mark_range!(arr, lo, hi)
    mid = (lo + hi) >>> 1
    if mid != hi
        swap!(arr, mid, hi)
    end
    mark_pivot!(arr, hi)
    i = lo - 1
    for j in lo:(hi - 1)
        if compare(arr, j, hi) <= 0
            i += 1
            if i != j
                swap!(arr, i, j)
            end
        end
    end
    swap!(arr, i + 1, hi)
    mark_sorted!(arr, i + 1)
    return i + 1
end

function quicksort_rec!(arr, lo, hi)
    if lo < hi
        p = partition!(arr, lo, hi)
        quicksort_rec!(arr, lo, p - 1)
        quicksort_rec!(arr, p + 1, hi)
    elseif lo == hi && lo >= 1 && lo <= length(arr)
        mark_sorted!(arr, lo)
    end
end

function sort_algorithm!(arr)
    quicksort_rec!(arr, 1, length(arr))
end
""",
    ),
    (
        slug = "heap-sort",
        garden_slug = "sorting",
        name = "Heap Sort",
        summary = "Construye un max-heap binario y extrae repetidamente el máximo hacia el final del arreglo.",
        difficulty = "advanced",
        concept = "Árbol binario implícito (Max-Heap) y ordenamiento in-place O(n log n)",
        explanation = """
Heap Sort organiza el arreglo como un montículo máximo (max-heap) para extraer el mayor elemento en cada paso e intercambiarlo con el final del tramo no ordenado.
""",
        visualization_guide = "El rango activo delimita el tamaño actual del heap mientras cada extracción fija el extremo derecho.",
        default_params_json = """{"size":20,"distribution":"random","seed":31}""",
        reference_code = """
function sift_down!(arr, n, root)
    largest = root
    left = 2 * root
    right = 2 * root + 1
    if left <= n && compare(arr, left, largest) > 0
        largest = left
    end
    if right <= n && compare(arr, right, largest) > 0
        largest = right
    end
    if largest != root
        swap!(arr, root, largest)
        sift_down!(arr, n, largest)
    end
end

function sort_algorithm!(arr)
    n = length(arr)
    for i in (n ÷ 2):-1:1
        sift_down!(arr, n, i)
    end
    for i in n:-1:2
        mark_range!(arr, 1, i)
        swap!(arr, 1, i)
        mark_sorted!(arr, i)
        sift_down!(arr, i - 1, 1)
    end
    mark_sorted!(arr, 1)
end
""",
    ),
    (
        slug = "bfs",
        garden_slug = "pathfinding",
        name = "Breadth-First Search (BFS)",
        summary = "Exploración por niveles con cola FIFO; garantiza el camino con menor número de pasos en grids sin pesos.",
        difficulty = "beginner",
        concept = "Exploración en anchura y distancia mínima no ponderada",
        explanation = """
BFS expande primero los nodos más cercanos al origen usando una cola FIFO.
En grids donde cada paso tiene costo uniforme, el primer momento en que alcanza el destino garantiza el camino más corto en cantidad de celdas.
""",
        visualization_guide = "Las celdas en frontera aparecen en cian, las visitadas en índigo y el camino final reconstruido en verde.",
        default_params_json = """{"rows":12,"cols":18,"start":[2,2],"goal":[11,17],"walls":[[2,6],[3,6],[4,6],[5,6],[6,6],[7,6],[8,6],[9,6],[5,11],[6,11],[7,11],[8,11],[9,11],[10,11]],"weights":[]}""",
        reference_code = """
function find_path(grid)
    s = start_node(grid)
    g = goal_node(grid)
    queue = [s]
    came_from = Dict{Tuple{Int, Int}, Tuple{Int, Int}}(s => s)
    frontier!(grid, s; cost=0.0)

    while !isempty(queue)
        cur = popfirst!(queue)
        visit!(grid, cur)
        if cur == g
            path = Tuple{Int, Int}[]
            while cur != s
                push!(path, cur)
                cur = came_from[cur]
            end
            push!(path, s)
            reverse!(path)
            return path
        end
        for nxt in neighbors(grid, cur)
            if !haskey(came_from, nxt)
                came_from[nxt] = cur
                push!(queue, nxt)
                frontier!(grid, nxt)
            end
        end
    end
    return Tuple{Int, Int}[]
end
""",
    ),
    (
        slug = "dfs",
        garden_slug = "pathfinding",
        name = "Depth-First Search (DFS)",
        summary = "Explora cada rama hasta el fondo mediante una pila LIFO antes de retroceder.",
        difficulty = "beginner",
        concept = "Exploración en profundidad y backtracking sin garantía de optimalidad",
        explanation = """
DFS avanza siguiendo un único corredor tanto como sea posible usando una pila antes de retroceder (backtracking).
Encuentra un camino si existe, aunque no necesariamente el más corto.
""",
        visualization_guide = "Observa cómo la frontera avanza en corredores profundos en lugar de expandirse en círculos concéntricos.",
        default_params_json = """{"rows":12,"cols":18,"start":[2,2],"goal":[11,17],"walls":[[2,6],[3,6],[4,6],[5,6],[6,6],[7,6],[8,6],[9,6],[5,11],[6,11],[7,11],[8,11],[9,11],[10,11]],"weights":[]}""",
        reference_code = """
function find_path(grid)
    s = start_node(grid)
    g = goal_node(grid)
    stack = [s]
    visited = Set{Tuple{Int, Int}}()
    came_from = Dict{Tuple{Int, Int}, Tuple{Int, Int}}(s => s)
    frontier!(grid, s)

    while !isempty(stack)
        cur = pop!(stack)
        cur in visited && continue
        push!(visited, cur)
        visit!(grid, cur)
        if cur == g
            path = Tuple{Int, Int}[]
            while cur != s
                push!(path, cur)
                cur = came_from[cur]
            end
            push!(path, s)
            reverse!(path)
            return path
        end
        for nxt in neighbors(grid, cur)
            if !(nxt in visited)
                if !haskey(came_from, nxt)
                    came_from[nxt] = cur
                end
                push!(stack, nxt)
                frontier!(grid, nxt)
            end
        end
    end
    return Tuple{Int, Int}[]
end
""",
    ),
    (
        slug = "dijkstra",
        garden_slug = "pathfinding",
        name = "Dijkstra",
        summary = "Encuentra la ruta de costo mínimo en grids ponderados usando una cola de prioridad por costo acumulado.",
        difficulty = "intermediate",
        concept = "Relajación de aristas y camino más corto con pesos positivos",
        explanation = """
El algoritmo de Dijkstra expande siempre el nodo en frontera con menor costo acumulado `g(n)` usando `MinPriorityQueue`.
Cuando existen celdas con mayor peso de terreno, rodea las zonas costosas para minimizar el costo total.
""",
        visualization_guide = "Las celdas con peso adicional muestran un tono cálido; Dijkstra las evita si existe un rodeo más económico.",
        default_params_json = """{"rows":12,"cols":18,"start":[6,2],"goal":[6,17],"walls":[[3,8],[4,8],[5,8],[7,8],[8,8],[9,8]],"weights":[[6,8,8.0],[6,9,8.0],[5,9,8.0],[7,9,8.0]]}""",
        reference_code = """
function find_path(grid)
    s = start_node(grid)
    g = goal_node(grid)
    pq = MinPriorityQueue{Tuple{Int, Int}, Float64}()
    enqueue!(pq, s, 0.0)
    dist = Dict{Tuple{Int, Int}, Float64}(s => 0.0)
    came_from = Dict{Tuple{Int, Int}, Tuple{Int, Int}}(s => s)
    frontier!(grid, s; cost=0.0)

    while !isempty(pq)
        cur, cur_cost = dequeue!(pq)
        cur_cost > get(dist, cur, Inf) && continue
        visit!(grid, cur; cost=cur_cost)
        if cur == g
            path = Tuple{Int, Int}[]
            while cur != s
                push!(path, cur)
                cur = came_from[cur]
            end
            push!(path, s)
            reverse!(path)
            return path
        end
        for nxt in neighbors(grid, cur)
            alt = cur_cost + step_cost(grid, cur, nxt)
            if alt < get(dist, nxt, Inf)
                dist[nxt] = alt
                came_from[nxt] = cur
                relax_edge!(grid, cur, nxt, alt)
                enqueue!(pq, nxt, alt)
                frontier!(grid, nxt; cost=alt)
            end
        end
    end
    return Tuple{Int, Int}[]
end
""",
    ),
    (
        slug = "a-star",
        garden_slug = "pathfinding",
        name = "A* (A-Star)",
        summary = "Búsqueda informada que combina costo real acumulado y heurística admisible para guiar la exploración al destino.",
        difficulty = "intermediate",
        concept = "Función de evaluación f(n) = g(n) + h(n) y heurística Manhattan",
        explanation = """
A* prioriza nodos según `f(n) = g(n) + h(n)`, donde `g(n)` es el costo desde el inicio y `h(n)` es la distancia Manhattan estimada hasta la meta.
Reduce drásticamente los nodos visitados manteniendo optimalidad cuando la heurística no sobreestima el costo real.
""",
        visualization_guide = "Compara la cantidad de nodos visitados frente a Dijkstra: la frontera se dirige en cono hacia la meta.",
        default_params_json = """{"rows":12,"cols":18,"start":[6,2],"goal":[6,17],"walls":[[3,9],[4,9],[5,9],[6,9],[7,9],[8,9],[9,9]],"weights":[]}""",
        reference_code = """
function find_path(grid)
    s = start_node(grid)
    g = goal_node(grid)
    pq = MinPriorityQueue{Tuple{Int, Int}, Float64}()
    enqueue!(pq, s, Float64(manhattan(s, g)))
    g_score = Dict{Tuple{Int, Int}, Float64}(s => 0.0)
    came_from = Dict{Tuple{Int, Int}, Tuple{Int, Int}}(s => s)
    frontier!(grid, s; cost=0.0)

    while !isempty(pq)
        cur, _ = dequeue!(pq)
        visit!(grid, cur; cost=g_score[cur])
        if cur == g
            path = Tuple{Int, Int}[]
            while cur != s
                push!(path, cur)
                cur = came_from[cur]
            end
            push!(path, s)
            reverse!(path)
            return path
        end
        for nxt in neighbors(grid, cur)
            tentative = g_score[cur] + step_cost(grid, cur, nxt)
            if tentative < get(g_score, nxt, Inf)
                g_score[nxt] = tentative
                came_from[nxt] = cur
                relax_edge!(grid, cur, nxt, tentative)
                f_score = tentative + manhattan(nxt, g)
                enqueue!(pq, nxt, f_score)
                frontier!(grid, nxt; cost=tentative)
            end
        end
    end
    return Tuple{Int, Int}[]
end
""",
    ),
]

const CORE_EXERCISES_SEED = [
    (
        id = "ex-insertion-sort-complete",
        algorithm_slug = "insertion-sort",
        title = "Completa el bucle interno de Insertion Sort",
        instructions = "Completa `sort_algorithm!(arr)` desplazando hacia la izquierda cada elemento menor que su vecino anterior mediante `compare` y `swap!`.",
        starter_code = """
function sort_algorithm!(arr)
    n = length(arr)
    mark_sorted!(arr, 1)
    for i in 2:n
        j = i
        # TODO: Mientras j > 1 y arr[j - 1] > arr[j], intercambia y decrementa j
        mark_sorted!(arr, i)
    end
end
""",
        test_cases_json = """[
            {"name":"arreglo_pequeno","params":{"values":[8,3,5,1,4]}},
            {"name":"invertido","params":{"values":[9,7,5,3,1]}},
            {"name":"duplicados","params":{"values":[4,2,4,1,2]}}
        ]""",
    ),
    (
        id = "ex-bubble-sort-early-exit",
        algorithm_slug = "bubble-sort",
        title = "Implementa Bubble Sort ascendente",
        instructions = "Ordena `arr` de menor a mayor comparando elementos vecinos y usando `swap!(arr, j, j + 1)`.",
        starter_code = """
function sort_algorithm!(arr)
    n = length(arr)
    for i in 1:(n - 1)
        # TODO: Recorre 1:(n - i) y ordena elementos adyacentes
    end
end
""",
        test_cases_json = """[
            {"name":"aleatorio","params":{"size":10,"distribution":"random","seed":5}},
            {"name":"ya_ordenado","params":{"values":[1,2,3,4,5]}},
            {"name":"negativos","params":{"values":[3,-2,0,-5,2]}}
        ]""",
    ),
    (
        id = "ex-quicksort-partition",
        algorithm_slug = "quick-sort",
        title = "Completa la partición de Quick Sort",
        instructions = "Implementa el intercambio final del pivote en `partition!(arr, lo, hi)` y devuelve su índice definitivo.",
        starter_code = """
function partition!(arr, lo, hi)
    mark_range!(arr, lo, hi)
    mid = (lo + hi) >>> 1
    if mid != hi
        swap!(arr, mid, hi)
    end
    mark_pivot!(arr, hi)
    i = lo - 1
    for j in lo:(hi - 1)
        if compare(arr, j, hi) <= 0
            i += 1
            if i != j
                swap!(arr, i, j)
            end
        end
    end
    # TODO: Coloca el pivote (hi) en i + 1 y retorna ese índice
    return hi
end

function quicksort_rec!(arr, lo, hi)
    if lo < hi
        p = partition!(arr, lo, hi)
        quicksort_rec!(arr, lo, p - 1)
        quicksort_rec!(arr, p + 1, hi)
    end
end

function sort_algorithm!(arr)
    quicksort_rec!(arr, 1, length(arr))
end
""",
        test_cases_json = """[
            {"name":"basico","params":{"values":[10,7,8,9,1,5]}},
            {"name":"invertido","params":{"values":[6,5,4,3,2,1]}},
            {"name":"duplicados","params":{"values":[4,4,2,8,2,1]}}
        ]""",
    ),
    (
        id = "ex-bfs-shortest-path",
        algorithm_slug = "bfs",
        title = "Encuentra el camino más corto con BFS",
        instructions = "Completa la exploración de vecinos en `find_path(grid)` para devolver la ruta mínima desde `start_node(grid)` hasta `goal_node(grid)`.",
        starter_code = """
function find_path(grid)
    s = start_node(grid)
    g = goal_node(grid)
    queue = [s]
    came_from = Dict{Tuple{Int, Int}, Tuple{Int, Int}}(s => s)
    frontier!(grid, s)

    while !isempty(queue)
        cur = popfirst!(queue)
        visit!(grid, cur)
        if cur == g
            path = Tuple{Int, Int}[]
            while cur != s
                push!(path, cur)
                cur = came_from[cur]
            end
            push!(path, s)
            reverse!(path)
            return path
        end
        # TODO: Explora neighbors(grid, cur) sin repetir nodos ya vistos
    end
    return Tuple{Int, Int}[]
end
""",
        test_cases_json = """[
            {"name":"grid_abierto","params":{"rows":4,"cols":4,"start":[1,1],"goal":[4,4]},"expected_cost":6.0},
            {"name":"con_muros","params":{"rows":4,"cols":4,"start":[1,1],"goal":[1,4],"walls":[[1,2],[2,2],[3,2]]},"expected_cost":9.0},
            {"name":"sin_salida","params":{"rows":3,"cols":3,"start":[1,1],"goal":[3,3],"walls":[[1,2],[2,1]]},"expect_reachable":false}
        ]""",
    ),
    (
        id = "ex-astar-heuristic",
        algorithm_slug = "a-star",
        title = "Agrega la heurística Manhattan en A*",
        instructions = "Calcula `f_score = tentative + manhattan(nxt, g)` al encolar vecinos en `MinPriorityQueue` para guiar A* hacia el objetivo.",
        starter_code = """
function find_path(grid)
    s = start_node(grid)
    g = goal_node(grid)
    pq = MinPriorityQueue{Tuple{Int, Int}, Float64}()
    enqueue!(pq, s, Float64(manhattan(s, g)))
    g_score = Dict{Tuple{Int, Int}, Float64}(s => 0.0)
    came_from = Dict{Tuple{Int, Int}, Tuple{Int, Int}}(s => s)
    frontier!(grid, s; cost=0.0)

    while !isempty(pq)
        cur, _ = dequeue!(pq)
        visit!(grid, cur; cost=g_score[cur])
        if cur == g
            path = Tuple{Int, Int}[]
            while cur != s
                push!(path, cur)
                cur = came_from[cur]
            end
            push!(path, s)
            reverse!(path)
            return path
        end
        for nxt in neighbors(grid, cur)
            tentative = g_score[cur] + step_cost(grid, cur, nxt)
            if tentative < get(g_score, nxt, Inf)
                g_score[nxt] = tentative
                came_from[nxt] = cur
                # TODO: Encola nxt con prioridad f_score = tentative + manhattan(nxt, g)
            end
        end
    end
    return Tuple{Int, Int}[]
end
""",
        test_cases_json = """[
            {"name":"optimo_con_muro","params":{"rows":5,"cols":5,"start":[1,1],"goal":[5,5],"walls":[[2,2],[3,2],[4,2]]},"expected_cost":8.0},
            {"name":"evita_terreno_caro","params":{"rows":3,"cols":3,"start":[2,1],"goal":[2,3],"weights":[[2,2,10.0]]},"expected_cost":4.0}
        ]""",
    ),
    (
        id = "ex-mergesort-merge",
        algorithm_slug = "merge-sort",
        title = "Completa la mezcla en Merge Sort",
        instructions = "Completa los bucles de `merge_ranges!(arr, lo, mid, hi)` para combinar ambas mitades ordenadas dentro de `arr`.",
        starter_code = """
function merge_ranges!(arr, lo, mid, hi)
    mark_range!(arr, lo, hi)
    left = [arr[i] for i in lo:mid]
    right = [arr[j] for j in (mid + 1):hi]
    i = 1
    j = 1
    k = lo
    while i <= length(left) && j <= length(right)
        # TODO: Elige el menor entre left[i] y right[j], escríbelo en arr[k] y avanza índices
        break
    end
    while i <= length(left)
        arr[k] = left[i]
        i += 1
        k += 1
    end
    while j <= length(right)
        arr[k] = right[j]
        j += 1
        k += 1
    end
end

function mergesort_rec!(arr, lo, hi)
    if lo >= hi
        return
    end
    mid = (lo + hi) ÷ 2
    mergesort_rec!(arr, lo, mid)
    mergesort_rec!(arr, mid + 1, hi)
    merge_ranges!(arr, lo, mid, hi)
end

function sort_algorithm!(arr)
    n = length(arr)
    mergesort_rec!(arr, 1, n)
    for i in 1:n
        mark_sorted!(arr, i)
    end
end
""",
        test_cases_json = """[
            {"name":"par_desordenado","params":{"values":[9,2,7,1,6,4]}},
            {"name":"invertido_impares","params":{"values":[11,8,5,2,-1]}},
            {"name":"duplicados","params":{"values":[4,1,4,2,1]}}
        ]""",
    ),
    (
        id = "ex-dijkstra-weighted",
        algorithm_slug = "dijkstra",
        title = "Relaja aristas ponderadas en Dijkstra",
        instructions = "Usa `step_cost(grid, cur, nxt)` en `find_path(grid)` para calcular `alt = cur_cost + step_cost(grid, cur, nxt)` y evitar celdas de terreno costoso.",
        starter_code = """
function find_path(grid)
    s = start_node(grid)
    g = goal_node(grid)
    pq = MinPriorityQueue{Tuple{Int, Int}, Float64}()
    enqueue!(pq, s, 0.0)
    dist = Dict{Tuple{Int, Int}, Float64}(s => 0.0)
    came_from = Dict{Tuple{Int, Int}, Tuple{Int, Int}}(s => s)
    frontier!(grid, s; cost=0.0)

    while !isempty(pq)
        cur, cur_cost = dequeue!(pq)
        cur_cost > get(dist, cur, Inf) && continue
        visit!(grid, cur; cost=cur_cost)
        if cur == g
            path = Tuple{Int, Int}[]
            while cur != s
                push!(path, cur)
                cur = came_from[cur]
            end
            push!(path, s)
            reverse!(path)
            return path
        end
        for nxt in neighbors(grid, cur)
            # TODO: Reemplaza este costo fijo por cur_cost + step_cost(grid, cur, nxt) y relaja solo si mejora dist[nxt]
            alt = cur_cost + 1.0
            if !haskey(came_from, nxt)
                dist[nxt] = alt
                came_from[nxt] = cur
                enqueue!(pq, nxt, alt)
                frontier!(grid, nxt; cost=alt)
            end
        end
    end
    return Tuple{Int, Int}[]
end
""",
        test_cases_json = """[
            {"name":"rodeo_terreno_caro","params":{"rows":3,"cols":3,"start":[2,1],"goal":[2,3],"weights":[[2,2,10.0]]},"expected_cost":4.0},
            {"name":"corredor_ponderado","params":{"rows":4,"cols":4,"start":[1,1],"goal":[1,4],"weights":[[1,2,9.0],[1,3,9.0]]},"expected_cost":5.0},
            {"name":"meta_inalcanzable","params":{"rows":3,"cols":3,"start":[1,1],"goal":[3,3],"walls":[[1,2],[2,1]]},"expect_reachable":false}
        ]""",
    ),
]

const GARDENS_SEED = vcat(CORE_GARDENS_SEED, PHASE6_GARDENS_SEED)
const ALGORITHMS_SEED = vcat(CORE_ALGORITHMS_SEED, PHASE6_ALGORITHMS_SEED)
const EXERCISES_SEED = vcat(CORE_EXERCISES_SEED, PHASE6_EXERCISES_SEED)

end

