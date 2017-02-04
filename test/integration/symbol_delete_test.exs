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

    assert response.status == 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}} = Poison.decode!(response.resp_body)
  end

  @doc """
  DELETE /api/symbols/non-existent -H authorization: at1
  """
  test "authorised invalid delete patch submission for a non-existent symbol" do
    conn =
      conn(:delete, "/api/symbols/non-existent")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "The specified symbol could not be found"}} = Poison.decode!(response.resp_body)
  end

  @doc """
  DELETE /api/symbols/existent -H authorization: at1
  """
  test "authorised valid delete patch submission for review 1" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '.', type: 'macro', revision_id: #{sym_rev}})-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_name}")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 202
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {revision_id: #{sym_rev}})-[:DELETE]->(:DeleteSymbolPatch) RETURN s")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}})<-[r1:CATEGORY]-(s:Symbol {revision_id: #{sym_rev}})-[r2:DELETE]->(sd:DeleteSymbolPatch)
      DELETE r1, r2, c, s, sd
    """)
  end

  @doc """
  DELETE /api/symbols/existent -H authorization: at3
  """
  test "authorised valid update delete submission for review 2" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '.', type: 'macro', revision_id: #{sym_rev}})-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_name}", %{"review" => "1"})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 202
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {revision_id: #{sym_rev}})-[:DELETE]->(:DeleteSymbolPatch) RETURN s")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}})<-[r1:CATEGORY]-(s:Symbol {revision_id: #{sym_rev}})-[r2:DELETE]->(sd:DeleteSymbolPatch)
      DELETE r1, r2, c, s, sd
    """)
  end

  @doc """
  DELETE /api/symbols/existent -H authorization: at2
  """
  test "authorised valid soft delete patch submission 1" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '.', type: 'macro', revision_id: #{sym_rev}})-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_name}")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 204
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {revision_id: #{sym_rev}}) RETURN s")
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (s:SymbolDeleted {revision_id: #{sym_rev}}) RETURN s")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}})<-[r:CATEGORY]-(s:SymbolDeleted {revision_id: #{sym_rev}})
      DELETE r, c, s
    """)
  end

  @doc """
  DELETE /api/symbols/existent -H authorization: at3
  """
  test "authorised valid soft delete patch submission 2" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '.', type: 'macro', revision_id: #{sym_rev}})-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_name}")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 204
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {revision_id: #{sym_rev}}) RETURN s")
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (s:SymbolDeleted {revision_id: #{sym_rev}}) RETURN s")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}})<-[r:CATEGORY]-(s:SymbolDeleted {revision_id: #{sym_rev}})
      DELETE r, c, s
    """)
  end

  @doc """
  DELETE /api/symbols/existent -H authorization: at3
  """
  test "authorised valid hard delete patch submission" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:SymbolDeleted {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '.', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_name}", %{"mode" => "hard"})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 204
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (s:SymbolDeleted {revision_id: #{sym_rev}}) RETURN s")

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{cat_rev}}) DELETE c")
  end

  @doc """
  DELETE /api/symbols/existent
  """
  test "unauthenticated hard delete patch submission" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:SymbolDeleted {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '.', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_name}", %{"mode" => "hard"})
      |> put_req_header("content-type", "application/json")

    response = Router.call(conn, @opts)

    assert response.status == 401
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (s:SymbolDeleted {revision_id: #{sym_rev}}) RETURN s")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}})<-[r:CATEGORY]-(s:SymbolDeleted {revision_id: #{sym_rev}})
      DELETE r, c, s
    """)
  end

  @doc """
  DELETE /api/symbols/existent -H authorization: at1
  """
  test "unauthorised hard delete patch submission 1" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:SymbolDeleted {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '.', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_name}", %{"mode" => "hard"})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 403
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (s:SymbolDeleted {revision_id: #{sym_rev}}) RETURN s")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}})<-[r:CATEGORY]-(s:SymbolDeleted {revision_id: #{sym_rev}})
      DELETE r, c, s
    """)
  end

  @doc """
  DELETE /api/symbols/existent -H authorization: at2
  """
  test "unauthorised hard delete patch submission 2" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:SymbolDeleted {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '.', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/symbols/#{sym_name}", %{"mode" => "hard"})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 403
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (s:SymbolDeleted {revision_id: #{sym_rev}}) RETURN s")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}})<-[r:CATEGORY]-(s:SymbolDeleted {revision_id: #{sym_rev}})
      DELETE r, c, s
    """)
  end
end
