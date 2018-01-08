defmodule PhpInternals.Api.Users.User do
  use PhpInternals.Web, :model

  alias PhpInternals.Cache.ResultCache
  alias PhpInternals.Api.Users.UserView

  @valid_fields [
    "name",
    "avatar_url",
    "blog_url",
    "email",
    "bio",
    "location",
    "github_url",
    "twitter_url",
    "linkedin_url",
    "googleplus_url"
  ]

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

  def valid_optional?(nil = username) do
    {:ok, username}
  end

  def valid_optional?(username) do
    valid?(username)
  end

  def valid?(username) do
    user = fetch_by_username_cache(username)

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

  def fetch_all_cache(order_by, ordering, offset, limit, nil = search_term) do
    key = "users?#{order_by}&#{ordering}&#{offset}&#{limit}&#{search_term}"
    ResultCache.fetch(key, fn ->
      all_users = fetch_all(order_by, ordering, offset, limit, search_term)
      ResultCache.group("users", key)
      Phoenix.View.render_to_string(UserView, "index.json", users: all_users["result"])
    end)
  end

  def fetch_all_cache(order_by, ordering, offset, limit, search_term) do
    # Don't bother caching normal search terms...
    # key = "users?#{order_by}&#{ordering}&#{offset}&#{limit}&#{search_term}"
    # ResultCache.fetch(key, fn ->
    #   all_users = fetch_all(order_by, ordering, offset, limit, search_term)
    #   ResultCache.group("users", key)
    #   Phoenix.View.render_to_string(UserView, "index.json", users: all_users["result"])
    # end)

    all_users = fetch_all(order_by, ordering, offset, limit, search_term)
    Phoenix.View.render_to_string(UserView, "index.json", users: all_users["result"])
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

  def fetch_by_username_cache(username) do
    key = "users/#{username}"
    case ResultCache.get(key) do
      {:not_found} ->
        case fetch_by_username(username) do
          nil ->
            nil
          user ->
            ResultCache.set(key, Phoenix.View.render_to_string(UserView, "show_full.json", user: user))
        end
      {:found, response} -> response
    end
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

    ResultCache.invalidate("users/#{auth_info.username}")
    ResultCache.flush("users")
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

    user = List.first Neo4j.query!(Neo4j.conn, query, params)

    ResultCache.invalidate("users/#{username}")
    ResultCache.flush("users")

    user
  end

  def delete_token(username) do
    query = """
      MATCH (u:User {username: {username}})
      SET u.access_token = ""
    """

    Neo4j.query!(Neo4j.conn, query, %{username: username})
  end
end
