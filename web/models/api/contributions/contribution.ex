defmodule PhpInternals.Api.Contributions.Contribution do
  use PhpInternals.Web, :model

  def fetch_all_overview(offset, limit) do
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

  def fetch_all_overview_for(username) do
    query = """
      MATCH (u:User {username: {username}})
      OPTIONAL MATCH (u)<-[cr:CONTRIBUTOR]-(c)

      WHERE cr.time > timestamp() - 31556952000

      RETURN {
        contribution_count: COUNT(cr),
        date: cr.date
      } AS day

      ORDER BY day.date ASC
    """

    params = %{username: username}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_all_normal(offset, limit) do
    query = """
      MATCH (u:User)<-[cr:CONTRIBUTOR]-(cn)

      WITH cn,
        cr,
        u,
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

      ORDER BY cr.date DESC

      WITH COLLECT({
          type: cr.type,
          date: cr.date,
          towards: CASE WHEN filter = 'category' THEN {category: cn} ELSE cn END,
          filter: filter,
          user: {
            username: u.username,
            name: u.name,
            privilege_level: u.privilege_level,
            avatar_url: u.avatar_url
          }
        }) AS contributions

      RETURN {
        contributions: contributions[#{offset}..#{offset + limit}],
        meta: {
          total: LENGTH(contributions),
          offset: #{offset},
          limit: #{limit}
        }
      } AS result
    """

    params = %{offset: offset, limit: limit}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_all_normal_for(username, offset, limit) do
    query = """
      MATCH (u:User {username: {username}})
      OPTIONAL MATCH (u)<-[cr:CONTRIBUTOR]-(cn)

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

      ORDER BY cr.date DESC

      WITH COLLECT({
          type: cr.type,
          date: cr.date,
          towards: CASE WHEN filter = 'category' THEN {category: cn} ELSE cn END,
          filter: filter
        }) AS contributions

      RETURN {
        contributions: contributions[#{offset}..#{offset + limit}],
        meta: {
          total: LENGTH(contributions),
          offset: #{offset},
          limit: #{limit}
        }
      } AS result
    """

    params = %{username: username, offset: offset, limit: limit}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end
end
