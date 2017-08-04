defmodule CategoriesPostTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

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
        CREATE (c)-[:CONTRIBUTOR]->(user)
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
    assert %{"error" => %{"message" => "The introduction field should have a length of between 1 and 6000 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/categories -H 'authorization: at3'
  """
  test "invalid category insert (introduction field length > 6000)" do
    data = %{"category" => %{"introduction" => String.duplicate("a", 6_001), "name" => "a"}}

    conn =
      conn(:post, "/api/categories", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The introduction field should have a length of between 1 and 6000 (inclusive)"}}
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
end
