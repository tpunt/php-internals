defmodule CategoryPatchTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  test "Unauthenticated non-existent category patch" do
    conn = conn(:patch, "/api/categories/non-existent")
    response = Router.call(conn, @opts)

    assert response.status == 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}} = Poison.decode! response.resp_body
  end

  test "Authorised non-existent category patch" do
    conn =
      conn(:patch, "/api/categories/non-existent", %{"category" => %{"name" => ".", "introduction" => "."}})
      |> put_req_header("authorization", "at1")
    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "Category not found"}} = Poison.decode! response.resp_body
  end

  test "Authorised update existing category review 1" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"category" => %{"name" => "#{name}", "introduction" => "."}})
      |> put_req_header("authorization", "at1")
    response = Router.call(conn, @opts)

    assert response.status == 202
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {against_revision: #{rev_id}}) RETURN c")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (c)-[r1:UPDATE]->(ucp:UpdateCategoryPatch),
        (ucp)-[r2:CONTRIBUTOR {type: "update"}]->()
      DELETE r1, r2, c, ucp
    """)
  end

  test "Authorised update existing category review 2" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)
    data = %{"review" => "1", "category" => %{"name" => "#{name}", "introduction" => "."}}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)

    assert response.status == 202
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {against_revision: #{rev_id}}) RETURN c")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (c)-[r1:UPDATE]->(ucp:UpdateCategoryPatch),
        (ucp)-[r2:CONTRIBUTOR {type: "update"}]->()
      DELETE r1, r2, c, ucp
    """)
  end

  test "Authorised update existing category review 3" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)
    data = %{"review" => "1", "category" => %{"name" => "#{name}", "introduction" => "."}}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 202
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {against_revision: #{rev_id}}) RETURN c")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (c)-[r1:UPDATE]->(ucp:UpdateCategoryPatch),
        (ucp)-[r2:CONTRIBUTOR {type: "update"}]->()
      DELETE r1, r2, c, ucp
    """)
  end

  test "Authorised update existing category review 4" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (cp:UpdateCategoryPatch {
          name: '#{name}.#{name}',
          introduction: '.',
          url: '#{name}.#{name}',
          revision_id: #{rev_id2},
          against_revision: #{rev_id}
        }),
        (c)-[:UPDATE]->(cp)
    """)
    data = %{"review" => "1", "references_patch" => "#{rev_id2}", "category" =>
      %{"name" => "#{name}.", "introduction" => "....."}}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 202
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {revision_id: #{rev_id2}}) RETURN c")
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {against_revision: #{rev_id}}) RETURN c")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}}),
        (c)-[r1:UPDATE]->(ucp:UpdateCategoryPatch),
        (ucp)-[r2:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision),
        (ucp)-[r3:CONTRIBUTOR {type: "update"}]->()
      DELETE r1, r2, r3, c, ucp, ucpr
    """)
  end

  test "Unauthorised update existing category review" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)
    data = %{"review" => "1", "references_patch" => "1", "category" =>
      %{"name" => "#{name}.", "introduction" => "....."}}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at1")
    response = Router.call(conn, @opts)

    assert response.status == 403
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:ategory {revision_id: #{rev_id}})-[:UPDATE]-() RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) DELETE c")
  end

  test "Authorised update existing category 1" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"category" => %{"name" => "#{name}", "introduction" => "."}})
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category" => %{"name" => _, "introduction" => ".", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {against_revision: #{rev_id}}) RETURN c")
    refute [] == Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {name: '#{name}'}),
        (c1)-[:REVISION]->(c2:CategoryRevision {revision_id: #{rev_id}})
      RETURN c2
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[r1:REVISION]-(cr:CategoryRevision {revision_id: #{rev_id}}),
        (c)-[r2:CONTRIBUTOR {type: "update"}]->()
      DELETE r1, r2, c, cr
    """)
  end

  test "Authorised update existing category 2" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"category" => %{"name" => "#{name}", "introduction" => "."}})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category" => %{"name" => _, "introduction" => ".", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {against_revision: #{rev_id}}) RETURN c")
    refute [] == Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {name: '#{name}'}),
        (c1)-[:REVISION]->(c2:CategoryRevision {revision_id: #{rev_id}})
      RETURN c2
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {name: '#{name}'}),
        (c1)-[r1:REVISION]->(c2:CategoryRevision {revision_id: #{rev_id}}),
        (c1)-[r2:CONTRIBUTOR {type: 'update'}]->()
      DELETE r1, r2, c1, c2
    """)
  end

  test "Authorised update existing category 3" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (cp:UpdateCategoryPatch {
          name: '#{name}.#{name}',
          introduction: '.',
          url: '#{name}.#{name}',
          revision_id: #{rev_id2},
          against_revision: #{rev_id}
        }),
        (c)-[:UPDATE]->(cp)
    """)
    data = %{"references_patch" => "#{rev_id2}", "category" =>
      %{"name" => "#{name}.", "introduction" => ".."}}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category" => %{"name" => _, "introduction" => "..", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {revision_id: #{rev_id2}}) RETURN c")
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {against_revision: #{rev_id}}) RETURN c")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {name: '#{name}'})-[r:UPDATE]->(c2:UpdateCategoryPatch)
      DELETE r, c1, c2
    """)
  end

  test "Unauthorised update existing category" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)
    data = %{"references_patch" => "1", "category" => %{"name" => "#{name}.", "introduction" => "."}}

    conn =
      conn(:patch, "/api/categories/#{name}", data)
      |> put_req_header("authorization", "at1")
    response = Router.call(conn, @opts)

    assert response.status == 403
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:ategory {revision_id: #{rev_id}})-[:UPDATE]-() RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) DELETE c")
  end

  test "Authorised insert category patch apply 1" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:InsertCategoryPatch {
          name: '#{name}',
          introduction: '...',
          url: '#{name}',
          revision_id: #{rev_id}
        })
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "insert"})
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) RETURN c")
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {revision_id: '#{rev_id}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[r:CONTRIBUTOR {type: 'apply_insert'}]-()
      DELETE r, c
    """)
  end

  test "Authorised insert category patch apply 2" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:InsertCategoryPatch {
          name: '#{name}',
          introduction: '...',
          url: '#{name}',
          revision_id: #{rev_id}
        })
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "insert"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category" => %{"name" => _, "introduction" => "...", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) RETURN c")
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {revision_id: '#{rev_id}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[r:CONTRIBUTOR {type: 'apply_insert'}]-()
      DELETE r, c
    """)
  end

  test "Authorised invalid insert category patch apply 1" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "insert"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "Insert patch not found"}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) DELETE c")
  end

  test "Authorised invalid insert category patch apply 2" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (:InsertCategoryPatch {name: '#{name}', introduction: '.', url: '#{name}', revision_id: #{rev_id2}})
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "insert"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 400
    assert %{"error" => %{"message" => "A category with the same name already exists"}}
      = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {revision_id: #{rev_id}}),
        (c2:InsertCategoryPatch {revision_id: #{rev_id2}})
      DELETE c1, c2
    """)
  end

  test "Authorised update existing category patch apply" do
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
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "update,#{rev_id2}"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"category" => %{"name" => _, "introduction" => ".", "url" => _, "revision_id" => _}}
      = Poison.decode! response.resp_body
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {revision_id: #{rev_id2}}) RETURN c")
    refute [] == Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {revision_id: #{rev_id2}}),
        (c1)-[:REVISION]->(c2:CategoryRevision {revision_id: #{rev_id}})
      RETURN c2
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {revision_id: #{rev_id2}}),
        (c1)-[r1:INSERT_APPLIED_BY]->(),
        (c1)-[r2:REVISION]->(c2:CategoryRevision {revision_id: #{rev_id}})
        DELETE r1, r2, c1, c2
    """)
  end

  test "Authorised invalid update existing category patch apply 1" do
    conn =
      conn(:patch, "/api/categories/non-existent", %{"apply_patch" => "update,1"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "Category not found"}} = Poison.decode! response.resp_body
  end

  test "Authorised invalid update existing category patch apply 2" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    rev_id2 = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "update,#{rev_id2}"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "Update patch not found for the specified category"}}
      = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) DELETE c")
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

    assert response.status == 400
    assert %{"error" => %{"message" => "Cannot apply patch due to revision ID mismatch"}}
      = Poison.decode! response.resp_body
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {revision_id: #{rev_id2}}) RETURN c")
    assert [] == Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {revision_id: #{rev_id2}}),
        (c1)-[:REVISION]->(c2:CategoryRevision {revision_id: #{rev_id}})
      RETURN c2
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c1:Category {revision_id: #{rev_id}}),
        (c1)-[r:UPDATE]->(c2:InsertCategoryPatch {revision_id: #{rev_id2}})
      DELETE r, c1, c2
    """)
  end

  test "Authorised invalid query string patch apply 1" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "invalid_action"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 400
    assert %{"error" => %{"message" => "Unknown patch action"}}
      = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) DELETE c")
  end

  test "Authorised invalid query string patch apply 2" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "update,1,1"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 400
    assert %{"error" => %{"message" => "Unknown patch action"}}
      = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) DELETE c")
  end

  test "Authorised delete existing category patch apply" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {
          name: '#{name}',
          introduction: '...',
          url: '#{name}',
          revision_id: #{rev_id}
        }),
        (c)-[:DELETE]->(:DeleteCategoryPatch)
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 204
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}})-[:DELETE]->(:DeleteCategoryPatch) RETURN c")
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:CategoryDeleted {revision_id: #{rev_id}}) RETURN c")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:CategoryDeleted {revision_id: #{rev_id}}),
        (c)-[r:CONTRIBUTOR {type: "apply_delete"}]->()
      DELETE r, c
    """)
  end

  test "Authorised invalid delete existing category patch apply 1" do
    conn =
      conn(:patch, "/api/categories/non-existent", %{"apply_patch" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "Category not found"}} = Poison.decode! response.resp_body
  end

  test "Authorised invalid delete existing category patch apply 2" do
    name = :rand.uniform(100_000_000)
    rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}})
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"apply_patch" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "Delete patch not found for the specified category"}}
      = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) DELETE c")
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

    assert response.status == 200
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {revision_id: #{rev_id}}) RETURN c")
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatchDeleted {revision_id: #{rev_id}}) RETURN c")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:InsertCategoryPatchDeleted {revision_id: #{rev_id}}),
        (c)-[r:CONTRIBUTOR {type: 'discard_insert'}]->()
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

    assert response.status == 200
    assert response.resp_body == ""
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatch {revision_id: #{rev_id2}}) RETURN c")
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:UpdateCategoryPatchDeleted {revision_id: #{rev_id2}}) RETURN c")

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
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}', revision_id: #{rev_id}}),
        (c)-[:DELETE]->(:DeleteCategoryPatch)
    """)

    conn =
      conn(:patch, "/api/categories/#{name}", %{"discard_patch" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}})-[:DELETE]->(:DeleteCategoryPatch) RETURN c")
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {revision_id: #{rev_id}}) RETURN c")

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{rev_id}})-[r:CONTRIBUTOR {type: 'discard_delete'}]-()
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
      conn(:patch, "/api/categories/...", %{"category" => %{}})
      |> put_req_header("authorization", "#{name}")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The maximum patch limit (20) has been exceeded!"}}
      = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (user:User {username: '#{name}'})<-[r:CONTRIBUTOR]-(c) DELETE r, user, c")
  end
end
