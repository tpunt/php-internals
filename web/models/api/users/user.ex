defmodule PhpInternals.Api.Users.User do
  use PhpInternals.Web, :model

  @valid_fields ["name", "privilege_level"]

  def user_exists?(username) do
    user = fetch_user_by_username(username)

    if user === nil do
      {:error, 404, "The specified user does not exist"}
    else
      {:ok, user}
    end
  end

  def valid_params?(params) do
    if params !== %{} and Map.keys(params) -- @valid_fields === [] do
      {:ok}
    else
      {:error, 400, "Unknown fields provided"}
    end
  end

  def fetch_users do
    query = """
      MATCH (u:User)
      RETURN {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
    """

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_user_by_username(username) do
    query = """
      MATCH (user:User {username: {username}})
      RETURN user
    """

    params = %{username: username}

    case Neo4j.query!(Neo4j.conn, query, params) do
      [] -> nil
      [user] -> user
    end
  end

  def fetch_user_by_id(user_id) do
    query = """
      MATCH (user:User {id: {id}})
      RETURN user
    """

    params = %{id: user_id}

    case Neo4j.query!(Neo4j.conn, query, params) do
      [] -> nil
      [user] -> user
    end
  end

  def fetch_user_by_token(access_token) do
    query = """
      MATCH (u:User {access_token: {access_token}})
      RETURN {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
    """

    params = %{access_token: access_token}

    case Neo4j.query!(Neo4j.conn, query, params) do
      [] -> nil
      [user] -> user
    end
  end

  def fetch_user_by_secret(client_secret) do
    query = """
      MATCH (user:User {client_secret: {client_secret}})
      RETURN user
    """

    params = %{client_secret: client_secret}

    case Neo4j.query!(Neo4j.conn, query, params) do
      [] -> nil
      [user] -> user
    end
  end

  def update_user_token(username, access_token) do
    query = """
      MATCH (u:User {username: {username}})
      SET u.access_token = {access_token}
      RETURN {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
    """

    params = %{username: username, access_token: access_token}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def insert_user(auth_info) do
    query = """
      CREATE (user:User {
        name: {name},
        username: {username},
        provider: {provider},
        access_token: {access_token},
        privilege_level: 1
      })
      RETURN user
    """

    Neo4j.query!(Neo4j.conn, query, auth_info)
  end

  def update(username, user) do
    query1 = """
      MATCH (u:User {username: {username}})
      SET
    """

    query2 =
      Enum.reduce(user, [], fn {key, _value}, acc ->
        acc ++ ["u.#{key} = {#{key}}"]
      end)
      |> Enum.join(",")

    query3 = """
      RETURN {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
    """

    query = query1 <> query2 <> query3

    List.first Neo4j.query!(Neo4j.conn, query, Map.put(user, :username, username))
  end

  def delete_token(username) do
    query = """
      MATCH (u:User {username: {username}})
      SET u.access_token = ""
    """

    Neo4j.query!(Neo4j.conn, query, %{username: username})
  end
end
