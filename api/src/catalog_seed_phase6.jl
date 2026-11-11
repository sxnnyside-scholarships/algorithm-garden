const PHASE6_GARDENS_SEED = [
    (
        slug = "cellular",
        name = "Cellular Garden",
        description = "Explora sistemas discretos y autómatas celulares con reglas B/S modificables y evolución generación tras generación.",
        sort_order = 3,
    ),
    (
        slug = "graph",
        name = "Graph Garden",
        description = "Comprende recorridos BFS/DFS, componentes conexas y árboles de expansión mínima (Kruskal) sobre grafos ponderados.",
        sort_order = 4,
    ),
    (
        slug = "fractal",
        name = "Fractal Garden",
        description = "Experimenta con escape en el plano complejo (Mandelbrot y conjuntos de Julia) y fractales recursivos con zoom interactivo.",
        sort_order = 5,
    ),
    (
        slug = "evolution",
        name = "Evolution Garden",
        description = "Observa selección por torneo, cruce, mutación y convergencia del fitness en algoritmos genéticos.",
        sort_order = 6,
    ),
]

const PHASE6_ALGORITHMS_SEED = [
    (
        slug = "conways-game-of-life",
        garden_slug = "cellular",
        name = "Conway's Game of Life",
        summary = "Autómata celular 2D clásico regido por supervivencia S23 y nacimiento B3 sobre vecindad de Moore.",
        difficulty = "beginner",
        concept = "Transiciones discretas locales y patrones emergentes (estáticos, osciladores, naves)",
        explanation = """
Cada célula evalúa a sus 8 vecinas (`live_neighbors`). Una célula viva sobrevive con 2 o 3 vecinas vivas; una célula muerta nace exactamente con 3 vecinas vivas.
De reglas deterministas simples emergen planeadores, osciladores y estructuras autoorganizadas.
""",
        visualization_guide = "Las células vivas brillan en verde bio-luminiscente; las recién nacidas o activas pulsan con mayor intensidad en cada generación.",
        default_params_json = """{"rows":14,"cols":18,"generations":18,"preset":"glider","born":[3],"survive":[2,3],"wrap":true}""",
        reference_code = """
function evolve_cellular(grid)
    rows, cols = grid_dims(grid)
    born = rule_born(grid)
    survive = rule_survive(grid)
    cells = current_cells(grid)

    for gen in 1:generations_count(grid)
        next_cells = zeros(Int, rows, cols)
        for r in 1:rows
            for c in 1:cols
                nb = live_neighbors(grid, r, c)
                if cells[r, c] == 1
                    next_cells[r, c] = (nb in survive) ? 1 : 0
                else
                    next_cells[r, c] = (nb in born) ? 1 : 0
                end
            end
        end
        cells = record_generation!(grid, next_cells, gen)
    end
end
""",
    ),
    (
        slug = "custom-life-rules",
        garden_slug = "cellular",
        name = "HighLife (B36/S23)",
        summary = "Variante Life-like parametrizable que añade nacimiento con 6 vecinas (B36/S23), generando replicadores complejos.",
        difficulty = "intermediate",
        concept = "Espacio de reglas B/S en autómatas celulares 2D",
        explanation = """
Generaliza las reglas del Juego de la Vida consultando `rule_born(grid)` y `rule_survive(grid)`. Con B36/S23 surgen patrones autorreplicantes imposibles en Conway estándar.
Prueba cambiar los dígitos de nacimiento/supervivencia en los parámetros para estudiar su estabilidad.
""",
        visualization_guide = "Observa cómo la población y los nacimientos por generación cambian drásticamente al alternar B36/S23 frente a B3/S23.",
        default_params_json = """{"rows":14,"cols":18,"generations":20,"preset":"r_pentomino","born":[3,6],"survive":[2,3],"wrap":true}""",
        reference_code = """
function evolve_cellular(grid)
    rows, cols = grid_dims(grid)
    born = Set(rule_born(grid))
    survive = Set(rule_survive(grid))
    cells = current_cells(grid)

    for gen in 1:generations_count(grid)
        next_cells = zeros(Int, rows, cols)
        for r in 1:rows, c in 1:cols
            nb = live_neighbors(grid, r, c)
            if cells[r, c] == 1
                next_cells[r, c] = (nb in survive) ? 1 : 0
            else
                next_cells[r, c] = (nb in born) ? 1 : 0
            end
        end
        cells = record_generation!(grid, next_cells, gen)
    end
end
""",
    ),
    (
        slug = "brians-brain",
        garden_slug = "cellular",
        name = "Brian's Brain",
        summary = "Autómata de 3 estados (muerta = 0, encendida = 1, refractaria = 2) donde toda célula encendida descansa una generación.",
        difficulty = "intermediate",
        concept = "Estados refractarios y propagación ondulatoria sin crecimiento explosivo",
        explanation = """
A diferencia de Conway, una célula muerta nace si tiene exactamente 2 vecinas encendidas (`state == 1`); toda célula encendida pasa siempre al estado refractario (`2`), y toda refractaria muere (`0`) en la siguiente generación.
""",
        visualization_guide = "El verde esmeralda representa células encendidas (`1`) y los tonos pétalo/orquídea muestran células en periodo refractario (`2`).",
        default_params_json = """{"rows":14,"cols":18,"generations":20,"preset":"brians_glider","born":[2],"survive":[],"wrap":true}""",
        reference_code = """
function evolve_cellular(grid)
    rows, cols = grid_dims(grid)
    cells = current_cells(grid)

    for gen in 1:generations_count(grid)
        next_cells = zeros(Int, rows, cols)
        for r in 1:rows, c in 1:cols
            st = cells[r, c]
            if st == 1
                next_cells[r, c] = 2
            elseif st == 2
                next_cells[r, c] = 0
            else
                nb = live_neighbors(grid, r, c; state = 1)
                next_cells[r, c] = (nb == 2) ? 1 : 0
            end
        end
        cells = record_generation!(grid, next_cells, gen)
    end
end
""",
    ),
    (
        slug = "graph-bfs",
        garden_slug = "graph",
        name = "Graph BFS Traversal",
        summary = "Recorrido en anchura sobre grafos generales que encuentra el camino de menor cantidad de aristas.",
        difficulty = "beginner",
        concept = "Cola FIFO, árbol BFS y distancia geodésica en saltos",
        explanation = """
Graph BFS expande vértices por distancia creciente en saltos desde `start_vertex(graph)` hasta localizar `target_vertex(graph)` o visitar toda la componente alcanzable.
""",
        visualization_guide = "Las aristas aceptadas dibujan el árbol de descubrimiento; el camino final de saltos mínimos resalta en dorado solar.",
        default_params_json = """{"preset":"botanical_web","directed":false,"start_node":1,"target_node":6}""",
        reference_code = """
function analyze_graph(graph)
    s = start_vertex(graph)
    t = target_vertex(graph)
    q = [s]
    parent = Dict{Int, Int}(s => s)
    queue_node!(graph, s)

    while !isempty(q)
        u = popfirst!(q)
        visit_node!(graph, u)
        if u == t
            path = Int[]
            cur = t
            while cur != s
                push!(path, cur)
                cur = parent[cur]
            end
            push!(path, s)
            reverse!(path)
            mark_graph_path!(graph, path)
            return path
        end
        for (v, w) in adjacent(graph, u)
            fresh = !haskey(parent, v)
            inspect_edge!(graph, u, v; weight = w, accepted = fresh)
            if fresh
                parent[v] = u
                push!(q, v)
                queue_node!(graph, v; from = u)
            end
        end
    end
    return Int[]
end
""",
    ),
    (
        slug = "graph-dfs",
        garden_slug = "graph",
        name = "Graph DFS Traversal",
        summary = "Exploración en profundidad recursiva o con pila LIFO registrando descubrimiento y retroceso en grafos.",
        difficulty = "beginner",
        concept = "Pila LIFO, recursión y exploración de ramas completas",
        explanation = """
DFS avanza tan profundo como sea posible por un vecino no visitado antes de retroceder (`backtrack`) hacia vértices pendientes.
""",
        visualization_guide = "Observa cómo DFS explora ramas completas de un extremo a otro a diferencia de los anillos concéntricos de BFS.",
        default_params_json = """{"preset":"botanical_web","directed":false,"start_node":1,"target_node":6}""",
        reference_code = """
function analyze_graph(graph)
    s = start_vertex(graph)
    t = target_vertex(graph)
    visited = Set{Int}()
    order = Int[]

    function dfs(u::Int)
        push!(visited, u)
        push!(order, u)
        visit_node!(graph, u)
        for (v, w) in adjacent(graph, u)
            unseen = !(v in visited)
            inspect_edge!(graph, u, v; weight = w, accepted = unseen)
            if unseen
                queue_node!(graph, v; from = u)
                dfs(v)
            end
        end
    end

    queue_node!(graph, s)
    dfs(s)
    if t in visited
        mark_graph_path!(graph, order)
    end
    return order
end
""",
    ),
    (
        slug = "kruskal-mst",
        garden_slug = "graph",
        name = "Kruskal's Minimum Spanning Tree",
        summary = "Construye un árbol de expansión mínima ordenando aristas por peso y evitando ciclos con Union-Find.",
        difficulty = "intermediate",
        concept = "Algoritmo voraz y estructura Disjoint-Set (Union-Find)",
        explanation = """
Kruskal ordena todas las aristas de menor a mayor peso y acepta cada arista que conecte dos componentes distintas, garantizando el costo total mínimo sin formar ciclos.
""",
        visualization_guide = "Las aristas descartadas parpadean brevemente y las aceptadas permanecen iluminadas como parte del árbol mínimo.",
        default_params_json = """{"preset":"weighted_canopy","directed":false,"start_node":1,"target_node":6}""",
        reference_code = """
function analyze_graph(graph)
    n = node_count(graph)
    parent = collect(1:n)
    find_root(x) = parent[x] == x ? x : (parent[x] = find_root(parent[x]))

    sorted_edges = sort(graph_edges(graph); by = e -> e[3])
    total = 0.0

    for (u, v, w) in sorted_edges
        ru = find_root(u)
        rv = find_root(v)
        accepted = ru != rv
        inspect_edge!(graph, u, v; weight = w, accepted = accepted)
        if accepted
            parent[rv] = ru
            mark_tree_edge!(graph, u, v, w)
            total += w
        end
    end
    return round(total; digits = 4)
end
""",
    ),
    (
        slug = "connected-components",
        garden_slug = "graph",
        name = "Connected Components",
        summary = "Identifica y colorea subgrafos desconectados asignando un identificador único a cada componente.",
        difficulty = "beginner",
        concept = "Partición en componentes conexas en grafos no dirigidos",
        explanation = """
Recorre cada vértice no visitado de `graph_nodes(graph)` iniciando un BFS para etiquetar todo su cúmulo mediante `mark_component!`.
""",
        visualization_guide = "Cada isla o componente recibe un color botánico distinto sobre los vértices conforme es descubierta.",
        default_params_json = """{"preset":"two_islands","directed":false,"start_node":1,"target_node":7}""",
        reference_code = """
function analyze_graph(graph)
    seen = Set{Int}()
    comp_id = 0

    for seed in graph_nodes(graph)
        seed in seen && continue
        comp_id += 1
        q = [seed]
        push!(seen, seed)
        while !isempty(q)
            u = popfirst!(q)
            visit_node!(graph, u; component = comp_id)
            mark_component!(graph, u, comp_id)
            for (v, w) in adjacent(graph, u)
                fresh = !(v in seen)
                inspect_edge!(graph, u, v; weight = w, accepted = fresh)
                if fresh
                    push!(seen, v)
                    push!(q, v)
                end
            end
        end
    end
    return comp_id
end
""",
    ),
    (
        slug = "mandelbrot-set",
        garden_slug = "fractal",
        name = "Mandelbrot Set",
        summary = "Iteración de escape cuadrático z ← z² + c mapeando cada píxel del plano complejo.",
        difficulty = "beginner",
        concept = "Dinámica compleja, radio de escape |z| ≤ 2 y autosimilitud",
        explanation = """
Para cada coordenada compleja `c = pixel_complex(plane, r, c_col)` se itera `z = z^2 + c` desde `z = 0`. Los puntos que nunca escapan pertenecen al conjunto de Mandelbrot.
""",
        visualization_guide = "Haz clic sobre cualquier región del fractal tras ejecutar para hacer zoom 2× hacia detalles más profundos.",
        default_params_json = """{"width":64,"height":48,"x_min":-2.1,"x_max":0.8,"y_min":-1.2,"y_max":1.2,"max_iter":40,"julia_re":-0.7,"julia_im":0.27015,"depth":5}""",
        reference_code = """
function render_fractal(plane)
    w, h = plane_size(plane)
    max_it = max_iterations(plane)

    for r in 1:h
        vals = Vector{Int}(undef, w)
        for c in 1:w
            c0 = pixel_complex(plane, r, c)
            z = 0.0 + 0.0im
            it = 0
            while it < max_it && abs2(z) <= 4.0
                z = z * z + c0
                it += 1
            end
            vals[c] = it
        end
        emit_row!(plane, r, vals)
    end
end
""",
    ),
    (
        slug = "julia-set",
        garden_slug = "fractal",
        name = "Julia Set",
        summary = "Conjunto de Julia paramétrico z₀ = píxel con constante compleja fija c = julia_seed(plane).",
        difficulty = "intermediate",
        concept = "Dualidad Mandelbrot/Julia y sensibilidad al parámetro complejo c",
        explanation = """
A diferencia de Mandelbrot, aquí la semilla `c = julia_seed(plane)` permanece constante y la posición del píxel define el valor inicial `z`. Modifica Re(c) e Im(c) para transformar filamentos en espirales o polvo de Cantor.
""",
        visualization_guide = "Prueba parámetros como `(-0.7, 0.27015)` o `(-0.4, 0.6)` y aumenta `max_iter` para afinar los filamentos.",
        default_params_json = """{"width":64,"height":48,"x_min":-1.6,"x_max":1.6,"y_min":-1.2,"y_max":1.2,"max_iter":45,"julia_re":-0.7,"julia_im":0.27015,"depth":5}""",
        reference_code = """
function render_fractal(plane)
    w, h = plane_size(plane)
    max_it = max_iterations(plane)
    seed = julia_seed(plane)

    for r in 1:h
        vals = Vector{Int}(undef, w)
        for c in 1:w
            z = pixel_complex(plane, r, c)
            it = 0
            while it < max_it && abs2(z) <= 4.0
                z = z * z + seed
                it += 1
            end
            vals[c] = it
        end
        emit_row!(plane, r, vals)
    end
end
""",
    ),
    (
        slug = "recursive-tree",
        garden_slug = "fractal",
        name = "Recursive Botanical Tree",
        summary = "Geometría recursiva de ramificación simétrica que emite segmentos nivel por nivel.",
        difficulty = "intermediate",
        concept = "Recursión geométrica, ángulo de ramificación y escala",
        explanation = """
Desde un tronco base, cada rama se divide recursivamente en dos subramas rotadas `±angle` y escaladas hasta alcanzar `recursion_depth(plane)`.
""",
        visualization_guide = "Cada nivel de recursión colorea las ramas del tronco terroso hacia brotes dorados y pétalos en las puntas.",
        default_params_json = """{"width":64,"height":48,"x_min":-2.0,"x_max":2.0,"y_min":-1.5,"y_max":1.5,"max_iter":32,"julia_re":-0.7,"julia_im":0.27015,"depth":6}""",
        reference_code = """
function render_fractal(plane)
    max_d = recursion_depth(plane)
    buckets = [Vector{Float64}[] for _ in 1:max_d]

    function grow(x::Float64, y::Float64, angle::Float64, len::Float64, d::Int)
        d > max_d && return
        x2 = x + len * cos(angle)
        y2 = y - len * sin(angle)
        push!(buckets[d], [x, y, x2, y2])
        grow(x2, y2, angle - 0.44, len * 0.72, d + 1)
        grow(x2, y2, angle + 0.44, len * 0.72, d + 1)
    end

    grow(50.0, 92.0, pi / 2, 23.0, 1)
    for d in 1:max_d
        emit_segments!(plane, d, buckets[d])
    end
end
""",
    ),
    (
        slug = "genetic-algorithm",
        garden_slug = "evolution",
        name = "Genetic Algorithm",
        summary = "Optimización evolutiva completa con selección por torneo, cruce monopunto, mutación bit-flip y elitismo.",
        difficulty = "intermediate",
        concept = "Exploración vs. explotación en población, cruce y mutación",
        explanation = """
Cada individuo es un vector binario evaluado contra un genoma objetivo. Los mejores pasan por elitismo, mientras torneos binarios seleccionan padres para cruce y mutación en las siguientes generaciones.
""",
        visualization_guide = "La gráfica superior muestra mejor fitness y promedio por generación; la inferior exhibe los genomas élite convergiendo al objetivo.",
        default_params_json = """{"seed":42,"population_size":24,"generations":25,"chromosome_length":16,"mutation_rate":0.05,"crossover_rate":0.85,"elite_count":2}""",
        reference_code = """
function evolve_population(env)
    cfg = env_config(env)
    rng = seeded_rng(cfg.seed + 13)
    pop = initial_population(env)
    n = cfg.population_size
    L = cfg.chromosome_length

    for gen in 1:cfg.generations
        fits = [evaluate_fitness(env, g) for g in pop]
        order = sortperm(fits; rev = true)
        mutations = 0
        crossovers = 0

        next_pop = Vector{Vector{Int}}()
        for k in 1:min(cfg.elite_count, n)
            push!(next_pop, copy(pop[order[k]]))
        end

        tournament() = begin
            a = rand(rng, 1:n)
            b = rand(rng, 1:n)
            fits[a] >= fits[b] ? pop[a] : pop[b]
        end

        while length(next_pop) < n
            p1 = tournament()
            p2 = tournament()
            if rand(rng) < cfg.crossover_rate && L > 1
                cut = rand(rng, 1:(L - 1))
                child = vcat(p1[1:cut], p2[(cut + 1):L])
                crossovers += 1
            else
                child = copy(p1)
            end
            for i in 1:L
                if rand(rng) < cfg.mutation_rate
                    child[i] = mutate_bit(child[i])
                    mutations += 1
                end
            end
            push!(next_pop, child)
        end

        record_population!(env, gen, pop, fits; mutations = mutations, crossovers = crossovers)
        pop = next_pop
    end
end
""",
    ),
    (
        slug = "mutation-hill-climber",
        garden_slug = "evolution",
        name = "Elitist Mutation Climber",
        summary = "Selección elitista sin cruce que muta copias del top de la población para contrastar con cruce genético.",
        difficulty = "beginner",
        concept = "Búsqueda estocástica guiada únicamente por mutación y selección",
        explanation = """
Mantiene al mejor espécimen y genera descendientes mutando aleatoriamente bits sin recombinar material genético entre dos padres.
Úsalo para comparar velocidad de convergencia frente al Algoritmo Genético completo.
""",
        visualization_guide = "Compara la tasa de diversidad y el ritmo de convergencia del promedio frente al algoritmo con cruce.",
        default_params_json = """{"seed":42,"population_size":20,"generations":25,"chromosome_length":16,"mutation_rate":0.08,"crossover_rate":0.0,"elite_count":2}""",
        reference_code = """
function evolve_population(env)
    cfg = env_config(env)
    rng = seeded_rng(cfg.seed + 29)
    pop = initial_population(env)
    n = cfg.population_size
    L = cfg.chromosome_length

    for gen in 1:cfg.generations
        fits = [evaluate_fitness(env, g) for g in pop]
        order = sortperm(fits; rev = true)
        mutations = 0
        next_pop = Vector{Vector{Int}}()
        elites = max(1, cfg.elite_count)
        for k in 1:min(elites, n)
            push!(next_pop, copy(pop[order[k]]))
        end

        while length(next_pop) < n
            parent = pop[order[rand(rng, 1:min(elites, n))]]
            child = copy(parent)
            for i in 1:L
                if rand(rng) < cfg.mutation_rate
                    child[i] = mutate_bit(child[i])
                    mutations += 1
                end
            end
            push!(next_pop, child)
        end

        record_population!(env, gen, pop, fits; mutations = mutations, crossovers = 0)
        pop = next_pop
    end
end
""",
    ),
]

const PHASE6_EXERCISES_SEED = [
    (
        id = "ex-cellular-conway",
        algorithm_slug = "conways-game-of-life",
        title = "Implementa las reglas B3/S23 de Conway",
        instructions = "Completa la transición celular en `evolve_cellular(grid)` calculando `live_neighbors(grid, r, c)` y registrando cada generación con `record_generation!`.",
        starter_code = """
function evolve_cellular(grid)
    rows, cols = grid_dims(grid)
    cells = current_cells(grid)

    for gen in 1:generations_count(grid)
        next_cells = copy(cells)
        # TODO: aplica las reglas de nacimiento (3 vecinas) y supervivencia (2 o 3 vecinas)
        cells = record_generation!(grid, next_cells, gen)
    end
end
""",
        test_cases_json = """[
            {"name":"blinker_rotacion","params":{"rows":5,"cols":5,"generations":1,"live_cells":[[3,2],[3,3],[3,4]],"wrap":false},"min_generations":1,"expected_cells":[[0,0,0,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,0,0,0]]},
            {"name":"bloque_estable","params":{"rows":5,"cols":5,"generations":2,"live_cells":[[2,2],[2,3],[3,2],[3,3]],"wrap":false},"min_generations":2,"expected_cells":[[0,0,0,0,0],[0,1,1,0,0],[0,1,1,0,0],[0,0,0,0,0],[0,0,0,0,0]]}
        ]""",
    ),
    (
        id = "ex-cellular-highlife",
        algorithm_slug = "custom-life-rules",
        title = "Reglas dinámicas HighLife (B36/S23)",
        instructions = "Consulta `rule_born(grid)` y `rule_survive(grid)` en lugar de valores fijos para soportar el nacimiento con 6 vecinas en HighLife.",
        starter_code = """
function evolve_cellular(grid)
    rows, cols = grid_dims(grid)
    cells = current_cells(grid)

    for gen in 1:generations_count(grid)
        next_cells = zeros(Int, rows, cols)
        for r in 1:rows, c in 1:cols
            nb = live_neighbors(grid, r, c)
            # TODO: usa rule_born(grid) y rule_survive(grid) en lugar de solo B3/S23
            next_cells[r, c] = cells[r, c] == 1 ? ((nb == 2 || nb == 3) ? 1 : 0) : (nb == 3 ? 1 : 0)
        end
        cells = record_generation!(grid, next_cells, gen)
    end
end
""",
        test_cases_json = """[
            {"name":"nacimiento_con_6_vecinas","params":{"rows":5,"cols":5,"generations":1,"live_cells":[[2,2],[2,3],[2,4],[4,2],[4,3],[4,4]],"born":[3,6],"survive":[2,3],"wrap":false},"min_generations":1,"expected_alive":5}
        ]""",
    ),
    (
        id = "ex-graph-bfs-path",
        algorithm_slug = "graph-bfs",
        title = "Camino mínimo en saltos con Graph BFS",
        instructions = "Completa el bucle BFS reconstruyendo el camino de `start_vertex(graph)` a `target_vertex(graph)` y regístralo con `mark_graph_path!`.",
        starter_code = """
function analyze_graph(graph)
    s = start_vertex(graph)
    t = target_vertex(graph)
    # TODO: implementa BFS con cola FIFO, visit_node!, queue_node! y mark_graph_path!
    return Int[]
end
""",
        test_cases_json = """[
            {"name":"ruta_corta","params":{"nodes":[{"id":1,"label":"A","x":15,"y":50},{"id":2,"label":"B","x":45,"y":20},{"id":3,"label":"C","x":45,"y":80},{"id":4,"label":"D","x":85,"y":50}],"edges":[[1,2,1],[2,4,1],[1,3,1],[3,4,1]],"start_node":1,"target_node":4},"expected_path":[1,2,4]},
            {"name":"puente_lineal","params":{"nodes":[{"id":1,"label":"A","x":15,"y":50},{"id":2,"label":"B","x":50,"y":50},{"id":3,"label":"C","x":85,"y":50}],"edges":[[1,2,2],[2,3,5]],"start_node":1,"target_node":3},"expected_path":[1,2,3]}
        ]""",
    ),
    (
        id = "ex-graph-kruskal",
        algorithm_slug = "kruskal-mst",
        title = "Árbol de expansión mínima con Kruskal",
        instructions = "Ordena `graph_edges(graph)` por peso y une componentes disjuntas registrando cada arista del árbol mediante `mark_tree_edge!(graph, u, v, w)`.",
        starter_code = """
function analyze_graph(graph)
    n = node_count(graph)
    # TODO: ordena aristas por peso y acepta únicamente aristas sin ciclo usando Union-Find
    return 0.0
end
""",
        test_cases_json = """[
            {"name":"triangulo_ponderado","params":{"nodes":[{"id":1,"label":"A","x":15,"y":50},{"id":2,"label":"B","x":50,"y":20},{"id":3,"label":"C","x":85,"y":50}],"edges":[[1,2,2],[2,3,3],[1,3,9]]},"expected_mst_weight":5.0},
            {"name":"cuadrado_con_atajo","params":{"nodes":[{"id":1,"label":"A","x":20,"y":20},{"id":2,"label":"B","x":80,"y":20},{"id":3,"label":"C","x":80,"y":80},{"id":4,"label":"D","x":20,"y":80}],"edges":[[1,2,1],[2,3,2],[3,4,4],[1,4,8],[1,3,6]]},"expected_mst_weight":7.0}
        ]""",
    ),
    (
        id = "ex-fractal-mandelbrot",
        algorithm_slug = "mandelbrot-set",
        title = "Conteo de escape de Mandelbrot",
        instructions = "Completa el bucle de escape `z = z * z + c0` verificando `abs2(z) <= 4.0` y emite cada fila con `emit_row!(plane, r, vals)`.",
        starter_code = """
function render_fractal(plane)
    w, h = plane_size(plane)
    max_it = max_iterations(plane)
    for r in 1:h
        vals = zeros(Int, w)
        # TODO: calcula las iteraciones de escape para pixel_complex(plane, r, c)
        emit_row!(plane, r, vals)
    end
end
""",
        test_cases_json = """[
            {"name":"origen_y_esquina","params":{"width":21,"height":15,"x_min":-1.0,"x_max":1.0,"y_min":-1.0,"y_max":1.0,"max_iter":20},"expected_min_pixels":315,"sample_checks":[{"row":8,"col":11,"expected":20},{"row":1,"col":1,"max":5}]}
        ]""",
    ),
    (
        id = "ex-evolution-ga",
        algorithm_slug = "genetic-algorithm",
        title = "Cruce y mutación en Algoritmo Genético",
        instructions = "Implementa selección, cruce monopunto y `mutate_bit` dentro de `evolve_population(env)` para alcanzar al menos `0.90` de fitness en 25 generaciones.",
        starter_code = """
function evolve_population(env)
    cfg = env_config(env)
    pop = initial_population(env)
    for gen in 1:cfg.generations
        fits = [evaluate_fitness(env, g) for g in pop]
        # TODO: evoluciona pop aplicando elitismo, cruce y mutate_bit antes de registrar
        record_population!(env, gen, pop, fits; mutations = 0, crossovers = 0)
    end
end
""",
        test_cases_json = """[
            {"name":"convergencia_90","params":{"seed":42,"population_size":24,"generations":25,"chromosome_length":12,"mutation_rate":0.05,"crossover_rate":0.85,"elite_count":2},"min_generations":20,"min_best_fitness":0.9}
        ]""",
    ),
]
