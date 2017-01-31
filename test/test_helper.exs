ExUnit.start

alias Neo4j.Sips, as: Neo4j

defmodule PopulateDatabase do
  def setup do
    Neo4j.query!(Neo4j.conn, "MATCH (n) OPTIONAL MATCH (n)-[r]-() DELETE r, n")

    query = """
      CREATE (u1:User {id: 1, name: {name1}, privilege_level: 1, access_token: "at1"}),
        (u2:User {id: 2, name: {name2}, privilege_level: 2, access_token: "at2"}),
        (u3:User {id: 3, name: {name3}, privilege_level: 3, access_token: "at3"})
    """

    params = %{name1: "#{:rand.uniform(100_000_000)}",
      name2: "#{:rand.uniform(100_000_000)}",
      name3: "#{:rand.uniform(100_000_000)}"}

    Neo4j.query!(Neo4j.conn, query, params)
  end
end

PopulateDatabase.setup
