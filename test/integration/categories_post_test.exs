defmodule CategoriesPostTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  POST /api/categories
  """
  test "Unauthenticated attempt at inserting a new category" do
    conn =
      conn(:post, "/api/categories", %{"category" => %{"name": ".", "introduction": "..."}})
      |> put_req_header("content-type", "application/json")

    response = Router.call(conn, @opts)

    assert response.status === 401
  end

  @doc """
  POST /api/categories -H 'authorization: at1'
  """
  test "Authorised attempt 1 at inserting a new category patch" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/categories", %{"category" => %{"name": "#{name}", "introduction": "..."}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 202
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:InsertCategoryPatch {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at1'})
      RETURN c
    """)

    conn = conn(:get, "/api/categories/#{name}", %{})
    response = Router.call(conn, @opts)

    assert response.status === 404

    Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {name: '#{name}'})-[r]-() DELETE r, c")
  end

  @doc """
  POST /api/categories?review=1 -H 'authorization: at2'
  """
  test "Authorised attempt 2 at inserting a new category patch" do
    name = :rand.uniform(100_000_000)
    data = %{"category" => %{"name": "#{name}", "introduction": "..."}, "review" => "1"}
    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 202
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:InsertCategoryPatch {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at2'})
      RETURN c
    """)

    conn = conn(:get, "/api/categories/#{name}", %{})
    response = Router.call(conn, @opts)

    assert response.status === 404

    Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {name: '#{name}'})-[r]-() DELETE r, c")
  end

  @doc """
  POST /api/categories?review=1 -H 'authorization: at3'
  """
  test "Authorised attempt 3 at inserting a new category patch" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/categories", %{"category" => %{"name": "#{name}", "introduction": "..."}, "review" => "1"})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 202
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:InsertCategoryPatch {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at3'})
      RETURN c
    """)

    conn = conn(:get, "/api/categories/#{name}", %{})
    response = Router.call(conn, @opts)

    assert response.status === 404

    Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {name: '#{name}'})-[r]-() DELETE r, c")
  end

  @doc """
  POST /api/categories?review=1 -H 'authorization: at3'
  """
  test "Authorised invalid attempt at inserting a new category patch (missing name field)" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/categories", %{"category" => %{"introduction": "..."}, "review" => "1"})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Required fields are missing (expecting: name, introduction)"}}
      = Poison.decode!(response.resp_body)
    assert [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c {name: '#{name}'})
      WHERE HEAD(LABELS(c)) IN ['Category', 'InsertCategoryPatch']
      RETURN c
    """)
  end

  @doc """
  POST /api/categories -H 'authorization: at2'
  """
  test "Authorised attempt 1 at inserting a new category" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/categories", %{"category" => %{"name": "#{name}", "introduction": "..."}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 201
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at2'})
      RETURN c
    """)

    conn = conn(:get, "/api/categories/#{name}", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'})-[r]-() DELETE r, c")
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "Authorised attempt 2 at inserting a new category" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/categories", %{"category" => %{"name": "#{name}", "introduction": "..."}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 201
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at3'})
      RETURN c
    """)

    conn = conn(:get, "/api/categories/#{name}", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'})-[r]-() DELETE r, c")
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "Authorised attempt 3 at inserting a new category (with subcategories)" do
    name = :rand.uniform(100_000_000)
    data = %{"category" => %{"name": "#{name}", "introduction": "...", "subcategories": ["existent"]}}
    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 201
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at3'}),
        (c)-[:SUBCATEGORY]->(:Category {name: 'existent'})
      RETURN c
    """)

    conn = conn(:get, "/api/categories/#{name}", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'})-[r]-() DELETE r, c")
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "Authorised attempt 4 at inserting a new category (with supercategories)" do
    name = :rand.uniform(100_000_000)
    data = %{"category" => %{"name": "#{name}", "introduction": "...", "supercategories": ["existent"]}}
    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 201
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at3'}),
        (:Category {name: 'existent'})-[:SUBCATEGORY]->(c)
      RETURN c
    """)

    conn = conn(:get, "/api/categories/#{name}", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'})-[r]-() DELETE r, c")
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "Authorised invalid attempt at inserting a new category (same subcategories and supercategories)" do
    name = :rand.uniform(100_000_000)
    data = %{"category" => %{"name": "#{name}", "introduction": "...",
      "subcategories": ["existent"], "supercategories": ["existent"]}}
    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "A category may not have the same category in its super and sub categories"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "Authorised invalid attempt at inserting a new category (missing introduction field)" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/categories", %{"category" => %{"name": "#{name}"}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Required fields are missing (expecting: name, introduction)"}}
      = Poison.decode!(response.resp_body)
    assert [] === Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) RETURN c")
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "Authorised invalid attempt at inserting a new category (category already exists)" do
    conn =
      conn(:post, "/api/categories", %{"category" => %{"name": "existent", "introduction": "..."}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The category with the specified name already exists"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/categories -H 'authorization: ...'
  """
  test "Authorised invalid attempt at inserting a new category (patch limit reached)" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (user:User {username: '#{name}', access_token: '#{name}', privilege_level: 1}),
        (c:UpdateCategoryPatch)
      FOREACH (ignored in RANGE(1, 20) |
        CREATE (c)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(user)
      )
    """)

    conn =
      conn(:post, "/api/categories", %{"category" => %{}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "#{name}")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The maximum patch limit (20) has been exceeded!"}}
      = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (u:User {username: '#{name}'})<-[r]-(c) DELETE r, u, c")
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "invalid category insert (name field length < 1)" do
    data = %{"category" => %{"introduction" => "...", "name" => ""}}

    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The name field should have a length of between 1 and 50 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "invalid category insert (name field length > 50)" do
    data = %{"category" => %{"introduction" => "...", "name" => String.duplicate("a", 51)}}

    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The name field should have a length of between 1 and 50 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "invalid category insert (introduction field length < 1)" do
    data = %{"category" => %{"introduction" => "", "name" => "a"}}

    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The introduction field should have a length of between 1 and 15000 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "invalid category insert (introduction field length > 15000)" do
    data = %{"category" => %{"introduction" => String.duplicate("a", 15_001), "name" => "a"}}

    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The introduction field should have a length of between 1 and 15000 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "Authorised invalid attempt at inserting a new category (duplicate subcategories)" do
    name = :rand.uniform(100_000_000)
    data = %{"category" => %{"name": "#{name}", "introduction": "...",
      "subcategories": ["existent", "existent"]}}
    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Duplicate subcategory names given"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "Authorised invalid attempt at inserting a new category (duplicate supercategories)" do
    name = :rand.uniform(100_000_000)
    data = %{"category" => %{"name": "#{name}", "introduction": "...",
      "supercategories": ["existent", "existent"]}}
    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Duplicate supercategory names given"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "Authorised insert category (cache invalidation test)" do
    name = Integer.to_string(:rand.uniform(100_000_000))
    name2 = Integer.to_string(:rand.uniform(100_000_000))
    name3 = Integer.to_string(:rand.uniform(100_000_000))
    Neo4j.query!(Neo4j.conn, """
      CREATE (c2:Category {name: '#{name2}', introduction: '..', url: '#{name2}'})
      CREATE (c3:Category {name: '#{name3}', introduction: '...', url: '#{name3}'})
    """)

    # prime the caches
    response = Router.call(conn(:get, "/api/categories/#{name2}", %{}), @opts)
    assert response.status === 200
    assert %{"category" => %{"name" => ^name2, "introduction" => "..",
      "url" => ^name2, "supercategories" => [], "subcategories" => []}}
        = Poison.decode!(response.resp_body)

    response = Router.call(conn(:get, "/api/categories/#{name3}", %{}), @opts)
    assert response.status === 200
    assert %{"category" => %{"name" => ^name3, "introduction" => "...",
      "url" => ^name3, "supercategories" => [], "subcategories" => []}}
        = Poison.decode!(response.resp_body)

    data = %{"category" => %{"name" => "#{name}", "introduction" => ".",
      "supercategories" => [name3], "subcategories" => [name2]}}
    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 201
    assert %{"category" => %{"name" => ^name, "introduction" => ".",
      "url" => ^name, "supercategories" => [%{"category" => %{"name" => ^name3}}],
      "subcategories" => [%{"category" => %{"name" => ^name2}}]}}
        = Poison.decode!(response.resp_body)

    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at3'}),
        (:Category {name: '#{name3}'})-[:SUBCATEGORY]->(c),
        (c)-[:SUBCATEGORY]->(:Category {name: '#{name2}'})
      RETURN c
    """)

    response = Router.call(conn(:get, "/api/categories/#{name2}", %{}), @opts)
    assert response.status === 200
    assert %{"category" => %{"name" => ^name2, "introduction" => "..",
      "url" => ^name2, "supercategories" => [%{"category" => %{"name" => ^name}}],
      "subcategories" => []}}
        = Poison.decode!(response.resp_body)

    response = Router.call(conn(:get, "/api/categories/#{name3}", %{}), @opts)
    assert response.status === 200
    assert %{"category" => %{"name" => ^name3, "introduction" => "...",
      "url" => ^name3, "supercategories" => [],
      "subcategories" => [%{"category" => %{"name" => ^name}}]}}
        = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[r1:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at3'}),
        (c3:Category {name: '#{name3}'})-[r2:SUBCATEGORY]->(c),
        (c)-[r3:SUBCATEGORY]->(c2:Category {name: '#{name2}'})
      DELETE r1, r2, r3, c, c2, c3
    """)
  end

  @doc """
  POST /api/categories -H 'authorization: at1'
  """
  test "Authorised insert category patch and apply (cache invalidation test)" do
    name = Integer.to_string(:rand.uniform(100_000_000))
    name2 = Integer.to_string(:rand.uniform(100_000_000))
    name3 = Integer.to_string(:rand.uniform(100_000_000))
    Neo4j.query!(Neo4j.conn, """
      CREATE (c2:Category {name: '#{name2}', introduction: '..', url: '#{name2}'})
      CREATE (c3:Category {name: '#{name3}', introduction: '...', url: '#{name3}'})
    """)

    # prime the caches
    response = Router.call(conn(:get, "/api/categories/#{name2}", %{}), @opts)
    assert response.status === 200
    assert %{"category" => %{"name" => ^name2, "introduction" => "..",
      "url" => ^name2, "supercategories" => [], "subcategories" => []}}
        = Poison.decode!(response.resp_body)

    response = Router.call(conn(:get, "/api/categories/#{name3}", %{}), @opts)
    assert response.status === 200
    assert %{"category" => %{"name" => ^name3, "introduction" => "...",
      "url" => ^name3, "supercategories" => [], "subcategories" => []}}
        = Poison.decode!(response.resp_body)

    data = %{"category" => %{"name" => "#{name}", "introduction" => ".",
      "supercategories" => [name3], "subcategories" => [name2]}}
    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 202

    response = Router.call(conn(:get, "/api/categories/#{name}", %{}), @opts)
    assert response.status === 404

    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:InsertCategoryPatch {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at1'}),
        (:Category {name: '#{name3}'})-[:SUBCATEGORY]->(c),
        (c)-[:SUBCATEGORY]->(:Category {name: '#{name2}'})
      RETURN c
    """)

    conn =
      conn(:patch, "/api/categories/#{name}?apply_patch=insert", %{})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)
    assert response.status === 200
    assert %{"category" => %{"name" => ^name, "introduction" => ".",
      "url" => ^name, "supercategories" => [%{"category" => %{"name" => ^name3}}],
      "subcategories" => [%{"category" => %{"name" => ^name2}}]}}
        = Poison.decode!(response.resp_body)

    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at1'}),
        (c)-[:CONTRIBUTOR {type: 'apply_insert'}]->(:User {access_token: 'at3'}),
        (:Category {name: '#{name3}'})-[:SUBCATEGORY]->(c),
        (c)-[:SUBCATEGORY]->(:Category {name: '#{name2}'})
      RETURN c
    """)

    response = Router.call(conn(:get, "/api/categories/#{name2}", %{}), @opts)
    assert response.status === 200
    assert %{"category" => %{"name" => ^name2, "introduction" => "..",
      "url" => ^name2, "supercategories" => [%{"category" => %{"name" => ^name}}],
      "subcategories" => []}}
        = Poison.decode!(response.resp_body)

    response = Router.call(conn(:get, "/api/categories/#{name3}", %{}), @opts)
    assert response.status === 200
    assert %{"category" => %{"name" => ^name3, "introduction" => "...",
      "url" => ^name3, "supercategories" => [],
      "subcategories" => [%{"category" => %{"name" => ^name}}]}}
        = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[r1:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at3'}),
        (c3:Category {name: '#{name3}'})-[r2:SUBCATEGORY]->(c),
        (c)-[r3:SUBCATEGORY]->(c2:Category {name: '#{name2}'})
      DELETE r1, r2, r3, c, c2, c3
    """)
  end
end
