defmodule PhpInternals.Api.Articles.Article do
  use PhpInternals.Web, :model

  @default_order_by "date"
  @required_fields ["author", "title", "body", "categories"]
  @optional_fields ["tags"]

  # Implement tags?

  def contains_required_fields?(article) do
    if @required_fields -- Map.keys(article) === [] do
      {:ok}
    else
      {:error, 400, "Required fields are missing"}
    end
  end

  def contains_only_expected_fields?(article) do
    if Map.keys(article) -- (@required_fields ++ @optional_fields) === [] do
      {:ok}
    else
      {:error, 400, "Unknown fields given"}
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

  def exists?(article_url) do
    query = """
      MATCH (article:Article {url: {url}}),
        (article)-[arel:AUTHOR]->(u:User),
        (article)-[crel:CATEGORY]->(category:Category)
      RETURN article,
        collect(category) AS categories,
        {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
    """

    params = %{url: article_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "Article not found"}
    else
      categories = Enum.map(result["categories"], &(%{"category" => &1}))
      article =
        result["article"]
        |> Map.merge(%{"user" => result["user"]})
        |> Map.merge(%{"categories" => categories})

      {:ok, %{"article" => article}}
    end
  end

  def does_not_exist?(article_url) do
    case exists?(article_url) do
      {:ok, _article} ->
        {:error, 400, "The article with the specified name already exists"}
      {:error, 404, _status} ->
        {:ok}
    end
  end

  def fetch_articles(order_by, ordering, offset, limit, nil = _category_filter) do
    query = """
      MATCH (article:Article),
        (article)-[arel:AUTHOR]->(u:User),
        (article)-[crel:CATEGORY]->(category:Category)
      RETURN article,
        collect(category) as categories,
        {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
      ORDER BY article.#{order_by} #{ordering}
      SKIP #{offset}
      LIMIT #{limit}
    """

    normalise_fetched_articles_results Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_articles(order_by, ordering, offset, limit, category_filter) do
    query = """
      MATCH (article:Article)-[:CATEGORY]->(:Category {url: {category_url}})
      MATCH (article)-[arel:AUTHOR]->(u:User),
        (article)-[crel:CATEGORY]->(category:Category)
      RETURN article,
        collect(category) as categories,
        {username: u.username, name: u.name, privilege_level: u.privilege_level} AS user
      ORDER BY article.#{order_by} #{ordering}
      SKIP #{offset}
      LIMIT #{limit}
    """

    params = %{category_url: category_filter}

    normalise_fetched_articles_results Neo4j.query!(Neo4j.conn, query, params)
  end

  defp normalise_fetched_articles_results(results) do
    results
    |> Enum.map(fn %{"article" => article, "user" => user} = result ->
        categories = Enum.map(result["categories"], &(%{"category" => &1}))
        article =
          article
          |> Map.merge(%{"user" => user})
          |> Map.merge(%{"categories" => categories})

        %{"article" => article}
      end)
  end

  def insert(article) do
    query1 = """
      CREATE (article:Article {title: {title}, url: {url}, body: {body}, date: timestamp()})
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
      MATCH (user:User {username: {username}})
      CREATE (article)-[:AUTHOR]->(user)
      WITH article, user
      MATCH (article)-[:CATEGORY]->(c:Category)
      RETURN article, user, collect({name: c.name, url:c.url}) as categories
    """

    query = query1 <> query2 <> query3

    params2 = %{
      title: article["title"],
      url: article["url"],
      body: article["body"],
      username: article["author"]
    }

    params = Map.merge(params1, params2)

    [result] = Neo4j.query!(Neo4j.conn, query, params)

    categories = Enum.map(result["categories"], &(%{"category" => &1}))
    article =
      result["article"]
      |> Map.merge(%{"user" => result["user"]})
      |> Map.merge(%{"categories" => categories})

    %{"article" => article}
  end

  def update(article, article_url) do
    query1 = """
      MATCH (article:Article {url: {old_url}})-[r:CATEGORY]->(:Category)
      SET article.url = {new_url},
          article.title = {new_title},
          article.body = {new_body}
      DELETE r
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
      MATCH (user:User)<-[:AUTHOR]-(article)-[:CATEGORY]->(c:Category)
      RETURN article, user, collect({name: c.name, url:c.url}) as categories
    """

    query = query1 <> query2 <> query3

    params2 = %{
      old_url: article_url,
      new_title: article["title"],
      new_url: article["url"],
      new_body: article["body"]
    }

    params = Map.merge(params1, params2)

    [result] = Neo4j.query!(Neo4j.conn, query, params)

    categories = Enum.map(result["categories"], &(%{"category" => &1}))
    article =
      result["article"]
      |> Map.merge(%{"user" => result["user"]})
      |> Map.merge(%{"categories" => categories})

    %{"article" => article}
  end

  def soft_delete_article(article_url) do
    query = """
      MATCH (article:Article {url: {url}})
      REMOVE article:Article
      SET article:ArticleDeleted
    """

    params = %{url: article_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end
end
