defmodule PhpInternals.Api.Contributions.Contribution do
  use PhpInternals.Web, :model

  alias PhpInternals.Cache.ResultCache

  def fetch_all_cache(offset, limit) do
    key = "contributions?#{offset}#{limit}"
    ResultCache.fetch(key, fn ->
      fetch_all(offset, limit)
    end)
  end

  def fetch_all(offset, limit) do
    query = """
      MATCH (u:User)
      OPTIONAL MATCH (u)<-[:CONTRIBUTOR]-(c)

      WITH {
        user: {
          username: u.username,
            name: u.name,
            privilege_level: u.privilege_level,
            avatar_url: u.avatar_url
          },
          contribution_count: COUNT(c)
        } AS user

      ORDER BY user.contribution_count DESC

      WITH COLLECT(user) AS users

      OPTIONAL MATCH ()<-[r:CONTRIBUTOR]-()

      RETURN {
        total_contributions: COUNT(r),
        contributors: users[#{offset}..#{offset + limit}],
        meta: {
          total: LENGTH(users),
          offset: #{offset},
          limit: #{limit}
        }
      } AS result
    """

    List.first Neo4j.query!(Neo4j.conn, query)
  end
end
