defmodule SymbolPatchTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  PATCH /api/symbols/non-existent
  """
  test "unauthorised update patch submission" do
    conn = conn(:patch, "/api/symbols/non-existent")
    response = Router.call(conn, @opts)

    assert response.status == 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/symbols/0123 -H authorization: at1
  """
  test "authorised invalid update patch submission for a non-existent symbol" do
    data = %{"symbol" => %{"name" => "...","description" => "..","definition" => "..",
      "definition_location" => "..","type" => "macro","categories" => ["existent"]}}

    conn =
      conn(:patch, "/api/symbols/0123", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "The specified symbol could not be found"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/symbols/0123 -H authorization: at1
  """
  test "authorised invalid update patch submission from required fields" do
    data = %{"symbol" => %{"name" => "...","description" => "..","definition" => "..",
      "definition_location" => "..","type" => "macro"}}

    conn =
      conn(:patch, "/api/symbols/0123", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 400
    assert %{"error" => %{"message" => "Required fields are missing (expecting: name, description, definition, definition_location, type, categories(as well as parameters and declaration for functions))"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/symbols/0123 -H authorization: at1
  """
  test "authorised invalid update patch submission from an invalid category" do
    data = %{"symbol" => %{"name" => "...","description" => "..","definition" => "..",
      "definition_location" => "..","type" => "macro","categories" => ["invalid"]}}

    conn =
      conn(:patch, "/api/symbols/0123", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 400
    assert %{"error" => %{"message" => "An invalid category has been entered"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/symbols/0123 -H authorization: at1
  """
  test "authorised invalid update patch submission from no categories" do
    data = %{"symbol" => %{"name" => "...","description" => "..","definition" => "..",
      "definition_location" => "..","type" => "macro","categories" => []}}

    conn =
      conn(:patch, "/api/symbols/0123", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 400
    assert %{"error" => %{"message" => "At least one category must be given"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/symbols/existent -H authorization: at1
  """
  test "authorised valid update patch submission for review 1" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    new_sym_name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          definition_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c)
    """)
    data = %{"symbol" => %{"name" => "#{new_sym_name}","description" => "..",
      "definition" => "..","definition_location" => "..","type" => "macro","categories" => ["existent"]}}

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 202
    assert %{"symbol" => %{"name" => new_sym_name2}} = Poison.decode!(response.resp_body)
    assert String.to_integer(new_sym_name2) == new_sym_name
    refute [] == Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (s)-[:UPDATE]->(su:UpdateSymbolPatch {name: '#{new_sym_name}'}),
        (su)-[:CATEGORY]->(c:Category {url: 'existent'}),
        (su)-[:CONTRIBUTOR {type: 'update'}]->()
      RETURN su
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (s:Symbol {revision_id: #{sym_rev}})-[r1:CATEGORY]->(c),
        (s)-[r2:UPDATE]->(su:UpdateSymbolPatch {name: '#{new_sym_name}'}),
        (su)-[r3:CATEGORY]->(c),
        (su)-[r4:CONTRIBUTOR {type: 'update'}]->()
      DELETE r1, r2, r3, r4, s, su
    """)
  end

  @doc """
  PATCH /api/symbols/existent -H authorization: at2
  """
  test "authorised valid update patch submission for review 2" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    new_sym_name = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          definition_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c)
    """)
    data = %{"review" => "1", "symbol" => %{"name" => "#{new_sym_name}","description" => "..",
      "definition" => "..","definition_location" => "..","type" => "macro","categories" => ["existent"]}}

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 202
    assert %{"symbol" => %{"name" => new_sym_name2}} = Poison.decode!(response.resp_body)
    assert String.to_integer(new_sym_name2) == new_sym_name
    refute [] == Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (s)-[:UPDATE]->(su:UpdateSymbolPatch {name: '#{new_sym_name}'}),
        (su)-[:CATEGORY]->(c:Category {url: 'existent'}),
        (su)-[:CONTRIBUTOR {type: 'update'}]->()
      RETURN su
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (s:Symbol {revision_id: #{sym_rev}}),
        (su:UpdateSymbolPatch {name: '#{new_sym_name}'}),
        (c)<-[r1:CATEGORY]-(s),
        (s)-[r2:UPDATE]->(su),
        (su)-[r3:CATEGORY]->(c),
        (su)-[r4:CONTRIBUTOR {type: 'update'}]->()
      DELETE r1, r2, r3, r4, s, su
    """)
  end

  @doc """
  PATCH /api/symbols/existent -H authorization: at3
  """
  test "authorised valid update patch submission" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    new_sym_name = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          definition_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c)
    """)
    data = %{"symbol" => %{"name" => "#{new_sym_name}","description" => "..",
      "definition" => "..","definition_location" => "..","type" => "macro","categories" => ["existent"]}}

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol" => %{"name" => new_sym_name2}} = Poison.decode!(response.resp_body)
    assert String.to_integer(new_sym_name2) === new_sym_name
    assert [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (su:UpdateSymbolPatch {name: '#{new_sym_name}'}),
        (c:Category {url: 'existent'}),
        (s)-[:UPDATE]->(su),
        (su)-[:CATEGORY]->(c)
      RETURN su
    """)
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (s:Symbol {name: '#{new_sym_name}'}),
        (sr:SymbolRevision {revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c),
        (s)-[:REVISION]->(sr),
        (sr)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR {type: 'update'}]->()
      RETURN sr
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (s:Symbol {revision_id: '#{new_sym_name}'}),
        (sr:SymbolRevision {revision_id: #{sym_rev}}),
        (c)<-[r1:CATEGORY]-(s),
        (s)-[r2:REVISION]->(sr),
        (sr)-[r3:CATEGORY]->(c),
        (s)-[r4:CONTRIBUTOR {type: 'update'}]->()
        DELETE r1, r2, r3, r4, s, sr
    """)
  end

  @doc """
  PATCH /api/symbols/existent?apply_patch=update -H authorization: at3
  """
  test "authorised valid apply patch update" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    sym_rev_b = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          definition_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (su:UpdateSymbolPatch {
          id: #{sym_id},
          name: '...2',
          description: '..',
          url: '...2',
          definition: '..',
          definition_location: '..',
          type: 'macro',
          revision_id: #{sym_rev_b},
          against_revision: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(su),
        (su)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"apply_patch" => "update,#{sym_rev_b}"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol" => %{"name" => "...2"}} = Poison.decode!(response.resp_body)
    assert [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}}),
        (c:Category {url: 'existent'}),
        (s)-[:UPDATE]->(su),
        (s)-[:CATEGORY]->(c),
        (su)-[:CATEGORY]->(c)
      RETURN su
    """)
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (sr:SymbolRevision {revision_id: #{sym_rev}}),
        (s:Symbol {revision_id: #{sym_rev_b}}),
        (c:Category {url: 'existent'}),
        (s)-[:REVISION]->(sr),
        (s)-[:CATEGORY]->(c),
        (sr)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR {type: 'apply_update'}]->()
      RETURN sr
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (s:Symbol {revision_id: #{sym_rev_b}}),
        (sr:SymbolRevision {revision_id: #{sym_rev}}),
        (c)<-[r1:CATEGORY]-(s),
        (s)-[r2:REVISION]->(sr),
        (sr)-[r3:CATEGORY]->(c),
        (s)-[r4:CONTRIBUTOR {type: 'apply_update'}]->()
        DELETE r1, r2, r3, r4, s, sr
    """)
  end

  @doc """
  PATCH /api/symbols/existent?discard_patch=update -H authorization: at3
  """
  test "authorised valid discard patch update" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    sym_rev_b = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          definition_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (su:UpdateSymbolPatch {
          id: #{sym_id},
          name: '...2',
          description: '..',
          url: '...2',
          definition: '..',
          definition_location: '..',
          type: 'macro',
          revision_id: #{sym_rev_b},
          against_revision: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(su),
        (su)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"discard_patch" => "update,#{sym_rev_b}"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}}),
        (c:Category {url: 'existent'}),
        (s)-[:UPDATE]->(su),
        (s)-[:CATEGORY]->(c),
        (su)-[:CATEGORY]->(c)
      RETURN su
    """)
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (su:UpdateSymbolPatchDeleted {revision_id: #{sym_rev_b}}),
        (c:Category {url: 'existent'}),
        (s)-[:UPDATE]->(su),
        (s)-[:CATEGORY]->(c),
        (su)-[:CATEGORY]->(c),
        (su)-[:CONTRIBUTOR {type: 'discard_update'}]->()
      RETURN su
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}}),
        (c:Category {url: 'existent'}),
        (s)-[r1:UPDATE]->(su),
        (s)-[r2:CATEGORY]->(c),
        (su)-[r3:CATEGORY]->(c),
        (su)-[r4:CONTRIBUTOR {type: 'discard_update'}]->()
        DELETE r1, r2, r3, r4, s, su
    """)
  end

  @doc """
  PATCH /api/symbols/existent?apply_patch=insert -H authorization: at3
  """
  test "authorised valid apply patch insert" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (s:InsertSymbolPatch {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          definition_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"apply_patch" => "insert"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol" => %{"name" => "..."}} = Poison.decode!(response.resp_body)
    assert [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:InsertSymbolPatch {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[:CATEGORY]->(c)
      RETURN s
    """)
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR {type: 'apply_insert'}]->()
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[r1:CATEGORY]->(c),
        (s)-[r2:CONTRIBUTOR {type: 'apply_insert'}]->()
      DELETE r1, r2, s
    """)
  end

  @doc """
  PATCH /api/symbols/existent?discard_patch=insert -H authorization: at3
  """
  test "authorised valid discard patch insert" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (s:InsertSymbolPatch {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          definition_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"discard_patch" => "insert"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:InsertSymbolPatch {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[:CATEGORY]->(c)
      RETURN s
    """)
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:InsertSymbolPatchDeleted {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR {type: 'discard_insert'}]->()
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:InsertSymbolPatchDeleted {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[r1:CATEGORY]->(c),
        (s)-[r2:CONTRIBUTOR {type: 'discard_insert'}]->()
      DELETE r1, r2, s
    """)
  end

  @doc """
  PATCH /api/symbols/existent?apply_patch=delete -H authorization: at3
  """
  test "authorised valid apply patch delete" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          definition_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)-[:DELETE]->(:DeleteSymbolPatch)
    """)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"apply_patch" => "delete"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 204
    assert [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[:CATEGORY]->(c),
        (s)-[:DELETE]->(:DeleteSymbolPatch)
      RETURN s
    """)
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (sd:SymbolDeleted {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (sd)-[:CATEGORY]->(c),
        (sd)-[:CONTRIBUTOR {type: 'apply_delete'}]->()
      RETURN sd
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (sd:SymbolDeleted {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (sd)-[r1:CATEGORY]->(c),
        (sd)-[r2:CONTRIBUTOR {type: 'apply_delete'}]->()
      DELETE r1, r2, sd
    """)
  end

  @doc """
  PATCH /api/symbols/existent?discard_patch=delete -H authorization: at3
  """
  test "authorised valid discard patch delete" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          definition_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)-[:DELETE]->(:DeleteSymbolPatch)
    """)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"discard_patch" => "delete"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[:CATEGORY]->(c),
        (s)-[:DELETE]->(:DeleteSymbolPatch)
      RETURN s
    """)
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR {type: 'discard_delete'}]->()
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[r1:CATEGORY]->(c),
        (s)-[r2:CONTRIBUTOR {type: 'discard_delete'}]->()
      DELETE r1, r2, s
    """)
  end
end
