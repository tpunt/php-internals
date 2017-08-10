defmodule ContributionsGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  GET /api/contributions?view=overview
  """
  test "list all contributions overview" do
    conn = conn(:get, "/api/contributions", %{"view" => "overview"})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"total_contributions" => _, "contributions" => _, "meta" => %{}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/contributions?view=normal
  """
  test "list all contributions normal" do
    conn = conn(:get, "/api/contributions", %{})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"meta" => %{"total" => _, "page_count" => _, "offset" => 0, "limit" => _,
      "current_page" => _}, "contributions" => _,}
        = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/contributions?view=overview&author=user3
  """
  test "list all contributions overview for a pre-existing user" do
    conn = conn(:get, "/api/contributions", %{"view" => "overview", "author" => "user3"})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"contribution_history" => ch} = Poison.decode!(response.resp_body)
    assert %{"day" => %{"date" => _, "contribution_count" => _}} = List.first ch
  end

  @doc """
  GET /api/contributions?author=user3
  """
  test "list all contributions normal for a pre-existing user" do
    conn = conn(:get, "/api/contributions", %{"author" => "user3"})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"meta" => %{"total" => _, "page_count" => _, "offset" => 0, "limit" => _,
      "current_page" => _}, "contributions" => contributions}
        = Poison.decode!(response.resp_body)
    assert %{"contribution" => %{"type" => _, "towards" => _, "filter" => _, "date" => _}}
      = List.first contributions
  end

  @doc """
  GET /api/contributions?view=overview&author=...
  """
  test "list all contributions overview for a new user" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (user:User {username: '#{name}', access_token: '#{name}', privilege_level: 1})
    """)

    conn = conn(:get, "/api/contributions", %{"view" => "overview", "author" => "#{name}"})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"contribution_history" => []} = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (u:User {username: '#{name}'}) DELETE u")
  end

  @doc """
  GET /api/contributions?author=...
  """
  test "list all contributions normal for a new user" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (user:User {username: '#{name}', access_token: '#{name}', privilege_level: 1})
    """)

    conn = conn(:get, "/api/contributions", %{"author" => "#{name}"})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"meta" => %{"total" => 0, "page_count" => 0, "offset" => 0, "limit" => _,
      "current_page" => 1}, "contributions" => []}
        = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (u:User {username: '#{name}'}) DELETE u")
  end
end
