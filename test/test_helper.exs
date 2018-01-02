ExUnit.start

alias Neo4j.Sips, as: Neo4j

defmodule PopulateDatabase do
  def setup do
    Neo4j.query!(Neo4j.conn, "MATCH (n) OPTIONAL MATCH (n)-[r]-() DELETE r, n")

    query = """
      CREATE (:User {id: 1, username: 'user1', name: 'u1', privilege_level: 1, access_token: "at1", avatar_url: "~1"}),
        (:User {id: 2, username: 'user2', name: 'u2', privilege_level: 2, access_token: "at2", avatar_url: "~2"}),
        (u:User {id: 3, username: 'user3', name: 'u3', privilege_level: 3, access_token: "at3", avatar_url: "~3"}),
        (c:Category {id: 4, name: 'existent', introduction: '~', url: 'existent', revision_id: 123}),
        (s:Symbol {
          id: 0,
          name: 'existent',
          description: '~',
          url: 'existent',
          definition: '~',
          source_location: '~',
          type: 'macro',
          revision_id: 123
        }),
        (a:Article {title: 'existent', url: 'existent', body: '.', series_name: '', excerpt: '.', date: 20170810, time: 2}),
        (s)-[:CATEGORY]->(c),
        (a)-[:CATEGORY]->(c),
        (c)-[:CONTRIBUTOR {type: "insert", date: 20170810, time: 1499974146854}]->(u),
        (s)-[:CONTRIBUTOR {type: "insert", date: 20170810, time: 1499974146854}]->(u),
        (a)-[:CONTRIBUTOR {type: "insert", date: 20170810, time: 1499974146854}]->(u),
        (:Settings {cache_expiration_time: 0})
    """

    Neo4j.query!(Neo4j.conn, query)
  end
end

PopulateDatabase.setup
