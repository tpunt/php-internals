defmodule PhpInternals.Api.Articles.Article do
  use PhpInternals.Web, :model

  alias PhpInternals.Cache.ResultCache
  alias PhpInternals.Utilities
  alias PhpInternals.Api.Articles.ArticleView

  @default_order_by "time"
  @required_fields ["title", "body", "categories", "excerpt"]
  @optional_fields ["series_name"] # "tags"

  # Implement tags?

  def contains_required_fields?(article) do
    if @required_fields -- Map.keys(article) === [] do
      {:ok}
    else
      {:error, 400, "Required fields are missing (expecting: #{Enum.join(@required_fields, ", ")})"}
    end
  end

  def contains_only_expected_fields?(article) do
    all_fields = @required_fields ++ @optional_fields
    if Map.keys(article) -- all_fields === [] do
      {:ok}
    else
      {:error, 400, "Unknown fields given (expecting: #{Enum.join(all_fields, ", ")})"}
    end
  end

  def valid_order_by?(order_by) do
    if order_by === nil do
      {:ok, @default_order_by}
    else
      if Enum.member?(@required_fields ++ @optional_fields, order_by) do
        {:ok, order_by}
      else
        {:error, 400, "Invalid order by field given"}
      end
    end
  end

  def valid_cache?(article_url) do
    key = "articles//#{article_url}"
    case ResultCache.get(key) do
      {:not_found} ->
        case valid?(article_url) do
          {:ok, article} ->
            response = Phoenix.View.render_to_string(ArticleView, "show_full.json", article: article)

            ResultCache.set(key, response)

            if article["article"]["series_url"] !== "" do
              ResultCache.set("articles/#{article["article"]["series_url"]}/#{article_url}", response)
            end

            {:ok, response}
          error -> error
        end
      {:found, response} -> {:ok, response}
    end
  end

  def valid?(article_url) do
    query = """
      MATCH (article:Article {url: {url}}),
        (article)-[:CATEGORY]->(c:Category)

      WITH article, COLLECT({category: {name: c.name, url: c.url}}) AS categories

      MATCH (article)-[:CONTRIBUTOR {type: "insert"}]->(u:User)

      RETURN {
        title: article.title,
        url: article.url,
        series_name: article.series_name,
        series_url: article.series_url,
        excerpt: article.excerpt,
        body: article.body,
        time: article.time,
        user: {
          username: u.username,
          name: u.name,
          privilege_level: u.privilege_level,
          avatar_url: u.avatar_url
        },
        categories: categories
      } AS article
    """

    params = %{url: article_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "Article not found"}
    else
      {:ok, result}
    end
  end

  def valid_series_cache?(series_url) do
    key = "articles/#{series_url}"
    case ResultCache.get(key) do
      {:not_found} ->
        case valid_series?(series_url) do
          {:ok, articles} ->
            response = Phoenix.View.render_to_string(ArticleView, "index.json", articles: articles)
            ResultCache.set(key, response)
            {:ok, response}
          error ->
            ResultCache.set(key, error)
        end
      {:found, response} ->
        if is_binary(response), do: {:ok, response}, else: response
    end
  end

  def valid_series?(series_url) do
    query = """
      MATCH (a:Article {series_url: {series_url}}),
        (a)-[:CATEGORY]->(c:Category)

      WITH a, COLLECT({category: {name: c.name, url: c.url}}) AS cs

      MATCH (a)-[:CONTRIBUTOR {type: "insert"}]->(u:User)

      RETURN {
          title: a.title,
          url: a.url,
          time: a.time,
          excerpt: a.excerpt,
          series_name: a.series_name,
          series_url: a.series_url,
          categories: cs,
          user: {
            username: u.username,
            name: u.name,
            privilege_level: u.privilege_level
          }
        } AS article
      ORDER BY article.time ASC
    """

    params = %{series_url: series_url}

    result = Neo4j.query!(Neo4j.conn, query, params)

    if result === [] do
      {:error, 404, "Article series not found"}
    else
      {:ok, result}
    end
  end

  def valid_in_series_cache?(series_url, article_url) do
    key = "articles/#{series_url}/#{article_url}"
    case ResultCache.get(key) do
      {:not_found} ->
        case valid_in_series?(series_url, article_url) do
          {:ok, article} ->
            response = Phoenix.View.render_to_string(ArticleView, "show_full.json", article: article)
            ResultCache.set(key, response)
            {:ok, response}
          error -> error
        end
      {:found, response} -> {:ok, response}
    end
  end

  def valid_in_series?(series_url, article_url) do
    query = """
      MATCH (article:Article {series_url: {series_url}, url: {url}}),
        (article)-[:CATEGORY]->(c:Category)

      WITH article, COLLECT({category: {name: c.name, url: c.url}}) AS categories

      MATCH (article)-[:CONTRIBUTOR {type: "insert"}]->(u:User)

      RETURN {
        title: article.title,
        url: article.url,
        series_name: article.series_name,
        series_url: article.series_url,
        excerpt: article.excerpt,
        body: article.body,
        time: article.time,
        user: {
          username: u.username,
          name: u.name,
          privilege_level: u.privilege_level,
          avatar_url: u.avatar_url
        },
        categories: categories
      } AS article
    """

    params = %{series_url: series_url, url: article_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "Article not found for given article series"}
    else
      {:ok, result}
    end
  end

  def not_valid?(old_article_url, new_article_url) do
    if old_article_url === new_article_url do
      {:ok}
    else
      case valid?(new_article_url) do
        {:ok, _article} ->
          {:error, 400, "The article with the specified name already exists"}
        {:error, 404, _status} ->
          {:ok}
      end
    end
  end

  def fetch_all_cache(order_by, ordering, offset, limit, category_filter, author_filter, search_term, full_search) do
    key = "articles?#{order_by}&#{ordering}&#{offset}&#{limit}&#{category_filter}&#{author_filter}&#{search_term}&#{full_search}"
    ResultCache.fetch(key, fn ->
      articles = fetch_all(order_by, ordering, offset, limit, category_filter, author_filter, search_term, full_search)
      ResultCache.group("articles", key)
      Phoenix.View.render_to_string(ArticleView, "index.json", articles: articles["result"])
    end)
  end

  def fetch_all(order_by, ordering, offset, limit, category_filter, author_filter, search_term, full_search) do
    query1 =
      if category_filter === nil do
        if author_filter === nil do
          "MATCH (a:Article)"
        else
          "MATCH (a:Article)-[:CONTRIBUTOR {type: \"insert\"}]->(:User {username: {username}})"
        end
      else
        if author_filter === nil do
          "MATCH (a:Article)-[:CATEGORY]->(:Category {url: {category_url}})"
        else
          "MATCH (:User {username: {username}})<-[:CONTRIBUTOR {type: \"insert\"}]-(a:Article)-[:CATEGORY]->(:Category {url: {category_url}})"
        end
      end

      {query2, search_term} =
        if search_term !== nil do
          where_query = "WHERE a."

          {column, search_term} =
            if full_search do
              {"body", "(?i).*#{search_term}.*"}
            else
              if String.first(search_term) === "=" do
                {"title", "(?i)#{String.slice(search_term, 1..-1)}"}
              else
                {"title", "(?i).*#{search_term}.*"}
              end
            end

          {where_query <> column <> " =~ {search_term}", search_term}
        else
          {"", nil}
        end

    query3 = """
      MATCH (a)-[arel:CONTRIBUTOR {type: "insert"}]->(u:User), (a)-[crel:CATEGORY]->(c:Category)
      WITH a, u, COLLECT({category: {name: c.name, url: c.url}}) AS categories
      ORDER BY a.#{order_by} #{ordering}
      WITH COLLECT({
        article: {
          title: a.title,
          url: a.url,
          time: a.time,
          excerpt: a.excerpt,
          series_name: a.series_name,
          series_url: a.series_url,
          categories: categories,
          user: {
            username: u.username,
            name: u.name,
            privilege_level: u.privilege_level
          }
        }
      }) AS articles
      RETURN {
        articles: articles[#{offset}..#{offset + limit}],
        meta: {
          total: LENGTH(articles),
          offset: #{offset},
          limit: #{limit}
        }
      } AS result
    """

    query = query1 <> query2 <> query3

    params = %{category_url: category_filter, username: author_filter, search_term: search_term}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  defp build_category_query(categories) do
    {match_categories, join_categories, bind_categories, _counter} =
      categories
      |> Enum.reduce({[], [], %{}, 0}, fn (cat, {m, j, b, c}) ->
          {
            m ++ ["(c#{c}:Category {url: {cat_#{c}}})"],
            j ++ ["(article)-[:CATEGORY]->(c#{c})"],
            Map.put(b, "cat_#{c}", cat),
            c + 1
          }
        end)

    {Enum.join(match_categories, ", "), Enum.join(join_categories, ", "), bind_categories}
  end

  def insert(article, username) do
    {match_categories, join_categories, bind_categories} =
      build_category_query(article["categories"])

    query = """
      MATCH (user:User {username: {username}}), #{match_categories}

      CREATE (article:Article {
          title: {title},
          url: {url},
          series_name: {series_name},
          series_url: {series_url},
          excerpt: {excerpt},
          body: {body},
          date: #{Utilities.get_date()},
          time: timestamp()
        }),
        (article)-[:CONTRIBUTOR {type: "insert", date: #{Utilities.get_date()}, time: timestamp()}]->(user),
        #{join_categories}
    """

    params = Map.merge(bind_categories, %{
      title: article["title"],
      url: article["url"],
      excerpt: article["excerpt"],
      body: article["body"],
      username: username,
      series_name: article["series_name"],
      series_url: article["series_url"]
    })

    Neo4j.query!(Neo4j.conn, query, params)

    update_cache_after_insert(article["series_url"], article["url"])

    {:ok, article} = valid_cache?(article["url"])

    article
  end

  def update(updated_article, old_article, username) do
    {match_categories, join_categories, bind_categories} =
      build_category_query(updated_article["categories"])

    query = """
      MATCH (article:Article {url: {old_url}}), (user:User {username: {username}})

      OPTIONAL MATCH (article)-[r1:REVISION]->(old_revision:ArticleRevision)
      OPTIONAL MATCH (article)-[r2:CONTRIBUTOR {type: "update"}]->(u:User)

      CREATE (revision:ArticleRevision)

      SET revision = article

      SET article.url = {new_url},
          article.title = {new_title},
          article.series_name = {new_series_name},
          article.series_url = {new_series_url},
          article.excerpt = {new_excerpt},
          article.body = {new_body}

      FOREACH (unused IN CASE r1 WHEN NULL THEN [] ELSE [1] END |
        CREATE (revision)-[:REVISION]->(old_revision)
        DELETE r1
      )

      FOREACH (unused IN CASE r2 WHEN NULL THEN [] ELSE [1] END |
        CREATE (revision)-[:CONTRIBUTOR {type: "update", date: r2.date, time: r2.time}]->(u)
        DELETE r2
      )

      CREATE (article)-[:REVISION]->(revision),
        (article)-[:CONTRIBUTOR {type: "update", date: #{Utilities.get_date()}, time: timestamp()}]->(user)

      WITH article

      MATCH (article)-[r3:CATEGORY]->(c:Category)

      DELETE r3

      WITH article, COLLECT(c) AS unused

      MATCH #{match_categories}

      CREATE #{join_categories}
    """

    params = Map.merge(bind_categories, %{
      old_url: old_article["url"],
      new_title: updated_article["title"],
      new_url: updated_article["url"],
      new_series_name: updated_article["series_name"],
      new_series_url: updated_article["series_url"],
      new_excerpt: updated_article["excerpt"],
      new_body: updated_article["body"],
      username: username
    })

    Neo4j.query!(Neo4j.conn, query, params)

    update_cache_after_update(old_article, updated_article)

    {:ok, article} = valid_cache?(updated_article["url"])

    article
  end

  def soft_delete(article_series, article_url) do
    query = """
      MATCH (article:Article {url: {url}})
      REMOVE article:Article
      SET article:ArticleDeleted
    """

    params = %{url: article_url}

    Neo4j.query!(Neo4j.conn, query, params)

    update_cache_after_delete(article_series, article_url)
  end

  def update_cache_after_update(old_article, updated_article) do
    old_categories =
      Enum.map(old_article["categories"], fn %{"category" => %{"url" => url}} ->
        url
      end)

    category_diff =
      (old_categories -- updated_article["categories"]) ++
      (updated_article["categories"] -- old_categories)

    if old_article["series_name"] !== updated_article["series_name"]
      or old_article["name"] !== updated_article["name"]
      or old_article["excerpt"] !== updated_article["excerpt"]
      or category_diff !== [] do
      ResultCache.flush("articles")
    end

    ResultCache.invalidate("articles//#{old_article["url"]}")

    if old_article["series_url"] !== "" do
      ResultCache.invalidate("articles/#{old_article["series_url"]}/#{old_article["url"]}")
    end

    ResultCache.invalidate_contributions()
  end

  def update_cache_after_delete(article_series, article_url) do
    ResultCache.invalidate("articles//#{article_url}")

    if article_series !== "" do
      ResultCache.invalidate("articles/#{article_series}/#{article_url}")
    end

    ResultCache.flush("articles")
  end

  def update_cache_after_insert(article_series, article_url) do
    ResultCache.invalidate("articles//#{article_url}")

    if article_series !== "" do
      ResultCache.invalidate("articles/#{article_series}/#{article_url}")
    end

    ResultCache.flush("articles")
  end
end
