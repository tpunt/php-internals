defmodule PhpInternals.Api.Contributions.Contribution do
  use PhpInternals.Web, :model

  alias PhpInternals.Cache.ResultCache
  alias PhpInternals.Api.Contributions.ContributionView

  def fetch_all_overview_cache(offset, limit) do
    key = "contributions?overview&#{offset}&#{limit}"
    ResultCache.fetch_contributions(key, fn ->
      cs = fetch_all_overview(offset, limit)
      ResultCache.group("contributions", key)
      ResultCache.set(key, Phoenix.View.render_to_string(ContributionView, "index_overview.json", contributions: cs["result"]))
    end)
  end

  def fetch_all_overview(offset, limit) do
    query = """
      MATCH (u:User)
      OPTIONAL MATCH (u)<-[:CONTRIBUTOR]-(c)

      WITH {
          author: {
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

  def fetch_all_overview_for_cache(username) do
    key = "contributions?overview&#{username}"
    ResultCache.fetch_contributions(key, fn ->
      cs = fetch_all_overview_for(username)
      ResultCache.group("contributions", key)
      ResultCache.set(key, Phoenix.View.render_to_string(ContributionView, "index_overview_for_user.json", contributions: cs["result"]))
    end)
  end

  def fetch_all_overview_for(username) do
    query = """
      MATCH (u:User {username: {username}})
      OPTIONAL MATCH (u)<-[cr:CONTRIBUTOR]-(c)

      WHERE cr.time > timestamp() - 31556952000

      WITH cr.date AS date, COUNT(cr) AS contribution_count

      ORDER BY date ASC

      RETURN COLLECT(CASE date WHEN NULL THEN NULL ELSE {
        day: {
          contribution_count: contribution_count,
          date: date
        }
      } END) AS result
    """

    params = %{username: username}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_all_normal_cache(offset, limit) do
    key = "contributions?normal&#{offset}&#{limit}"
    ResultCache.fetch_contributions(key, fn ->
      cs = fetch_all_normal(offset, limit)
      ResultCache.group("contributions", key)
      ResultCache.set(key, Phoenix.View.render_to_string(ContributionView, "index_normal.json", contributions: cs["result"]))
    end)
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

      ORDER BY cr.date DESC, cr.time DESC

      WITH COLLECT({
          type: cr.type,
          date: cr.date,
          time: cr.time,
          towards: CASE WHEN filter = 'category' THEN {category: cn} ELSE cn END,
          filter: filter,
          author: {
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

  def fetch_all_normal_for_cache(username, offset, limit) do
    key = "contributions?normal&#{username}&#{offset}&#{limit}"
    ResultCache.fetch_contributions(key, fn ->
      cs = fetch_all_normal_for(username, offset, limit)
      ResultCache.group("contributions", key)
      ResultCache.set(key, Phoenix.View.render_to_string(ContributionView, "index_normal_for_user.json", contributions: cs["result"]))
    end)
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
          WHEN HEAD(LABELS(cn)) IN [
            'Article',
            'ArticleRevision',
            'ArticleDeleted'
          ] THEN 'article'
          ELSE 'symbol'
        END AS filter

      ORDER BY cr.date DESC, cr.time DESC

      WITH COLLECT(CASE cr WHEN NULL THEN NULL ELSE {
          type: cr.type,
          date: cr.date,
          time: cr.time,
          towards: CASE WHEN filter = 'category' THEN {category: cn} ELSE cn END,
          filter: filter
        } END) AS contributions

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
