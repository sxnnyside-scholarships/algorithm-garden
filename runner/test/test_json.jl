@testset "GardenJSON" begin
    raw = """{"name":"algo","nums":[1,-2,3.5,0],"ok":true,"empty":null,"esc":"a\\n\\t\\"b\\"\\\\c"}"""
    parsed = parse_json(raw)
    @test parsed["name"] == "algo"
    @test parsed["nums"] == Any[1, -2, 3.5, 0]
    @test parsed["ok"] === true
    @test parsed["empty"] === nothing
    @test parsed["esc"] == "a\n\t\"b\"\\c"

    encoded = to_json(Dict("a" => [1, true, nothing, "x\"y"], "b" => (c = 2.5, d = NaN)))
    roundtrip = parse_json(encoded)
    @test roundtrip["a"] == Any[1, true, nothing, "x\"y"]
    @test roundtrip["b"]["c"] == 2.5
    @test roundtrip["b"]["d"] === nothing

    @test_throws ArgumentError parse_json("")
    @test_throws ArgumentError parse_json("{bad}")
    @test_throws ArgumentError parse_json("[1, 2")
    @test_throws ArgumentError parse_json("123 trailing")
end

