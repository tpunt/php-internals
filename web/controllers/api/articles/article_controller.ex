defmodule PhpInternals.Api.Articles.ArticleController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Categories.Category
  alias PhpInternals.Api.Users.User
  alias PhpInternals.Api.Articles.Article
  alias PhpInternals.Utilities

  def index(conn, params) do
    with {:ok, order_by} <- Article.valid_order_by?(params["order_by"]),
         {:ok, ordering} <- Utilities.valid_ordering?(params["ordering"]),
         {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]),
         {:ok, _category} <- Category.valid_category?(params["category"]),
         {:ok, view} <- Article.valid_view?(params["view"]) do
      render(conn, "index_#{view}.json", articles: Article.fetch_articles(order_by, ordering, offset, limit, params["category"], view))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"series_name" => series_url, "article_name" => article_url} = params) do
    with {:ok, article} <- Article.exists_from_series?(series_url, article_url) do
      conn
      |> put_status(200)
      |> render("show_full.json", article: article)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"article_name" => article_url} = params) do
    case Article.series_exists?(article_url) do
      {:ok, articles} ->
        conn
        |> put_status(200)
        |> render("index_overview.json", articles: articles)
      _ ->
        case Article.exists?(article_url) do
          {:ok, article} ->
            conn
            |> put_status(200)
            |> render("show_full.json", article: article)
          {:error, status_code, error} ->
            conn
            |> put_status(status_code)
            |> render(PhpInternals.ErrorView, "error.json", error: error)
        end
    end
  end

  def create(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def create(%{user: %{privilege_level: 3}} = conn, params) do
    insert(conn, params)
  end

  def create(%{user: %{privilege_level: _pl}} = conn, _params) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def insert(conn, %{"article" => article}) do
    with {:ok} <- Article.contains_required_fields?(article),
         {:ok} <- Article.contains_only_expected_fields?(article),
         {:ok} <- Article.does_not_exist?(Utilities.make_url_friendly_name(article["title"])),
         {:ok, _user} <- User.user_exists?(article["author"]),
         {:ok} <- Category.valid_categories?(article["categories"]) do
      article =
        article
        |> Map.put("url", Utilities.make_url_friendly_name(article["title"]))
        |> Map.put("series_url", Utilities.make_url_friendly_name(article["series_name"]))
        |> Article.insert

      conn
      |> put_status(201)
      |> render("show_full.json", article: article)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def update(%{user: %{privilege_level: 3}} = conn, %{"article_name" => article_url, "article" => article}) do
    with {:ok, _article} <- Article.exists?(article_url),
         {:ok} <- Article.contains_required_fields?(article),
         {:ok} <- Article.contains_only_expected_fields?(article),
         {:ok} <- Category.valid_categories?(article["categories"]) do
      article =
        article
        |> Map.put("url", Utilities.make_url_friendly_name(article["title"]))
        |> Article.update(article_url)

      conn
      |> put_status(200)
      |> render("show_full.json", article: article)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def update(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def update(%{user: %{privilege_level: _pl}} = conn, _params) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def delete(%{user: %{privilege_level: 3}} = conn, %{"article_name" => article_url}) do
    with {:ok, _article} <- Article.exists?(article_url) do
      Article.soft_delete_article(article_url)

      conn
      |> send_resp(204, "")
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def delete(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def delete(conn, _params) do # privilege_level = 1 or 2
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end
end
