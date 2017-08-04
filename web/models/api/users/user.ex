defmodule PhpInternals.Api.Users.User do
  use PhpInternals.Web, :model

  @valid_fields ["name", "avatar_url", "blog_url", "email", "bio", "location", "github_url"]
  @admin_valid_fields ["privilege_level", "access_token"] # "username" ?
  @patch_limit 20

  @valid_order_bys ["date", "username", "name", "privilege_level"]
  @default_order_by "date"

  def valid_order_by?(order_by) do
    if order_by === nil do
      {:ok, @default_order_by}
    else
      if Enum.member?(@valid_order_bys, order_by) do
        {:ok, order_by}
      else
        {:error, 400, "Invalid order by field given (expecting: #{Enum.join(@valid_order_bys, ", ")})"}
      end
    end
  end

  def valid?(nil = username) do
    {:ok, username}
  end

  def valid?(username) do
    user = fetch_by_username(username)

    if user === nil do
      {:error, 404, "The specified user does not exist"}
    else
      {:ok, user}
    end
  end

  def contains_only_expected_fields?(privilege_level, params) do
    all_fields =
      if privilege_level === 3 do
        @valid_fields ++ @admin_valid_fields
      else
        @valid_fields
      end

    if Map.keys(params) -- all_fields === [] do
      {:ok}
    else
      {:error, 400, "Unknown fields given (expecting: #{Enum.join(all_fields, ", ")})"}
    end
  end

  def within_patch_limit?(%{privilege_level: 1} = user) do
    query = """
      MATCH (user:User {username: {username}}),
        (c)-[:CONTRIBUTOR]->(user)
      WHERE HEAD(LABELS(c)) IN [
        "InsertCategoryPatch",
        "UpdateCategoryPatch",
        "InsertSymbolPatch",
        "UpdateSymbolPatch"
      ]
      RETURN COUNT(c) AS count
    """

    params = %{username: user.username}

    [%{"count" => count}] = Neo4j.query!(Neo4j.conn, query, params)

    if count === @patch_limit do
      {:error, 400, "The maximum patch limit (#{@patch_limit}) has been exceeded!"}
    else
      {:ok}
    end
  end

  def within_patch_limit?(_user) do
    {:ok}
  end

  def fetch_all(order_by, ordering, offset, limit, search_term) do
    {where_query, search_term} =
      if search_term !== nil do
        {column, search_term} =
          if String.first(search_term) === "=" do
            {"username", "(?i)#{String.slice(search_term, 1..-1)}"}
          else
            {"username", "(?i).*#{search_term}.*"}
          end

        {"WHERE u." <> column <> " =~ {search_term}", search_term}
      else
        {"", nil}
      end

    query = """
      MATCH (u:User)
      #{where_query}
      WITH u
      ORDER BY u.#{order_by} #{ordering}
      WITH COLLECT({user: {
        username: u.username,
        name: u.name,
        privilege_level: u.privilege_level
      }}) AS users
      RETURN {
        users: users[#{offset}..#{offset + limit}],
        meta: {
          total: LENGTH(users),
          offset: #{offset},
          limit: #{limit}
        }
      } AS result
    """

    params = %{search_term: search_term}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_by_username(username) do
    query = """
      MATCH (user:User {username: {username}})
      RETURN user
    """

    params = %{username: username}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_by_token(access_token) do
    query = """
      MATCH (u:User {access_token: {access_token}})
      RETURN {
        username: u.username,
        name: u.name,
        privilege_level: u.privilege_level,
        avatar_url: u.avatar_url
      } AS user
    """

    params = %{access_token: access_token}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_contributions_for(username, order_by, ordering, offset, limit) do
    query = """
      MATCH (u:User {username: {username}}),
        (u)<-[cr:CONTRIBUTOR]-(cn)

      WITH cn,
        cr,
        CASE WHEN HEAD(LABELS(cn)) IN [
            'Category',
            'InsertCategoryPatch',
            'UpdateCategoryPatch',
            'CategoryDeleted',
            'CategoryRevision'
          ] THEN 'category'
          WHEN HEAD(LABELS(cn)) = 'Article' THEN 'article'
          ELSE 'symbol'
        END AS filter

      RETURN {
        type: cr.type,
        date: cr.date,
        towards: CASE WHEN filter = 'category' THEN {category: cn} ELSE cn END,
        filter: filter
      } AS contribution
      ORDER BY cr.#{order_by} #{ordering}
      SKIP #{offset}
      LIMIT #{limit}
    """

    params = %{username: username, order_by: order_by, ordering: ordering, offset: offset, limit: limit}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def update_token(username, access_token) do
    query = """
      MATCH (u:User {username: {username}})
      SET u.access_token = {access_token}
      RETURN {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
    """

    params = %{username: username, access_token: access_token}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def insert(auth_info) do
    query = """
      CREATE (user:User {
        name: {name},
        username: {username},
        provider: {provider},
        access_token: {access_token},
        avatar_url: {avatar_url},
        blog_url: {blog_url},
        email: {email},
        bio: {bio},
        location: {location},
        github_url: {github_url},
        privilege_level: 1
      })
      RETURN user
    """

    Neo4j.query!(Neo4j.conn, query, auth_info)
  end

  def update(username, user) do
    query1 = """
      MATCH (user:User {username: {username}})
      SET
    """

    query2 =
      Enum.reduce(user, [], fn {key, _value}, acc ->
        acc ++ ["user.#{key} = {#{key}}"]
      end)
      |> Enum.join(",")

    query3 = """
      RETURN user
    """

    query = query1 <> query2 <> query3
    params = Map.put(user, :username, username)

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def delete_token(username) do
    query = """
      MATCH (u:User {username: {username}})
      SET u.access_token = ""
    """

    Neo4j.query!(Neo4j.conn, query, %{username: username})
  end
end
