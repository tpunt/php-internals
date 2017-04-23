defmodule SymbolGetTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  GET /api/symbols/0123?view=overview
  """
  test "get a non-existent symbol's overview" do
    conn = conn(:get, "/api/symbols/0123", %{"view" => "overview"})
    response = Router.call(conn, @opts)

    assert response.status === 404
  end

  @doc """
  GET /api/symbols/non-existent-invalid?view=overview
  """
  test "get a non-existent symbol's overview with an invalid ID" do
    conn = conn(:get, "/api/symbols/non-existent", %{"view" => "overview"})
    response = Router.call(conn, @opts)

    assert response.status === 400
  end

  @doc """
  GET /api/symbols/0123
  """
  test "get a non-existent symbol" do
    conn = conn(:get, "/api/symbols/0123", %{})
    response = Router.call(conn, @opts)

    assert response.status === 404
  end

  @doc """
  GET /api/symbols/0123?view=unknown
  """
  test "get a non-existent symbol with an unknown view" do
    conn = conn(:get, "/api/symbols/0123", %{"view" => "unknown"})
    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Invalid view type given (expecting: normal, overview)"}}
      = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/existent?view=overview
  """
  test "get an existing symbol's overview" do
    conn = conn(:get, "/api/symbols/0", %{"view" => "overview"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol" => %{"id" => 0, "name" => "existent", "url" => "existent", "type" => "macro"}}
      = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/existent
  """
  test "get an existing symbol" do
    conn = conn(:get, "/api/symbols/0", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol" => %{"id" => 0, "name" => "existent", "description" => "~",
      "url" => "existent", "definition" => "~", "source_location" => "~",
      "type" => "macro", "revision_id" => 123, "categories" => [%{"category" =>
      %{"name" => "existent", "url" => "existent"}}]}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/0123?patches=delete -H authorization:at3
  """
  test "get an non-existent symbol's delete patch" do
    conn =
      conn(:get, "/api/symbols/0123", %{"patches" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "The specified symbol could not be found"}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/existent?patches=delete -H authorization:at3
  """
  test "get an existing symbol's invalid delete patch" do
    conn =
      conn(:get, "/api/symbols/0", %{"patches" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "The specified symbol delete patch could not be found"}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/existent?patches=delete -H authorization:at3
  """
  test "get an existing symbol's delete patch" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (u:User {access_token: 'at2'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '...',
          description: '.',
          url: '...',
          definition: '.',
          source_location: '..',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)<-[:DELETE]-(u)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}", %{"patches" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_delete" => %{"symbol" => %{"id" => sym_id2, "name" => "...",
      "description" => ".", "url" => "...", "definition" => ".", "source_location" => "..",
      "type" => "macro", "revision_id" => sym_rev2, "categories" => [%{"category" =>
      %{"name" => "existent", "url" => "existent"}}]}}}
        = Poison.decode! response.resp_body
    assert sym_id2 === sym_id
    assert sym_rev2 === sym_rev

    Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {revision_id: #{sym_rev}})-[r]-() DELETE r, s")
  end

  @doc """
  GET /api/symbols/0123?patches=insert -H authorization:at3
  """
  test "get an non-existent symbol's insert patch" do
    conn =
      conn(:get, "/api/symbols/0123", %{"patches" => "insert"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "The specified symbol insert patch could not be found"}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/existent?patches=insert -H authorization:at3
  """
  test "get an existing symbol's insert patch" do
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (u:User {id: 3})
      CREATE (s:InsertSymbolPatch {
          id: #{sym_id},
          name: "...",
          description: '.',
          url: '...',
          definition: '.',
          source_location: '..',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR]->(u)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}", %{"patches" => "insert"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_insert" => %{"symbol" => %{"id" => sym_id2, "name" => "...",
      "description" => ".", "url" => "...", "definition" => ".", "source_location" => "..",
      "type" => "macro", "revision_id" => sym_rev2, "categories" => [%{"category" =>
      %{"name" => "existent", "url" => "existent"}}]}}}
        = Poison.decode! response.resp_body
    assert sym_id2 === sym_id
    assert sym_rev2 === sym_rev

    Neo4j.query!(Neo4j.conn, "MATCH (s:InsertSymbolPatch {revision_id: #{sym_rev}})-[r]-() DELETE r, s")
  end

  @doc """
  GET /api/symbols/existent?patches=update -H authorization:at3
  """
  test "get an existing symbol's update patches 1" do
    conn =
      conn(:get, "/api/symbols/0", %{"patches" => "update"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_updates" => %{"updates" => [], "symbol" => %{"id" => 0,
      "name" => "existent", "description" => "~", "url" => "existent", "definition" => "~",
      "source_location" => "~", "type" => "macro", "revision_id" => 123,
      "categories" => [%{"category" => %{"name" => "existent", "url" => "existent"}}]}}}
        = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/existent?patches=update -H authorization:at3
  """
  test "get an existing symbol's update patches 2" do
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
          source_location: '..',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s2:UpdateSymbolPatch {
          id: #{sym_id},
          name: '...2',
          description: '.2',
          url: '...2',
          definition: '.2',
          source_location: '..2',
          type: 'macro',
          revision_id: #{sym_rev_b}
        }),
        (s2)-[:CATEGORY]->(c),
        (s2)-[:CONTRIBUTOR]->(u),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}", %{"patches" => "update"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_updates" => %{"updates" => updates, "symbol" => %{"id" => sym_id2,
      "name" => "...", "description" => ".", "url" => "...", "definition" => ".",
      "source_location" => "..", "type" => "macro", "revision_id" => sym_rev2,
      "categories" => [%{"category" => %{"name" => "existent", "url" => "existent"}}]}}}
          = Poison.decode! response.resp_body
    assert sym_id2 === sym_id
    assert sym_rev2 === sym_rev
    assert [%{"user" => %{"username" => "user3", "privilege_level" => 3,
      "name" => "u3", "avatar_url" => "~3"}, "date" => _date, "symbol" => %{"id" => sym_id2,
      "name" => "...2", "description" => ".2", "url" => "...2", "definition" => ".2",
      "source_location" => "..2", "type" => "macro", "revision_id" => sym_rev2,
      "categories" => [%{"category" => %{"name" => "existent", "url" => "existent"}}]}}]
        = updates
    assert sym_id2 === sym_id
    assert sym_rev2 === sym_rev_b

    Neo4j.query!(Neo4j.conn, """
      MATCH (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}})-[r1]-(),
        (s:Symbol {revision_id: #{sym_rev}})-[r2]-()
      DELETE r1, r2, su, s
    """)
  end

  @doc """
  GET /api/symbols/existent?patches=update&patch_id=invalid -H authorization:at3
  """
  test "get an existing symbol's invalid update patch" do
    conn =
      conn(:get, "/api/symbols/0", %{"patches" => "update", "patch_id" => "1"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "The specified symbol update patch could not be found"}}
      = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/existent?patches=update&patch_id=... -H authorization:at3
  """
  test "get an existing symbol's update patch" do
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
          source_location: '..',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s2:UpdateSymbolPatch {
          id: #{sym_id},
          name: '...2',
          description: '.2',
          url: '...2',
          definition: '.2',
          source_location: '..2',
          type: 'macro',
          revision_id: #{sym_rev_b}
        }),
        (s2)-[:CATEGORY]->(c),
        (s2)-[:CONTRIBUTOR]->(u),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}", %{"patches" => "update", "patch_id" => "#{sym_rev_b}"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_update" => %{"update" => update, "symbol" => %{"id" => sym_id2,
      "name" => "...", "description" => ".", "url" => "...", "definition" => ".",
      "source_location" => "..", "type" => "macro", "revision_id" => sym_rev2,
      "categories" => [%{"category" => %{"name" => "existent", "url" => "existent"}}]}}}
        = Poison.decode! response.resp_body
    assert sym_id2 === sym_id
    assert sym_rev2 === sym_rev
    assert %{"user" => %{"username" => "user3", "privilege_level" => 3,
      "name" => "u3", "avatar_url" => "~3"}, "date" => _date, "symbol" => %{"id" => sym_id2,
      "name" => "...2", "description" => ".2", "url" => "...2", "definition" => ".2",
      "source_location" => "..2", "type" => "macro", "revision_id" => sym_rev2,
      "categories" => [%{"category" => %{"name" => "existent", "url" => "existent"}}]}} = update
    assert sym_rev2 === sym_rev_b
    assert sym_id2 === sym_id

    Neo4j.query!(Neo4j.conn, """
      MATCH (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}})-[r1]-(),
        (s:Symbol {revision_id: #{sym_rev}})-[r2]-()
      DELETE r1, r2, su, s
    """)
  end

  @doc """
  GET /api/symbols/existent?patches=all -H authorization:at3
  """
  test "get an existing symbol's patches 1" do
    conn =
      conn(:get, "/api/symbols/0", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_patches" => %{"patches" => %{"updates" => [], "delete" => false},
      "symbol" => %{"id" => 0, "name" => "existent", "description" => "~",
      "url" => "existent", "definition" => "~", "source_location" => "~",
      "type" => "macro", "revision_id" => 123, "categories" => [%{"category" =>
      %{"name" => "existent", "url" => "existent"}}]}}}
        = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/existent?patches=all -H authorization:at3
  """
  test "get an existing symbol's patches 2" do
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
          source_location: '..',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s2:UpdateSymbolPatch {
          id: #{sym_id},
          name: '...2',
          description: '.2',
          url: '...2',
          definition: '.2',
          source_location: '..2',
          type: 'macro',
          revision_id: #{sym_rev_b}
        }),
        (s2)-[:CATEGORY]->(c),
        (s2)-[:CONTRIBUTOR]->(u),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_patches" => %{"symbol" => %{"id" => sym_id2, "name" => "...",
      "description" => ".", "url" => "...", "definition" => ".", "source_location" => "..",
      "type" => "macro", "revision_id" => sym_rev2, "categories" => [%{"category" =>
      %{"name" => "existent", "url" => "existent"}}]}, "patches" => %{"updates" => updates,
      "delete" => false}}} = Poison.decode! response.resp_body
    assert sym_id2 === sym_id
    assert sym_rev2 === sym_rev
    assert [%{"symbol_update" => %{"user" => %{"username" => "user3", "privilege_level" => 3,
      "name" => "u3", "avatar_url" => "~3"}, "date" => _date, "symbol" => %{"id" => sym_id2,
      "name" => "...2", "description" => ".2", "url" => "...2", "definition" => ".2",
      "source_location" => "..2", "type" => "macro", "revision_id" => sym_rev2,
      "categories" => [%{"category" => %{"name" => "existent", "url" => "existent"}}]}}}]
        = updates
    assert sym_id2 === sym_id
    assert sym_rev2 === sym_rev_b

    Neo4j.query!(Neo4j.conn, """
      MATCH (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}})-[r1]-(),
        (s:Symbol {revision_id: #{sym_rev}})-[r2]-()
      DELETE r1, r2, su, s
    """)
  end

  @doc """
  GET /api/symbols/existent?patches=all -H authorization:at3
  """
  test "get an existing symbol's patches 3" do
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
          source_location: '..',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)<-[:DELETE]-(u)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_patches" => %{"symbol" => %{"id" => sym_id2, "name" => "...",
      "description" => ".", "url" => "...", "definition" => ".", "source_location" => "..",
      "type" => "macro", "revision_id" => sym_rev2, "categories" => [%{"category" =>
      %{"name" => "existent", "url" => "existent"}}]}, "patches" => %{"updates" => [],
      "delete" => true}}} = Poison.decode! response.resp_body
    assert sym_id2 === sym_id
    assert sym_rev2 === sym_rev

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}})-[r]-()
      DELETE r, s
    """)
  end

  @doc """
  GET /api/symbols/existent?patches=all -H authorization:at3
  """
  test "get an existing symbol's patches 4" do
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
          source_location: '..',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s2:UpdateSymbolPatch {
          id: #{sym_id},
          name: '...2',
          description: '.2',
          url: '...2',
          definition: '.2',
          source_location: '..2',
          type: 'macro',
          revision_id: #{sym_rev_b}
        }),
        (s2)-[:CATEGORY]->(c),
        (s2)-[:CONTRIBUTOR]->(u),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2),
        (s)<-[:DELETE]-(u)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_patches" => %{"symbol" => %{"id" => sym_id2, "name" => "...",
      "description" => ".", "url" => "...", "definition" => ".", "source_location" => "..",
      "type" => "macro", "revision_id" => sym_rev2, "categories" => [%{"category" =>
      %{"name" => "existent", "url" => "existent"}}]}, "patches" => %{"updates" => updates,
      "delete" => true}}} = Poison.decode! response.resp_body
    assert sym_id2 === sym_id
    assert sym_rev2 === sym_rev
    assert [%{"symbol_update" => %{"user" => %{"username" => "user3", "privilege_level" => 3,
      "name" => "u3", "avatar_url" => "~3"}, "date" => _date, "symbol" => %{"id" => sym_id2,
      "name" => "...2", "description" => ".2", "url" => "...2", "definition" => ".2",
      "source_location" => "..2", "type" => "macro", "revision_id" => sym_rev2,
      "categories" => [%{"category" => %{"name" => "existent", "url" => "existent"}}]}}}]
        = updates
    assert sym_id2 === sym_id
    assert sym_rev2 === sym_rev_b

    Neo4j.query!(Neo4j.conn, """
      MATCH (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}})-[r1]-(),
        (s:Symbol {revision_id: #{sym_rev}})-[r2]-()
      DELETE r1, r2, su, s
    """)
  end
end
