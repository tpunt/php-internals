defmodule CategoryPatchTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  test "Unauthenticated non-existent category patch" do
    conn = conn(:patch, "/api/categories/non-existent")
    response = Router.call(conn, @opts)

    assert response.status === 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}} = Poison.decode! response.resp_body
  end

  test "Authorised non-existent category patch" do
    data = %{"category" => %{"name" => ".", "introduction" => "."}, "revision_id" => 1}
    conn =
      conn(:patch, "/api/categories/non-existent", data)
      |> put_req_header("authorization", "at1")
    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Category not found"}} = Poison.decode! response.resp_body
  end

  test "Authorised update existing category review 1" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)
    data = %{"category" => %{"name" => "#{name}", "introduction" => "."}, "revision_id" => rev_id}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at1")
    response = Router.call(conn, @opts)

    assert response.status === 202
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (c)-[:UPDATE]->(ucp:UpdateCategoryPatch {against_revision: #{rev_id}}),
        (ucp)-[:CONTRIBUTOR {type: 'update'}]->(:User {access_token: 'at1'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}})-[r1]-(),
        (c)-[:UPDATE]->(ucp:UpdateCategoryPatch)-[r2]-()
      DELETE r1, r2, c, ucp
    """)
  end

  test "Authorised update existing category review 2" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)
    data = %{"review" => "1", "category" => %{"name" => "#{name}", "introduction" => "."}, "revision_id" => rev_id}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)

    assert response.status === 202
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
      refute [] === Neo4j.query!(Neo4j.conn, """
        MATCH (c:Category {revision_id: #{rev_id}}),
          (c)-[:UPDATE]->(ucp:UpdateCategoryPatch {against_revision: #{rev_id}}),
          (ucp)-[:CONTRIBUTOR {type: 'update'}]->(:User {access_token: 'at2'})
        RETURN c
      """)

      Neo4j.query!(Neo4j.conn, """
        MATCH (c:Category {revision_id: #{rev_id}})-[r1]-(),
          (c)-[:UPDATE]->(ucp:UpdateCategoryPatch)-[r2]-()
        DELETE r1, r2, c, ucp
      """)
  end

  test "Authorised update existing category review 3" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)
    data = %{"review" => "1", "category" => %{"name" => "#{name}", "introduction" => "."}, "revision_id" => rev_id}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 202
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
      refute [] === Neo4j.query!(Neo4j.conn, """
        MATCH (c:Category {revision_id: #{rev_id}}),
          (c)-[:UPDATE]->(ucp:UpdateCategoryPatch {against_revision: #{rev_id}}),
          (ucp)-[:CONTRIBUTOR {type: 'update'}]->(:User {access_token: 'at3'})
        RETURN c
      """)

      Neo4j.query!(Neo4j.conn, """
        MATCH (c:Category {revision_id: #{rev_id}})-[r1]-(),
          (c)-[:UPDATE]->(ucp:UpdateCategoryPatch)-[r2]-()
        DELETE r1, r2, c, ucp
      """)
  end

  test "Authorised update existing category review 4" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at2'})

      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (cp:UpdateCategoryPatch {
          name: '#{name}.#{name}',
          introduction: '.',
          url: '#{name}.#{name}',
          revision_id: #{rev_id2},
          against_revision: #{rev_id}
        }),
        (c)-[:UPDATE]->(cp),
        (c)-[:CONTRIBUTOR {type: "insert", date: 1, time: 3}]->(u),
        (cp)-[:CONTRIBUTOR {type: "update", date: 2, time: 4}]->(u)
    """)
    data = %{"review" => "1", "references_patch" => "#{rev_id2}", "category" =>
      %{"name" => "#{name}.", "introduction" => "....."}, "revision_id" => rev_id2}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 202
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (c)-[r1:UPDATE]->(ucp:UpdateCategoryPatch),
        (ucp)-[r2:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision {revision_id: #{rev_id2}}),
        (ucp)-[r3:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at3'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (c)-[r1:UPDATE]->(ucp:UpdateCategoryPatch),
        (c)-[r2:CONTRIBUTOR {type: "insert"}]->(:User {access_token: 'at2'}),
        (ucp)-[r3:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision),
        (ucpr)-[r4:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at2'}),
        (ucp)-[r5:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at3'})
      DELETE r1, r2, r3, r4, r5, c, ucp, ucpr
    """)
  end

  test "Unauthorised update existing category review" do
    data = %{"review" => "1", "references_patch" => "1", "category" =>
      %{"name" => "...", "introduction" => "....."}, "revision_id" => 1}

    conn =
      conn(:patch, "/api/categories/existent", data)
      |> put_req_header("authorization", "at1")
    response = Router.call(conn, @opts)

    assert response.status === 403
  end

  test "Authorised update existing category 1 (without subcategories)" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at2'})

      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (c)-[:CONTRIBUTOR {type: "insert", date: 1, time: 2}]->(u)
    """)
    data = %{"category" => %{"name" => "#{name}", "introduction" => "."}, "revision_id" => rev_id}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category" => %{"name" => _, "introduction" => ".", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[r1:REVISION]->(cr:CategoryRevision {revision_id: #{rev_id}}),
        (c)-[r2:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at2'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[r1:REVISION]-(cr:CategoryRevision {revision_id: #{rev_id}}),
        (c)-[r2:CONTRIBUTOR {type: "update"}]->(),
        (c)-[r3:CONTRIBUTOR {type: "insert"}]->()
      DELETE r1, r2, r3, c, cr
    """)
  end

  test "Authorised update existing category 2 (with subcategories)" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at2'})

      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (c)-[:CONTRIBUTOR {type: "insert", date: 1, time: 2}]->(u)
    """)
    data = %{"category" => %{"name" => "#{name}", "introduction" => ".", "subcategories" => ["existent"]},
      "revision_id" => rev_id}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category" => %{"name" => _, "introduction" => ".", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[:REVISION]->(cr:CategoryRevision {revision_id: #{rev_id}}),
        (cr)-[:CONTRIBUTOR {type: "insert", date: 1, time: 2}]->(:User {access_token: 'at2'}),
        (c)-[:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at3'}),
        (c)-[:SUBCATEGORY]->(:Category {name: 'existent'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[r1:REVISION]-(cr:CategoryRevision {revision_id: #{rev_id}}),
        (cr)-[r2:CONTRIBUTOR {type: "insert", date: 1, time: 2}]->(:User {access_token: 'at2'}),
        (c)-[r3:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at3'}),
        (c)-[r4:SUBCATEGORY]->(:Category {name: 'existent'})
      DELETE r1, r2, r3, r4, c, cr
    """)
  end

  test "Authorised update existing category 3 (without subcategories)" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at2'})

      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (cp:UpdateCategoryPatch {
          name: '#{name}.#{name}',
          introduction: '.',
          url: '#{name}.#{name}',
          revision_id: #{rev_id2},
          against_revision: #{rev_id}
        }),
        (c)-[:UPDATE]->(cp),
        (c)-[:CONTRIBUTOR {type: "insert", date: 1, time: 3}]->(u),
        (cp)-[:CONTRIBUTOR {type: "update", date: 2, time: 4}]->(u)
    """)
    data = %{"references_patch" => "#{rev_id2}", "category" =>
      %{"name" => "#{name}.", "introduction" => ".."}, "revision_id" => rev_id2}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category" => %{"name" => _, "introduction" => "..", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}.'}),
        (c)-[:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision {revision_id: #{rev_id2}}),
        (c)-[:REVISION]->(cr:CategoryRevision {revision_id: #{rev_id}}),
        (c)-[:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at3'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}.'}),
        (c)-[r1:CONTRIBUTOR {type: "insert"}]->(:User {access_token: 'at2'}),
        (c)-[r2:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision {revision_id: #{rev_id2}}),
        (ucpr)-[r3:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at2'}),
        (c)-[r4:REVISION]->(cr:CategoryRevision {revision_id: #{rev_id}}),
        (c)-[r5:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at3'})
      DELETE r1, r2, r3, r4, r5, c, ucpr, cr
    """)
  end

  test "Authorised update existing category 4 (with subcategories)" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at2'})

      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (cp:UpdateCategoryPatch {
          name: '#{name}.#{name}',
          introduction: '.',
          url: '#{name}.#{name}',
          revision_id: #{rev_id2},
          against_revision: #{rev_id}
        }),
        (c)-[:UPDATE]->(cp),
        (c)-[:CONTRIBUTOR {type: "insert", date: 1, time: 3}]->(u),
        (cp)-[:CONTRIBUTOR {type: "update", date: 2, time: 4}]->(u)
    """)
    data = %{"references_patch" => "#{rev_id2}", "category" =>
      %{"name" => "#{name}.", "introduction" => "..", "subcategories" => ["existent"]},
        "revision_id" => rev_id2}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category" => %{"name" => _, "introduction" => "..", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}.'}),
        (c)-[:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision {revision_id: #{rev_id2}}),
        (c)-[:REVISION]->(cr:CategoryRevision {revision_id: #{rev_id}}),
        (c)-[:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at3'}),
        (c)-[:SUBCATEGORY]->(:Category {name: 'existent'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}.'}),
        (c)-[r1:CONTRIBUTOR {type: "insert"}]->(:User {access_token: 'at2'}),
        (c)-[r2:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision {revision_id: #{rev_id2}}),
        (ucpr)-[r3:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at3'}),
        (c)-[r4:REVISION]->(cr:CategoryRevision {revision_id: #{rev_id}}),
        (c)-[r5:CONTRIBUTOR {type: "update"}]->(:User {access_token: 'at3'}),
        (c)-[r6:SUBCATEGORY]->(:Category {name: 'existent'})
      DELETE r1, r2, r3, r4, r5, r6, c, ucpr, cr
    """)
  end

  test "Unauthorised update existing category" do
    data = %{"references_patch" => "1", "category" => %{"name" => "...", "introduction" => "."},
      "revision_id" => 1}

    conn =
      conn(:patch, "/api/categories/existent", data)
      |> put_req_header("authorization", "at1")
    response = Router.call(conn, @opts)

    assert response.status === 403
  end

  test "Authorised insert category patch apply 1" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at2'})

      CREATE (c:InsertCategoryPatch {
          name: '#{name}',
          introduction: '...',
          url: '#{name}',
          revision_id: #{rev_id}
        }),
        (c)-[:CONTRIBUTOR {type: "insert", date: 1, time: 2}]->(u)
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "insert"})
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (c)-[r:CONTRIBUTOR {type: 'apply_insert'}]->(:User {access_token: 'at2'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[r1:CONTRIBUTOR {type: "insert", date: 1, time: 2}]->(:User {access_token: 'at2'}),
        (c)-[r2:CONTRIBUTOR {type: 'apply_insert'}]->(:User {access_token: 'at2'})
      DELETE r1, r2, c
    """)
  end

  test "Authorised insert category patch apply 2" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at2'})

      CREATE (c:InsertCategoryPatch {
          name: '#{name}',
          introduction: '...',
          url: '#{name}',
          revision_id: #{rev_id}
        }),
        (c)-[:CONTRIBUTOR {type: "insert", date: 1, time: 2}]->(u)
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "insert"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (c)-[r:CONTRIBUTOR {type: 'apply_insert'}]->(:User {access_token: 'at3'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[r1:CONTRIBUTOR {type: 'insert'}]->(),
        (c)-[r2:CONTRIBUTOR {type: 'apply_insert'}]->()
      DELETE r1, r2, c
    """)
  end

  test "Authorised invalid insert category patch apply 1" do
    conn =
      conn(:patch, "/api/categories/existent", %{"apply_patch" => "insert"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Insert patch not found"}} = Poison.decode! response.resp_body
  end

  test "Authorised invalid insert category patch apply 2" do
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:InsertCategoryPatch {name: 'existent', introduction: '.', url: 'existent', revision_id: #{rev_id}})
    """)

    conn =
      conn(:patch, "/api/categories/existent", %{"apply_patch" => "insert"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "A category with the same name already exists"}}
      = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, """
      MATCH (icp:InsertCategoryPatch {revision_id: #{rev_id}})
      DELETE icp
    """)
  end

  test "Authorised update existing category patch apply" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at2'})

      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (ucp:UpdateCategoryPatch {
          name: '#{name}.#{name}',
          introduction: '.',
          url: '#{name}.#{name}',
          revision_id: #{rev_id2},
          against_revision: #{rev_id}
        }),
        (c)-[:UPDATE]->(ucp),
        (c)-[:CONTRIBUTOR {type: "insert", date: 1, time: 3}]->(u),
        (ucp)-[:CONTRIBUTOR {type: "update", date: 2, time: 4}]->(u)
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "update,#{rev_id2}"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category" => %{"name" => _, "introduction" => ".", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    assert [] === Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {revision_id: #{rev_id2}}) RETURN c")
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {revision_id: #{rev_id2}}),
        (c1)-[:REVISION]->(c2:CategoryRevision {revision_id: #{rev_id}}),
        (c1)-[r:CONTRIBUTOR {type: 'apply_update'}]->(:User {access_token: 'at3'})
      RETURN c2
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {revision_id: #{rev_id2}}),
        (c1)-[r1:REVISION]->(c2:CategoryRevision {revision_id: #{rev_id}}),
        (c2)-[r2:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at2'}),
        (c1)-[r3:CONTRIBUTOR {type: 'update'}]->(:User {access_token: 'at2'}),
        (c1)-[r4:CONTRIBUTOR {type: 'apply_update'}]->(:User {access_token: 'at3'})
      DELETE r1, r2, r3, r4, c1, c2
    """)
  end

  test "Authorised invalid update existing category patch apply 1" do
    conn =
      conn(:patch, "/api/categories/non-existent", %{"apply_patch" => "update,1"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Category not found"}} = Poison.decode! response.resp_body
  end

  test "Authorised invalid update existing category patch apply 2" do
    conn =
      conn(:patch, "/api/categories/existent", %{"apply_patch" => "update,1"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Update patch not found for the specified category"}}
      = Poison.decode! response.resp_body
  end

  test "Authorised invalid update existing category patch apply 3" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (ucp:UpdateCategoryPatch {
          name: '#{name}.#{name}',
          introduction: '.',
          url: '#{name}.#{name}',
          revision_id: #{rev_id2},
          against_revision: #{rev_id + 1}
        }),
        (c)-[:UPDATE]->(ucp)
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "update,#{rev_id2}"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Cannot apply patch due to revision ID mismatch"}}
      = Poison.decode! response.resp_body
    refute [] === Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {revision_id: #{rev_id2}}) RETURN c")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {revision_id: #{rev_id}}),
        (c1)-[r:UPDATE]->(c2:InsertCategoryPatch {revision_id: #{rev_id2}})
      DELETE r, c1, c2
    """)
  end

  test "Authorised invalid query string patch apply 1" do
    conn =
      conn(:patch, "/api/categories/existent", %{"apply_patch" => "invalid_action"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Unknown patch action"}}
      = Poison.decode! response.resp_body
  end

  test "Authorised invalid query string patch apply 2" do
    conn =
      conn(:patch, "/api/categories/existent", %{"apply_patch" => "update,1,1"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Unknown patch action"}}
      = Poison.decode! response.resp_body
  end

  test "Authorised delete existing category patch apply" do
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
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 204
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:CategoryDeleted {revision_id: #{rev_id}}),
        (c)-[:CONTRIBUTOR {type: 'delete'}]->(:User {access_token: 'at1'}),
        (c)-[:CONTRIBUTOR {type: 'apply_delete'}]->(:User {access_token: 'at3'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:CategoryDeleted {revision_id: #{rev_id}})-[r]-()
      DELETE r, c
    """)
  end

  test "Authorised invalid delete existing category patch apply 1" do
    conn =
      conn(:patch, "/api/categories/non-existent", %{"apply_patch" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Category not found"}} = Poison.decode! response.resp_body
  end

  test "Authorised invalid delete existing category patch apply 2" do
    conn =
      conn(:patch, "/api/categories/existent", %{"apply_patch" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Delete patch not found for the specified category"}}
      = Poison.decode! response.resp_body
  end

  test "Authorised insert existing category patch discard" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:InsertCategoryPatch {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"discard_patch" => "insert"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert [] === Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {revision_id: #{rev_id}}) RETURN c")
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:InsertCategoryPatchDeleted {revision_id: #{rev_id}}),
        (c)-[:CONTRIBUTOR {type: 'discard_insert'}]->(:User {access_token: 'at3'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:InsertCategoryPatchDeleted {revision_id: #{rev_id}})-[r]-()
      DELETE r, c
    """)
  end

  test "Authorised update existing category patch discard" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (ucp:UpdateCategoryPatch {
          name: '#{name}.#{name}',
          introduction: '.',
          url: '#{name}.#{name}',
          revision_id: #{rev_id2},
          against_revision: #{rev_id}
        }),
        (c)-[:UPDATE]->(ucp)
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"discard_patch" => "update,#{rev_id2}"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert response.resp_body === ""
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (ucpd:UpdateCategoryPatchDeleted {revision_id: #{rev_id2}}),
        (c)-[r1:UPDATE]->(ucpd),
        (ucpd)-[r2:CONTRIBUTOR {type: "discard_update"}]->(:User {access_token: 'at3'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (ucpd:UpdateCategoryPatchDeleted {revision_id: #{rev_id2}}),
        (c)-[r1:UPDATE]->(ucpd),
        (ucpd)-[r2:CONTRIBUTOR {type: "discard_update"}]->()
      DELETE r1, r2, c, ucpd
    """)
  end

  test "Authorised delete existing category patch discard" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at2'})
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (c)<-[:DELETE]-(u)
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"discard_patch" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (c)-[:CONTRIBUTOR {type: 'discard_delete'}]->(:User {access_token: 'at3'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}})-[r]-()
      DELETE r, c
    """)
  end

  @doc """
  PATCH /api/categories/... -H 'authorization: ...'
  """
  test "Authorised invalid attempt at updating a category (patch limit reached)" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (user:User {username: '#{name}', access_token: '#{name}', privilege_level: 1}),
        (c:UpdateCategoryPatch)
      FOREACH (ignored in RANGE(1, 20) |
        CREATE (c)-[:CONTRIBUTOR]->(user)
      )
    """)

    conn =
      conn(:patch, "/api/categories/...", %{"category" => %{}, "revision_id" => 1})
      |> put_req_header("authorization", "#{name}")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The maximum patch limit (20) has been exceeded!"}}
      = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (user:User {username: '#{name}'})<-[r:CONTRIBUTOR]-(c) DELETE r, user, c")
  end

  test "Authorised update existing category with patches waiting" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at2'})

      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (ucp1:UpdateCategoryPatch {
          name: '#{name}.#{name}',
          introduction: '.',
          url: '#{name}.#{name}',
          revision_id: #{rev_id2 + 1},
          against_revision: #{rev_id}
        }),
        (ucp2:UpdateCategoryPatch {
          name: '#{name}..#{name}',
          introduction: '.',
          url: '#{name}..#{name}',
          revision_id: #{rev_id2 + 2},
          against_revision: #{rev_id}
        }),
        (c)-[:UPDATE]->(ucp1),
        (c)-[:UPDATE]->(ucp2),
        (c)-[:CONTRIBUTOR {type: "insert", date: 1, time: 4}]->(u),
        (ucp1)-[:CONTRIBUTOR {type: "update", date: 2, time: 5}]->(u),
        (ucp2)-[:CONTRIBUTOR {type: "update", date: 3, time: 6}]->(u)
    """)
    data = %{"category" => %{"name" => "#{name}...#{name}", "introduction" => "."}, "revision_id" => rev_id}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"category" => %{"name" => catname, "introduction" => ".", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    assert catname === "#{name}...#{name}"
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}...#{name}'}),
        (c)-[:UPDATE]->(:UpdateCategoryPatch {name: '#{name}..#{name}'}),
        (c)-[:UPDATE]->(:UpdateCategoryPatch {name: '#{name}.#{name}'}),
        (c)-[:REVISION]->(:CategoryRevision {name: '#{name}'}),
        (c)-[:CONTRIBUTOR]->(:User {access_token: 'at3'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}...#{name}'})-[r]-(),
        (c)-[:UPDATE]->(ucp1:UpdateCategoryPatch {name: '#{name}..#{name}'}),
        (c)-[:UPDATE]->(ucp2:UpdateCategoryPatch {name: '#{name}.#{name}'}),
        (c)-[:REVISION]->(cr:CategoryRevision {name: '#{name}'}),
        (c)-[:CONTRIBUTOR]->(u:User {access_token: 'at3'})
      DELETE r, c, ucp1, ucp2, cr
    """)
  end

  test "Prevent duplicate category naming on update" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    name2 = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (:Category {name: '#{name2}', introduction: '..', url: '#{name2}', revision_id: #{rev_id2}})
    """)
    data = %{"category" => %{"name" => "#{name}", "introduction" => "."}, "revision_id" => rev_id2}

    conn =
      conn(:patch, "/api/categories/#{name2}", data)
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The category with the specified name already exists"}}
      = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {revision_id: #{rev_id}}),
        (c2:Category {revision_id: #{rev_id2}})
      DELETE c1, c2
    """)
  end
end
