defmodule SymbolGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

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
        (s)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(u)
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
      "name" => "existent", "url" => "existent", "type" => "macro"}}}
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
          revision_id: #{sym_rev_b},
          against_revision: #{sym_rev}
        }),
        (s2)-[:CATEGORY]->(c),
        (s2)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(u),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}", %{"patches" => "update"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_updates" => %{"updates" => updates, "symbol" => %{"id" => ^sym_id,
      "name" => "...", "url" => "...", "type" => "macro"}}}
        = Poison.decode! response.resp_body
    assert [%{"user" => %{"username" => "user3", "privilege_level" => 3, "name" => "u3",
      "avatar_url" => "~3"}, "date" => 20170830, "revision_id" => ^sym_rev_b,
      "against_revision" => ^sym_rev}] = updates

    conn =
      conn(:get, "/api/symbols/#{sym_id}/updates", %{})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_updates" => %{"updates" => updates, "symbol" => %{"id" => ^sym_id,
      "name" => "...", "url" => "...", "type" => "macro"}}}
        = Poison.decode! response.resp_body
    assert [%{"user" => %{"username" => "user3", "privilege_level" => 3, "name" => "u3",
      "avatar_url" => "~3"}, "date" => 20170830, "revision_id" => ^sym_rev_b,
      "against_revision" => ^sym_rev}] = updates

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
          revision_id: #{sym_rev_b},
          against_revision: #{sym_rev}
        }),
        (s2)-[:CATEGORY]->(c),
        (s2)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(u),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}", %{"patches" => "update", "patch_id" => "#{sym_rev_b}"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_update" => %{"update" => update, "symbol" => %{"id" => ^sym_id,
      "name" => "...", "url" => "...", "type" => "macro"}}} = Poison.decode! response.resp_body
    assert %{"against_revision" => ^sym_rev, "categories" => [%{"category" => %{
      "name" => "existent", "url" => "existent"}}], "definition" => ".2",
      "description" => ".2", "id" => ^sym_id, "name" => "...2", "revision_id" => ^sym_rev_b,
      "source_location" => "..2", "type" => "macro", "url" => "...2"} = update

    conn =
      conn(:get, "/api/symbols/#{sym_id}/updates/#{sym_rev_b}", %{})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_update" => %{"update" => update, "symbol" => %{"id" => ^sym_id,
      "name" => "...", "url" => "...", "type" => "macro"}}} = Poison.decode! response.resp_body
    assert %{"against_revision" => ^sym_rev, "categories" => [%{"category" => %{
      "name" => "existent", "url" => "existent"}}], "definition" => ".2",
      "description" => ".2", "id" => ^sym_id, "name" => "...2", "revision_id" => ^sym_rev_b,
      "source_location" => "..2", "type" => "macro", "url" => "...2"} = update

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
      "symbol" => %{"id" => 0, "name" => "existent", "url" => "existent",
      "type" => "macro"}}} = Poison.decode! response.resp_body
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
          revision_id: #{sym_rev_b},
          against_revision: #{sym_rev}
        }),
        (s2)-[:CATEGORY]->(c),
        (s2)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(u),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_patches" => %{"symbol" => %{"id" => ^sym_id, "name" => "...",
      "type" => "macro", "url" => "..."}, "patches" => %{"updates" => updates, "delete" => false}}}
        = Poison.decode! response.resp_body
    assert [%{"symbol_update" => %{"user" => %{"username" => "user3", "privilege_level" => 3,
      "name" => "u3", "avatar_url" => "~3"}, "date" => 20170830, "against_revision" => ^sym_rev,
      "revision_id" => ^sym_rev_b}}] = updates

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
    assert %{"symbol_patches" => %{"symbol" => %{"id" => ^sym_id, "name" => "...",
      "url" => "...", "type" => "macro"}, "patches" => %{"updates" => [],
      "delete" => true}}} = Poison.decode! response.resp_body

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
          revision_id: #{sym_rev_b},
          against_revision: #{sym_rev}
        }),
        (s2)-[:CATEGORY]->(c),
        (s2)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(u),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2),
        (s)<-[:DELETE]-(u)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_patches" => %{"symbol" => %{"id" => ^sym_id, "name" => "...",
      "url" => "..."}, "patches" => %{"updates" => updates,
      "delete" => true}}} = Poison.decode! response.resp_body
    assert [%{"symbol_update" => %{"user" => %{"username" => "user3", "privilege_level" => 3,
      "name" => "u3", "avatar_url" => "~3"}, "date" => _date, "revision_id" => ^sym_rev_b,
      "against_revision" => ^sym_rev}}] = updates

    Neo4j.query!(Neo4j.conn, """
      MATCH (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}})-[r1]-(),
        (s:Symbol {revision_id: #{sym_rev}})-[r2]-()
      DELETE r1, r2, su, s
    """)
  end

  @doc """
  GET /api/symbols/existent/revisions -H authorization:at3
  """
  test "get an existing symbol's revisions" do
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
        (s2:SymbolRevision {
          id: #{sym_id},
          name: '...2',
          description: '.2',
          url: '...2',
          definition: '.2',
          source_location: '..2',
          categories: [c.id],
          type: 'macro',
          revision_id: #{sym_rev_b}
        }),
        (s2)-[:CONTRIBUTOR {date: 20170830, time: 2, type: 'insert'}]->(u),
        (s)-[:CATEGORY]->(c),
        (s)-[:REVISION]->(s2)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_id}/revisions", %{})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbol_revisions" => %{"symbol" => %{"id" => ^sym_id, "name" => "...",
      "url" => "...", "type" => "macro"}, "revisions" => revisions}}
        = Poison.decode! response.resp_body
    assert [%{"revision_date" => 20170830, "revision_id" => ^sym_rev_b, "type" => "insert",
      "user" => %{"username" => "user3", "privilege_level" => 3, "name" => "u3",
      "avatar_url" => "~3"}}] = revisions

    conn =
      conn(:get, "/api/symbols/#{sym_id}/revisions/#{sym_rev_b}", %{})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{
      "symbol_revision" => %{
        "revision" => %{
          "date" => 20170830,
          "symbol" => %{
            "categories" => [
              %{
                "category" => %{
                  "name" => "existent",
                  "url" => "existent"
                }
              }
            ],
            "definition" => ".2",
            "description" => ".2",
            "id" => ^sym_id,
            "name" => "...2",
            "revision_id" => ^sym_rev_b,
            "source_location" => "..2",
            "type" => "macro",
            "url" => "...2"
          },
          "user" => %{
            "avatar_url" => "~3",
            "name" => "u3",
            "privilege_level" => 3,
            "username" => "user3"
          }
        },
        "symbol" => %{
          "id" => ^sym_id,
          "name" => "...",
          "type" => "macro",
          "url" => "..."
        }
      }
    } = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (su:SymbolRevision {revision_id: #{sym_rev_b}})-[r1]-(),
        (s:Symbol {revision_id: #{sym_rev}})-[r2]-()
      DELETE r1, r2, su, s
    """)
  end

  @doc """
  GET /api/symbols/0/revisions -H 'authorization: at2'
  """
  test "Authorised attempt at listing an existing symbols's non-existent revisions" do
    conn =
      conn(:get, "/api/symbols/0/revisions", %{})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{
      "symbol_revisions" => %{
        "revisions" => [],
        "symbol" => %{
          "id" => 0,
          "name" => "existent",
          "type" => "macro",
          "url" => "existent"
        }
      }
    } = Poison.decode! response.resp_body
  end
end
