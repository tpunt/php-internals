defmodule CategoryGetTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  GET /api/docs/categories/non-existent
  """
  test "list a non-existent category" do
    conn = conn(:get, "/api/docs/categories/non-existent")
    response = Router.call(conn, @opts)

    assert response.status == 404
  end

  @doc """
  GET /api/docs/categories/existent
  """
  test "list an existing category" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})")

    conn = conn(:get, "/api/docs/categories/#{name}")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) DELETE c")
  end

  @doc """
  GET /api/docs/categories/non-existent?view=overview
  """
  test "list a non-existent category overview" do
    conn = conn(:get, "/api/docs/categories/non-existent", %{"view" => "overview"})
    response = Router.call(conn, @opts)

    assert response.status == 404
  end

  @doc """
  GET /api/docs/categories/existent?view=overview
  """
  test "list an existing category overview" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}'})")

    conn = conn(:get, "/api/docs/categories/#{name}", %{"view" => "overview"})
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert response.resp_body == Poison.encode! %{"category" => %{"name" => "#{name}", "url" => "#{name}"}}

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) DELETE c")
  end

  @doc """
  GET /api/docs/categories/non-existent?view=full
  """
  test "list a non-existent category in full" do
    conn = conn(:get, "/api/docs/categories/non-existent", %{"view" => "full"})
    response = Router.call(conn, @opts)

    assert response.status == 404
  end

  @doc """
  GET /api/docs/categories/existent?view=full
  """
  test "list an existing category in full" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn = conn(:get, "/api/docs/categories/#{cat_name}", %{"view" => "full"})
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category" => %{"name" => cat_name2, "introduction" => "...", "url" => cat_url, "symbols" => symbols, "revision_id" => cat_rev2}} = Poison.decode! response.resp_body
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name
    assert cat_rev2 == cat_rev
    assert [%{"symbol" => %{"name" => sym_name2, "url" => sym_url, "type" => "macro"}}] = symbols
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{cat_rev}})-[r:CATEGORY]->(s:Symbol {revision_id: #{sym_rev}}) DELETE r, c, s")
  end

  @doc """
  GET /api/docs/categories/existent?patches=insert -H 'authorization: at2'
  """
  test "Authorised invalid attempt at listing an existing category insert patch" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (:InsertCategoryPatch {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})")

    conn =
      conn(:get, "/api/docs/categories/#{name}", %{"patches" => "insert"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category_insert" => %{"category" => %{"introduction" => "..."}}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {revision_id: #{rev_id}}) DELETE c")
  end

  @doc """
  GET /api/docs/categories/existent?patches=update -H 'authorization: at2'
  """
  test "Authorised attempt at listing an existing category's update patches" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {
        name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}
      })-[:UPDATE]->(:UpdateCategoryPatch {
        name: '#{name}...', introduction: '.', url: '#{name}...', revision_id: #{rev_id2}, against_revision: #{rev_id}
      })
    """)

    conn =
      conn(:get, "/api/docs/categories/#{name}", %{"patches" => "update"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category_updates" => %{"category" => %{"introduction" => "..."}, "updates" => _updates}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}})-[r:UPDATE]-(c2:UpdateCategoryPatch {revision_id: #{rev_id2}}) DELETE r, c, c2")
  end

  @doc """
  GET /api/docs/categories/non-existent?patches=update -H 'authorization: at2'
  """
  test "Authorised attempt at listing a non-existent category's update patches" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})")

    conn =
      conn(:get, "/api/docs/categories/#{name}", %{"patches" => "update"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "Category update patches not found"}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) DELETE c")
  end

  @doc """
  GET /api/docs/categories/existent?patches=update&patch_id=1 -H 'authorization: at2'
  """
  test "Authorised attempt at listing an existing category's update patch" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {
        name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}
      })-[:UPDATE]->(:UpdateCategoryPatch {
        name: '#{name}...', introduction: '.', url: '#{name}...', revision_id: #{rev_id2}, against_revision: #{rev_id}
      })
    """)

    conn =
      conn(:get, "/api/docs/categories/#{name}", %{"patches" => "update", "patch_id" => "#{rev_id2}"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category_update" => %{"category" => %{"introduction" => "..."}, "update" => %{"category_update" => %{"category" => %{"introduction" => "."}}}}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}})-[r:UPDATE]-(c2:UpdateCategoryPatch {revision_id: #{rev_id2}}) DELETE r, c, c2")
  end

  @doc """
  GET /api/docs/categories/existent?patches=update&patch_id=1 -H 'authorization: at3'
  """
  test "Authorised attempt at listing an existing category's non-existent update patch" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {
        name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}
      })-[:UPDATE]->(:UpdateCategoryPatch {
        name: '#{name}...', introduction: '.', url: '#{name}...', revision_id: #{rev_id2}, against_revision: #{rev_id}
      })
    """)

    conn =
      conn(:get, "/api/docs/categories/#{name}", %{"patches" => "update", "patch_id" => "1"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "Category update patch not found"}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}})-[r:UPDATE]-(c2:UpdateCategoryPatch {revision_id: #{rev_id2}}) DELETE r, c, c2")
  end

  @doc """
  GET /api/docs/categories/existent?patches=delete -H 'authorization: at2'
  """
  test "Authorised attempt at listing an existing category delete patch" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})-[:DELETE]->(:DeleteCategoryPatch)
    """)

    conn =
      conn(:get, "/api/docs/categories/#{name}", %{"patches" => "delete"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category_delete" => %{"category" => %{"introduction" => "..."}}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'})-[r:DELETE]->(c2) DELETE r, c, c2")
  end

  @doc """
  GET /api/docs/categories/non-existent?patches=delete -H 'authorization: at2'
  """
  test "Authorised attempt at listing a non-existent category delete patch" do
    conn =
      conn(:get, "/api/docs/categories/non-existent", %{"patches" => "delete"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "Category not found"}} = Poison.decode! response.resp_body
  end
end
