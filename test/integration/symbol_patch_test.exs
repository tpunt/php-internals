defmodule SymbolPatchTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  PATCH /api/symbols/non-existent
  """
  test "unauthorised update patch submission" do
    conn = conn(:patch, "/api/symbols/non-existent")
    response = Router.call(conn, @opts)

    assert response.status === 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/symbols/0123 -H authorization: at1
  """
  test "authorised invalid update patch submission for a non-existent symbol" do
    data = %{"symbol" => %{"name" => "...","description" => "..","definition" => "..",
      "source_location" => "..","type" => "macro","categories" => ["existent"],
      "declaration" => ".."}, "revision_id" => 1}

    conn =
      conn(:patch, "/api/symbols/0123", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "The specified symbol could not be found"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/symbols/0123 -H authorization: at1
  """
  test "authorised invalid update patch submission from required fields" do
    data = %{"symbol" => %{"name" => "...","description" => "..","definition" => "..",
      "source_location" => "..","type" => "macro"}, "revision_id" => 1}

    conn =
      conn(:patch, "/api/symbols/0123", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Required fields are missing (expecting: type, name, declaration, source_location, description, categories)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/symbols/0123 -H authorization: at1
  """
  test "authorised invalid update patch submission from an invalid category" do
    data = %{"symbol" => %{"name" => "...","description" => "..","definition" => "..",
      "source_location" => "..","type" => "macro","categories" => ["invalid"],
      "declaration" => ".."}, "revision_id" => 1}

    conn =
      conn(:patch, "/api/symbols/0123", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "An invalid category has been entered"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/symbols/0123 -H authorization: at1
  """
  test "authorised invalid update patch submission from no categories" do
    data = %{"symbol" => %{"name" => "...","description" => "..","definition" => "..",
      "source_location" => "..","type" => "macro","categories" => [], "declaration" => ".."},
      "revision_id" => 1}

    conn =
      conn(:patch, "/api/symbols/0123", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 400
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
          source_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c)
    """)
    data = %{"symbol" => %{"name" => "#{new_sym_name}","description" => "..",
      "definition" => "..","source_location" => "..","type" => "macro",
      "categories" => ["existent"], "declaration" => ".."}, "revision_id" => sym_rev}

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 202
    assert %{"symbol" => %{"name" => "..."}} = Poison.decode!(response.resp_body)
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (s)-[:UPDATE]->(su:UpdateSymbolPatch {name: '#{new_sym_name}'}),
        (su)-[:CATEGORY]->(c:Category {url: 'existent'}),
        (su)-[:CONTRIBUTOR {type: 'update'}]->(:User {access_token: 'at1'})
      RETURN su
    """)

    conn = conn(:get, "/api/symbols/#{sym_id}", %{})
    response2 = Router.call(conn, @opts)

    assert Poison.decode!(response.resp_body) === Poison.decode!(response2.resp_body)

    conn =
      conn(:get, "/api/symbols/#{sym_id}/updates", %{})
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)

    assert %{"symbol_updates" => %{"symbol" => %{}, "updates" =>
      [%{"user" => %{}, "revision_id" => _, "date" => _, "against_revision" => _}]}}
        = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}})-[r1]-(),
        (su:UpdateSymbolPatch {name: '#{new_sym_name}'})-[r2]-()
      DELETE r1, r2, s, su
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
          source_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c)
    """)
    data = %{"review" => "1", "symbol" => %{"name" => "#{new_sym_name}","description" => "..",
      "definition" => "..","source_location" => "..","type" => "macro",
      "categories" => ["existent"], "declaration" => ".."}, "revision_id" => sym_rev}

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 202
    assert %{"symbol" => %{"name" => "..."}} = Poison.decode!(response.resp_body)
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (su:UpdateSymbolPatch {name: '#{new_sym_name}'}),
        (s)-[:UPDATE]->(su),
        (su)-[:CATEGORY]->(c:Category {url: 'existent'}),
        (su)-[:CONTRIBUTOR {type: 'update'}]->(:User {access_token: 'at2'})
      RETURN su
    """)

    conn = conn(:get, "/api/symbols/#{sym_id}", %{})
    response2 = Router.call(conn, @opts)

    assert Poison.decode!(response.resp_body) === Poison.decode!(response2.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}})-[r1]-(),
        (su:UpdateSymbolPatch {name: '#{new_sym_name}'})-[r2]-()
      DELETE r1, r2, s, su
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
          source_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c)
    """)
    data = %{"symbol" => %{"name" => "#{new_sym_name}","description" => "..","definition" => "..",
      "source_location" => "..","type" => "macro","categories" => ["existent"],
      "declaration" => ".."}, "revision_id" => sym_rev}

    # prime the cache
    conn = conn(:get, "/api/symbols/#{sym_id}", %{})
    Router.call(conn, @opts)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol" => %{"name" => new_sym_name2}} = Poison.decode!(response.resp_body)
    assert String.to_integer(new_sym_name2) === new_sym_name
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (s:Symbol {name: '#{new_sym_name}'}),
        (sr:SymbolRevision {revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c),
        (s)-[:REVISION]->(sr),
        (s)-[:CONTRIBUTOR {type: 'update'}]->(:User {access_token: 'at3'})
      RETURN sr
    """)

    conn = conn(:get, "/api/symbols/#{sym_id}", %{})
    response2 = Router.call(conn, @opts)

    assert Poison.decode!(response.resp_body) === Poison.decode!(response2.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {name: '#{new_sym_name}'})-[r1]-(),
        (sr:SymbolRevision {revision_id: #{sym_rev}})-[r2]-()
      DELETE r1, r2, s, sr
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
      MATCH (c:Category {url: 'existent'}),
        (u:User {id: 3})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          source_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (su:UpdateSymbolPatch {
          id: #{sym_id},
          name: '...2',
          description: '..',
          url: '...2',
          definition: '..',
          source_location: '..',
          type: 'macro',
          revision_id: #{sym_rev_b},
          against_revision: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(su),
        (su)-[:CATEGORY]->(c),
        (su)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(u)
    """)

    # prime the cache
    conn = conn(:get, "/api/symbols/#{sym_id}", %{})
    Router.call(conn, @opts)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"apply_patch" => "update,#{sym_rev_b}"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol" => %{"name" => "...2"}} = Poison.decode!(response.resp_body)
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev_b}}),
        (sr:SymbolRevision {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[:REVISION]->(sr),
        (s)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR {type: 'apply_update'}]->(:User {access_token: 'at3'})
      RETURN sr
    """)

    conn = conn(:get, "/api/symbols/#{sym_id}", %{})
    response2 = Router.call(conn, @opts)

    assert Poison.decode!(response.resp_body) === Poison.decode!(response2.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev_b}})-[r1]-(),
        (sr:SymbolRevision {revision_id: #{sym_rev}})-[r2]-()
      DELETE r1, r2, s, sr
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
      MATCH (c:Category {url: 'existent'}),
        (u:User {id: 3})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          source_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (su:UpdateSymbolPatch {
          id: #{sym_id},
          name: '...2',
          description: '..',
          url: '...2',
          definition: '..',
          source_location: '..',
          type: 'macro',
          revision_id: #{sym_rev_b},
          against_revision: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(su),
        (su)-[:CATEGORY]->(c),
        (su)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(u)
    """)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"discard_patch" => "update,#{sym_rev_b}"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (su:UpdateSymbolPatchDeleted {revision_id: #{sym_rev_b}}),
        (c:Category {url: 'existent'}),
        (s)-[:UPDATE]->(su),
        (s)-[:CATEGORY]->(c),
        (su)-[:CONTRIBUTOR {type: 'discard_update'}]->(:User {access_token: 'at3'})
      RETURN su
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}})-[r1]-(),
        (su:UpdateSymbolPatchDeleted {revision_id: #{sym_rev_b}})-[r2]-()
      DELETE r1, r2, s, su
    """)
  end

  @doc """
  PATCH /api/symbols/existent?apply_patch=insert -H authorization: at3
  """
  test "authorised valid apply patch insert" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (u:User {id: 3})
      CREATE (s:InsertSymbolPatch {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          source_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(u)
    """)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"apply_patch" => "insert"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol" => %{"name" => "..."}} = Poison.decode!(response.resp_body)
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR {type: 'apply_insert'}]->(:User {access_token: 'at3'})
      RETURN s
    """)

    conn = conn(:get, "/api/symbols/#{sym_id}", %{})
    response2 = Router.call(conn, @opts)

    assert response2.status === 200
    assert Poison.decode!(response.resp_body) === Poison.decode!(response2.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}})-[r]-()
      DELETE r, s
    """)
  end

  @doc """
  PATCH /api/symbols/existent?discard_patch=insert -H authorization: at3
  """
  test "authorised valid discard patch insert" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (u:User {id: 3})
      CREATE (s:InsertSymbolPatch {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          source_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(u)
    """)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"discard_patch" => "insert"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:InsertSymbolPatchDeleted {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[:CONTRIBUTOR {type: 'discard_insert'}]->(:User {access_token: 'at3'})
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:InsertSymbolPatchDeleted {revision_id: #{sym_rev}})-[r]-()
      DELETE r, s
    """)
  end

  @doc """
  PATCH /api/symbols/existent?apply_patch=delete -H authorization: at3
  """
  test "authorised valid apply patch delete" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (u:User {access_token: 'at1'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          source_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)<-[:DELETE]-(u)
    """)

    # prime the cache
    conn = conn(:get, "/api/symbols/#{sym_id}", %{})
    Router.call(conn, @opts)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"apply_patch" => "delete"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 204
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (sd:SymbolDeleted {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (sd)-[:CONTRIBUTOR {type: 'delete'}]->(:User {access_token: 'at1'}),
        (sd)-[:CONTRIBUTOR {type: 'apply_delete'}]->(:User {access_token: 'at3'})
      RETURN sd
    """)

    conn = conn(:get, "/api/symbols/#{sym_id}", %{})
    response2 = Router.call(conn, @opts)

    assert response2.status === 404

    Neo4j.query!(Neo4j.conn, """
      MATCH (sd:SymbolDeleted {revision_id: #{sym_rev}})-[r]-()
      DELETE r, sd
    """)
  end

  @doc """
  PATCH /api/symbols/existent?discard_patch=delete -H authorization: at3
  """
  test "authorised valid discard patch delete" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (u:User {access_token: 'at3'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          source_location: '.',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)<-[:DELETE]-(u)
    """)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", %{"discard_patch" => "delete"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (c:Category {url: 'existent'}),
        (s)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR {type: 'discard_delete'}]->(:User {access_token: 'at3'})
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}})-[r]-()
      DELETE r, s
    """)
  end

  test "Authorised update existing symbol from update patch review" do
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: 'existent'})
      CREATE (s:Symbol {
          id: #{rev_id},
          name: '.',
          description: '.',
          url: '.',
          definition: '.',
          source_location: '.',
          type: 'macro',
          revision_id: #{rev_id}
        }),
        (usp:UpdateSymbolPatch {
          id: #{rev_id},
          name: '..',
          description: '..',
          url: '..',
          definition: '..',
          source_location: '..',
          type: 'macro',
          revision_id: #{rev_id2}
        }),
        (s)-[:UPDATE]->(usp),
        (s)-[:CATEGORY]->(c),
        (usp)-[:CATEGORY]->(c)
    """)
    data = %{"review" => "1", "references_patch" => "#{rev_id2}", "symbol" =>
      %{"name" => "...","description" => "...","definition" => "...",
      "source_location" => "...","type" => "macro","categories" => ["existent"],
      "declaration" => ".."}, "revision_id" => rev_id2}

    conn =
      conn(:patch, "/api/symbols/#{rev_id}", data)
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 202
    assert %{"symbol" => %{"name" => "."}} = Poison.decode! response.resp_body
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{rev_id}}),
        (s)-[:UPDATE]->(usp:UpdateSymbolPatch {name: '...'}),
        (usp)-[:UPDATE_REVISION]->(uspr:UpdateSymbolPatchRevision {revision_id: #{rev_id2}}),
        (usp)-[:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at3'})
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{rev_id}})-[r1]-(),
        (uspr:UpdateSymbolPatchRevision {revision_id: #{rev_id2}})-[r2]-(),
        (s)-[r3:UPDATE]->(usp:UpdateSymbolPatch {name: '...'})-[r4]-()
      DELETE r1, r2, r3, r4, s, usp, uspr
    """)
  end

  test "Authorised update existing symbol from update patch no review" do
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: 'existent'})
      CREATE (s:Symbol {
          id: #{rev_id},
          name: '.',
          description: '.',
          url: '.',
          definition: '.',
          source_location: '.',
          type: 'macro',
          revision_id: #{rev_id}
        }),
        (usp:UpdateSymbolPatch {
          id: #{rev_id},
          name: '..',
          description: '..',
          url: '..',
          definition: '..',
          source_location: '..',
          type: 'macro',
          revision_id: #{rev_id2}
        }),
        (s)-[:UPDATE]->(usp),
        (s)-[:CATEGORY]->(c),
        (usp)-[:CATEGORY]->(c)
    """)
    data = %{"references_patch" => "#{rev_id2}", "symbol" => %{"name" => "...",
      "description" => "...","definition" => "...", "source_location" => "...",
      "type" => "macro","categories" => ["existent"], "declaration" => ".."},
      "revision_id" => rev_id2}

    # prime the cache
    conn = conn(:get, "/api/symbols/#{rev_id}", %{})
    Router.call(conn, @opts)

    conn =
      conn(:patch, "/api/symbols/#{rev_id}", data)
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol" => %{"name" => "..."}} = Poison.decode! response.resp_body
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (sr:SymbolRevision {revision_id: #{rev_id}}),
        (s:Symbol {name: '...'})-[:REVISION]->(sr),
        (s)-[:UPDATE_REVISION]->(uspr:UpdateSymbolPatchRevision {revision_id: #{rev_id2}}),
        (s)-[:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at3'})
      RETURN s
    """)

    conn = conn(:get, "/api/symbols/#{rev_id}", %{})
    response2 = Router.call(conn, @opts)

    assert Poison.decode!(response.resp_body) === Poison.decode!(response2.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (sr:SymbolRevision {revision_id: #{rev_id}})-[r1]-(),
        (s:Symbol {name: '...'})-[r2:REVISION]->(sr),
        (s)-[r3]-(),
        (uspr:UpdateSymbolPatchRevision {revision_id: #{rev_id2}})-[r4]-()
      DELETE r1, r2, r3, r4, s, sr, uspr
    """)
  end

  @doc """
  PATCH /api/symbols/... -H 'authorization: ...'
  """
  test "Authorised invalid attempt at updating a symbol (patch limit reached)" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (user:User {username: '#{name}', access_token: '#{name}', privilege_level: 1}),
        (c:UpdateCategoryPatch)
      FOREACH (ignored in RANGE(1, 20) |
        CREATE (c)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(user)
      )
    """)

    conn =
      conn(:patch, "/api/symbols/...", %{"symbol" => %{}, "revision_id" => 1})
      |> put_req_header("authorization", "#{name}")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The maximum patch limit (20) has been exceeded!"}}
      = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (u:User {username: '#{name}'})<-[r]-(c) DELETE r, u, c")
  end

  @doc """
  PATCH /api/symbols/... -H 'authorization: at2'
  """
  test "Authenticated attempt at inserting a new symbol (cache invalidation test)" do
    cat_name = Integer.to_string(:rand.uniform(100_000_000))
    cat_revid = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (u:User {access_token: 'at3'})

      CREATE (c2:Category {id: 10, name: '#{cat_name}', introduction: '.', url: '#{cat_name}', revision_id: #{cat_revid}}),
        (c2)-[:CONTRIBUTOR {type: "insert", date: 20170810, time: 6}]->(u),
        (s:Symbol {
            id: #{sym_id},
            name: '...',
            description: '.',
            declaration: '.',
            url: '...',
            definition: '.',
            source_location: '.',
            type: 'macro',
            revision_id: #{sym_rev}
          }),
          (s)-[:CATEGORY]->(c)
    """)

    data = %{"symbol" => %{"name" => "...", "description" => ".", "definition" => ".",
      "source_location" => ".", "type" => "macro", "categories" => [cat_name],
      "declaration" => ".."}, "revision_id" => sym_rev}

    # prime the cache
    response = Router.call(conn(:get, "/api/symbols", %{"category" => cat_name}), @opts)

    assert %{"symbols" => []} = Poison.decode!(response.resp_body)

    conn =
      conn(:patch, "/api/symbols/#{sym_id}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {id: #{sym_id}}),
        (s)-[:CONTRIBUTOR {type: 'update'}]->(:User {access_token: 'at2'}),
        (s)-[:CATEGORY]->(:Category {url: '#{cat_name}'})
      RETURN s
    """)

    response = Router.call(conn(:get, "/api/symbols", %{"category" => "#{cat_name}"}), @opts)

    refute [] === Poison.decode!(response.resp_body)["symbols"]

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{cat_name}'}),
        (s:Symbol {name: '#{sym_name}'}),
        (s)-[:REVISION]->(sr:SymbolRevision)
      DETACH DELETE c, s, sr
    """)
  end
end
