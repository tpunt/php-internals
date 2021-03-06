defmodule CategoryGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  GET /api/categories/non-existent
  """
  test "list a non-existent category" do
    conn = conn(:get, "/api/categories/non-existent", %{})
    response = Router.call(conn, @opts)

    assert response.status === 404
  end

  @doc """
  GET /api/categories/existent
  """
  test "list an existing category" do
    conn = conn(:get, "/api/categories/existent", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category" => %{"name" => "existent", "introduction" => "~",
      "url" => "existent", "revision_id" => 123, "supercategories" => _superc,
      "subcategories" => _subc}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/categories/non-existent?view=overview
  """
  test "list a non-existent category overview" do
    conn = conn(:get, "/api/categories/non-existent", %{"view" => "overview"})
    response = Router.call(conn, @opts)

    assert response.status === 404
  end

  @doc """
  GET /api/categories/existent?view=overview
  """
  test "list an existing category overview" do
    conn = conn(:get, "/api/categories/existent", %{"view" => "overview"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category" => %{"name" => "existent", "url" => "existent"}}
      = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/categories/existent?patches=insert -H 'authorization: at2'
  """
  test "Authorised invalid attempt at listing an existing category insert patch" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: 3}), (c:Category {url: 'existent'})
      CREATE (icp:InsertCategoryPatch {
          name: '#{name}',
          introduction: '...',
          url: '#{name}',
          revision_id: #{rev_id}
        }),
        (icp)-[:CONTRIBUTOR {type: 'insert', date: 20170810, time: timestamp()}]->(u),
        (c)-[:SUBCATEGORY]->(icp)
    """)

    conn =
      conn(:get, "/api/categories/#{name}", %{"patches" => "insert"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category_insert" => %{"category" => %{"introduction" => "...",
      "subcategories" => [], "supercategories" => [%{"category" => %{"url" => "existent"}}]}}}
        = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:InsertCategoryPatch {revision_id: #{rev_id}})-[r]-()
      DELETE r, c
    """)
  end

  @doc """
  GET /api/categories/existent?patches=update -H 'authorization: at2'
  """
  test "Authorised attempt at listing an existing category's update patches" do
    name = Integer.to_string(:rand.uniform(100_000_000))
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: 3})
      CREATE (c:Category {
          name: '#{name}',
          introduction: '...',
          url: '#{name}',
          revision_id: #{rev_id}
        }),
        (ucp:UpdateCategoryPatch {
          name: '#{name}...',
          introduction: '.',
          url: '#{name}...',
          revision_id: #{rev_id2},
          against_revision: #{rev_id}
        }),
        (c)-[:UPDATE]->(ucp),
        (ucp)-[:CONTRIBUTOR {type: 'insert', date: 20170810, time: timestamp()}]->(u)
    """)

    conn =
      conn(:get, "/api/categories/#{name}", %{"patches" => "update"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category_updates" => %{"category" => %{"name" => ^name, "url" => ^name},
      "updates" => _updates}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}})-[r1]-(),
        (ucp:UpdateCategoryPatch {revision_id: #{rev_id2}})-[r2]-()
      DELETE r1, r2, c, ucp
    """)
  end

  @doc """
  GET /api/categories/existent?patches=update -H 'authorization: at2'
  """
  test "Authorised attempt at listing a existing category's non-existent update patches" do
    name = Integer.to_string(:rand.uniform(100_000_000))
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})")

    conn =
      conn(:get, "/api/categories/#{name}", %{"patches" => "update"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category_updates" => %{"category" => %{"name" => ^name, "url" => ^name},
      "updates" => []}} = Poison.decode! response.resp_body

    conn =
      conn(:get, "/api/categories/#{name}/updates", %{})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category_updates" => %{"category" => %{"name" => ^name, "url" => ^name},
      "updates" => []}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) DELETE c")
  end

  @doc """
  GET /api/categories/existent?patches=update&patch_id=1 -H 'authorization: at2'
  """
  test "Authorised attempt at listing an existing category's update patch" do
    name = Integer.to_string(:rand.uniform(100_000_000))
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: 3})
      CREATE (c:Category {
          name: '#{name}',
          introduction: '...',
          url: '#{name}',
          revision_id: #{rev_id}
        }),
        (ucp:UpdateCategoryPatch {
          name: '#{name}...',
          introduction: '.',
          url: '#{name}...',
          revision_id: #{rev_id2},
          against_revision: #{rev_id}
        }),
        (c)-[:UPDATE]->(ucp),
        (ucp)-[:CONTRIBUTOR {type: 'insert', date: 20170810, time: timestamp()}]->(u)
    """)

    conn =
      conn(:get, "/api/categories/#{name}", %{"patches" => "update", "patch_id" => "#{rev_id2}"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category_update" => %{"category" => %{"name" => ^name, "url" => ^name},
    "update" => %{"category" => %{"introduction" => "."}, "date" => _date, "user" => _user}}}
        = Poison.decode! response.resp_body

    conn =
      conn(:get, "/api/categories/#{name}/updates/#{rev_id2}", %{})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category_update" => %{"category" => %{"name" => ^name, "url" => ^name},
    "update" => %{"category" => %{"introduction" => "."}, "date" => _date, "user" => _user}}}
        = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}})-[r1]-(),
        (ucp:UpdateCategoryPatch {revision_id: #{rev_id2}})-[r2]-()
      DELETE r1, r2, c, ucp
    """)
  end

  @doc """
  GET /api/categories/existent?patches=update&patch_id=1 -H 'authorization: at3'
  """
  test "Authorised attempt at listing an existing category's non-existent update patch" do
    conn =
      conn(:get, "/api/categories/existent", %{"patches" => "update", "patch_id" => "1"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Category revision not found"}}
      = Poison.decode! response.resp_body

    conn =
      conn(:get, "/api/categories/existent/updates/1", %{})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Category revision not found"}}
      = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/categories/existent/revisions -H 'authorization: at2'
  """
  test "Authorised attempt at listing an existing category's non-existent revisions" do
    name = Integer.to_string(:rand.uniform(100_000_000))
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)

    conn =
      conn(:get, "/api/categories/#{name}/revisions", %{})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category_revisions" => %{"category" => %{"name" => ^name, "url" => ^name},
      "revisions" => []}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) DELETE c")
  end

  @doc """
  GET /api/categories/existent/revisions/1 -H 'authorization: at2'
  """
  test "Authorised attempt at listing an existing category's revision" do
    name = Integer.to_string(:rand.uniform(100_000_000))
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: 3})
      CREATE (c:Category {
          name: '#{name}',
          introduction: '...',
          url: '#{name}',
          revision_id: #{rev_id}
        }),
        (cr:CategoryRevision {
          name: '#{name}...',
          introduction: '.',
          url: '#{name}...',
          revision_id: #{rev_id2}
        }),
        (c)-[:REVISION]->(cr),
        (cr)-[:CONTRIBUTOR {type: 'insert', date: 20170810, time: timestamp()}]->(u)
    """)

    conn =
      conn(:get, "/api/categories/#{name}/revisions/#{rev_id2}", %{})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category_revision" => %{"category" => %{"name" => ^name, "url" => ^name},
      "revision" => %{"category" => %{"introduction" => "."}, "date" => 20170810, "user" => _user}}}
        = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}})-[r1]-(),
        (cr:CategoryRevision {revision_id: #{rev_id2}})-[r2]-()
      DELETE r1, r2, c, cr
    """)
  end

  @doc """
  GET /api/categories/existent/revisions/1 -H 'authorization: at3'
  """
  test "Authorised attempt at listing an existing category's non-existent revision" do
    conn =
      conn(:get, "/api/categories/existent/revisions/1", %{})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Category revision not found"}}
      = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/categories/existent?patches=delete -H 'authorization: at2'
  """
  test "Authorised attempt at listing an existing category delete patch" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at1'})
      CREATE (c:Category {
          name: '#{name}',
          introduction: '...',
          url: '#{name}',
          revision_id: #{rev_id}
        }),
        (c)<-[:DELETE]-(u)
    """)

    conn =
      conn(:get, "/api/categories/#{name}", %{"patches" => "delete"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category_delete" => %{"category" => %{"introduction" => "..."}}}
      = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'})-[r]->() DELETE r, c")
  end

  @doc """
  GET /api/categories/non-existent?patches=delete -H 'authorization: at2'
  """
  test "Authorised attempt at listing a non-existent category delete patch" do
    conn =
      conn(:get, "/api/categories/non-existent", %{"patches" => "delete"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Category not found"}} = Poison.decode! response.resp_body
  end
end
