defmodule PhpInternals.Api.Articles.Article do
  use PhpInternals.Web, :model

  @default_order_by "date"
  @required_fields ["title", "body", "categories", "excerpt", "series_name"]
  @optional_fields [] # "tags"

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

  def valid_view?(nil = _view), do: {:ok, "full"}
  def valid_view?("overview" = view), do: {:ok, view}
  def valid_view?(_view), do: {:error, 400, "Invalid view field given"}

  def valid?(article_url) do
    query = """
      MATCH (article:Article {url: {url}}),
        (article)-[arel:AUTHOR]->(u:User),
        (article)-[crel:CATEGORY]->(category:Category)
      RETURN article,
        collect({category: category}) AS categories,
        {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
    """

    params = %{url: article_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "Article not found"}
    else
      article =
        result["article"]
        |> Map.merge(%{"user" => result["user"]})
        |> Map.merge(%{"categories" => result["categories"]})

      {:ok, %{"article" => article}}
    end
  end

  def valid_series?(series_url) do
    query = """
      MATCH (a:Article {series_url: {series_url}}),
        (a)-[arel:AUTHOR]->(u:User),
        (a)-[crel:CATEGORY]->(category:Category)
      RETURN {
          title: a.title,
          url: a.url,
          date: a.date,
          excerpt: a.excerpt,
          series_name: a.series_name,
          series_url: a.series_url
        } AS article,
        collect({category: category}) as categories,
        {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
      ORDER BY article.date ASC
    """

    params = %{series_url: series_url}

    result = Neo4j.query!(Neo4j.conn, query, params)

    if result === [] do
      {:error, 404, "Article series not found"}
    else
      result =
        result
        |> Enum.map(fn %{"article" => article, "user" => user} = result ->
            article =
              article
              |> Map.merge(%{"user" => user})
              |> Map.merge(%{"categories" => result["categories"]})

            %{"article" => article}
          end)

      {:ok, result}
    end
  end

  def valid_in_series?(series_url, article_url) do
    query = """
      MATCH (article:Article {series_url: {series_url}, url: {url}}),
        (article)-[arel:AUTHOR]->(u:User),
        (article)-[crel:CATEGORY]->(category:Category)
      RETURN article,
        collect({category: category}) AS categories,
        {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
    """

    params = %{series_url: series_url, url: article_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "Article not found for given article series"}
    else
      article =
        result["article"]
        |> Map.merge(%{"user" => result["user"]})
        |> Map.merge(%{"categories" => result["categories"]})

      {:ok, %{"article" => article}}
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

  def fetch(order_by, ordering, offset, limit, category_filter, author_filter, view, search_term, full_search) do
    query1 =
      if category_filter === nil do
        if author_filter === nil do
          "MATCH (a:Article)"
        else
          "MATCH (a:Article)-[:AUTHOR]->(:User {username: {username}})"
        end
      else
        if author_filter === nil do
          "MATCH (a:Article)-[:CATEGORY]->(:Category {url: {category_url}})"
        else
          "MATCH (:User {username: {username}})<-[:AUTHOR]-(a:Article)-[:CATEGORY]->(:Category {url: {category_url}})"
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

    query3 = "MATCH (a)-[arel:AUTHOR]->(u:User), (a)-[crel:CATEGORY]->(category:Category)"

    query4 =
      if view === "overview" do
        "RETURN {
          title: a.title,
          url: a.url,
          date: a.date,
          excerpt: a.excerpt,
          series_name: a.series_name,
          series_url: a.series_url
        } AS article,"
      else
        "RETURN a AS article,"
      end

    query5 = """
        collect({category: category}) as categories,
        {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
      ORDER BY article.#{order_by} #{ordering}
      SKIP #{offset}
      LIMIT #{limit}
    """

    query = query1 <> query2 <> query3 <> query4 <> query5

    params = %{category_url: category_filter, username: author_filter, search_term: search_term}

    Neo4j.query!(Neo4j.conn, query, params)
    |> Enum.map(fn %{"article" => article, "user" => user} = result ->
        article =
          article
          |> Map.merge(%{"user" => user})
          |> Map.merge(%{"categories" => result["categories"]})

        %{"article" => article}
      end)
  end

  def insert(article, username) do
    query1 = """
      CREATE (article:Article {
        title: {title},
        url: {url},
        series_name: {series_name},
        series_url: {series_url},
        excerpt: {excerpt},
        body: {body},
        date: timestamp()
      })
    """

    {query2, params1, _counter} =
      article["categories"]
      |> Enum.reduce({"", %{}, 0}, fn (cat, {q, p, c}) ->
          query = """
            WITH article
            MATCH (c#{c}:Category {url: {cat_#{c}}})
            CREATE (article)-[:CATEGORY]->(c#{c})
          """
          {q <> query, Map.put(p, "cat_#{c}", cat), c + 1}
        end)

    query3 = """
      WITH article
      MATCH (article)-[:CATEGORY]->(c:Category),
        (user:User {username: {username}})
      CREATE (article)-[:AUTHOR]->(user)
      RETURN article, user, collect({category: {name: c.name, url:c.url}}) as categories
    """

    query = query1 <> query2 <> query3

    params2 = %{
      title: article["title"],
      url: article["url"],
      excerpt: article["excerpt"],
      body: article["body"],
      username: username,
      series_name: article["series_name"],
      series_url: article["series_url"]
    }

    params = Map.merge(params1, params2)

    [result] = Neo4j.query!(Neo4j.conn, query, params)

    article =
      result["article"]
      |> Map.merge(%{"user" => result["user"]})
      |> Map.merge(%{"categories" => result["categories"]})

    %{"article" => article}
  end

  def update(article, article_url) do
    query1 = """
      MATCH (article:Article {url: {old_url}})-[r:CATEGORY]->(:Category)
      SET article.url = {new_url},
          article.title = {new_title},
          article.series_name = {new_series_name},
          article.series_url = {new_series_url},
          article.excerpt = {new_excerpt},
          article.body = {new_body}
      DELETE r
    """

    {query2, params1, _counter} =
      article["categories"]
      |> Enum.reduce({"", %{}, 0}, fn (cat, {q, p, c}) ->
          query = """
            WITH article
            MATCH (c#{c}:Category {url: {cat_#{c}}})
            CREATE UNIQUE (article)-[:CATEGORY]->(c#{c})
          """
          {q <> query, Map.put(p, "cat_#{c}", cat), c + 1}
        end)

    query3 = """
      WITH article
      MATCH (user:User)<-[:AUTHOR]-(article)-[:CATEGORY]->(c:Category)
      RETURN article, user, collect({category: {name: c.name, url: c.url}}) as categories
    """

    query = query1 <> query2 <> query3

    params2 = %{
      old_url: article_url,
      new_title: article["title"],
      new_url: article["url"],
      new_series_name: article["series_name"],
      new_series_url: article["series_url"],
      new_excerpt: article["excerpt"],
      new_body: article["body"]
    }

    params = Map.merge(params1, params2)

    [result] = Neo4j.query!(Neo4j.conn, query, params)

    article =
      result["article"]
      |> Map.merge(%{"user" => result["user"]})
      |> Map.merge(%{"categories" => result["categories"]})

    %{"article" => article}
  end

  def soft_delete(article_url) do
    query = """
      MATCH (article:Article {url: {url}})
      REMOVE article:Article
      SET article:ArticleDeleted
    """

    params = %{url: article_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end
end
