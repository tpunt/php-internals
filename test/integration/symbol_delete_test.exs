defmodule SymbolDeleteTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  DELETE /api/symbols/non-existent
  """
  test "unauthorised delete patch submission" do
    conn = conn(:delete, "/api/symbols/non-existent")
    response = Router.call(conn, @opts)

    assert response.status === 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}} = Poison.decode!(response.resp_body)
  end

  @doc """
  DELETE /api/symbols/non-existent -H authorization: at1
  """
  test "authorised invalid delete patch submission for a non-existent symbol" do
    conn =
      conn(:delete, "/api/symbols/0123")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "The specified symbol could not be found"}} = Poison.decode!(response.resp_body)
  end

  @doc """
  DELETE /api/symbols/non-existent-invalid -H authorization: at1
  """
  test "authorised invalid delete patch submission for an invalid, non-existent symbol ID" do
    conn =
      conn(:delete, "/api/symbols/non-existent-invalid")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Invalid integer ID given"}} = Poison.decode!(response.resp_body)
  end

  @doc """
  DELETE /api/symbols/existent -H authorization: at1
  """
  test "authorised valid delete patch submission for review 1" do
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
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_id}")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 202
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (s)-[:DELETE]->(dsp:DeleteSymbolPatch),
        (s)-[:CONTRIBUTOR {type: 'delete'}]->(:User {access_token: 'at1'})
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}})-[r1]-(),
        (s)-[r2:DELETE]->(sd:DeleteSymbolPatch)
      DELETE r1, r2, s, sd
    """)
  end

  @doc """
  DELETE /api/symbols/existent -H authorization: at3
  """
  test "authorised valid update delete submission for review 2" do
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
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_id}", %{"review" => "1"})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 202
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (s)-[:DELETE]->(dsp:DeleteSymbolPatch),
        (s)-[:CONTRIBUTOR {type: 'delete'}]->(:User {access_token: 'at3'})
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}})-[r1]-(),
        (s)-[r2:DELETE]->(sd:DeleteSymbolPatch)
      DELETE r1, r2, s, sd
    """)
  end

  @doc """
  DELETE /api/symbols/existent -H authorization: at2
  """
  test "authorised valid soft delete patch submission 1" do
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
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_id}")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 204
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (sd:SymbolDeleted {revision_id: #{sym_rev}}),
        (sd)-[:CONTRIBUTOR {type: 'delete'}]->(:User {access_token: 'at2'})
      RETURN sd
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (sd:SymbolDeleted {revision_id: #{sym_rev}})-[r]-()
      DELETE r, sd
    """)
  end

  @doc """
  DELETE /api/symbols/existent -H authorization: at3
  """
  test "authorised valid soft delete patch submission 2" do
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
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_id}")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 204
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (sd:SymbolDeleted {revision_id: #{sym_rev}}),
        (sd)-[:CONTRIBUTOR {type: 'delete'}]->(:User {access_token: 'at3'})
      RETURN sd
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (sd:SymbolDeleted {revision_id: #{sym_rev}})-[r]-()
      DELETE r, sd
    """)
  end

  @doc """
  DELETE /api/symbols/... -H 'authorization: ...'
  """
  test "Authorised invalid attempt at deleting a symbol (patch limit reached)" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (user:User {username: '#{name}', access_token: '#{name}', privilege_level: 1}),
        (c:UpdateCategoryPatch)
      FOREACH (ignored in RANGE(1, 20) |
        CREATE (c)-[:CONTRIBUTOR]->(user)
      )
    """)

    conn =
      conn(:delete, "/api/symbols/...")
      |> put_req_header("authorization", "#{name}")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The maximum patch limit (20) has been exceeded!"}}
      = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (u:User {username: '#{name}'})-[r]-(c) DELETE r, u, c")
  end
end
