defmodule PhpInternals.Api.Articles.ArticleController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Categories.Category
  alias PhpInternals.Api.Articles.Article
  alias PhpInternals.Api.Users.User
  alias PhpInternals.Utilities

  def index(conn, params) do
    with {:ok, order_by} <- Article.valid_order_by?(params["order_by"]),
         {:ok, ordering} <- Utilities.valid_ordering?(params["ordering"]),
         {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]),
         {:ok, _category} <- Category.valid_cache?(params["category"]),
         {:ok, _user} <- User.valid_optional?(params["author"]) do
      articles = Article.fetch_all_cache(order_by, ordering, offset, limit, params["category"], params["author"], params["search"], params["full_search"])

      conn
      |> Utilities.set_cache_control_header
      |> send_resp(200, articles)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"series_name" => series_url, "article_name" => article_url}) do
    with {:ok, article} <- Article.valid_in_series_cache?(series_url, article_url) do
      conn
      |> Utilities.set_cache_control_header
      |> send_resp(200, article)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"article_name" => article_url}) do
    case Article.valid_series_cache?(article_url) do
      {:ok, articles} ->
        conn
        |> Utilities.set_cache_control_header
        |> send_resp(200, articles)
      _ ->
        case Article.valid_cache?(article_url) do
          {:ok, article} ->
            conn
            |> Utilities.set_cache_control_header
            |> send_resp(200, article)
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
         {:ok, article_url_name} <- Utilities.is_url_friendly?(article["title"]),
         {:ok, series_url_name} <- Utilities.is_url_friendly_opt?(article["series_name"]),
         {:ok} <- Article.not_valid?("", article_url_name),
         {:ok} <- Category.all_valid?(article["categories"]) do
      article =
        article
        |> Map.put("url", article_url_name)
        |> Map.put("series_name", article["series_name"] || "")
        |> Map.put("series_url", series_url_name)
        |> Article.insert(conn.user.username)

      conn
      |> send_resp(201, article)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def update(%{user: %{privilege_level: 3}} = conn, %{"article_name" => article_url, "article" => article}) do
    with {:ok, %{"article" => current_article}} <- Article.valid?(article_url),
         {:ok} <- Article.contains_required_fields?(article),
         {:ok} <- Article.contains_only_expected_fields?(article),
         {:ok, article_url_name} <- Utilities.is_url_friendly?(article["title"]),
         {:ok, series_url_name} <- Utilities.is_url_friendly_opt?(article["series_name"]),
         {:ok} <- Article.not_valid?(article_url, article_url_name),
         {:ok} <- Category.all_valid?(article["categories"]) do
      article =
        article
        |> Map.put("url", article_url_name)
        |> Map.put("series_name", article["series_name"] || "")
        |> Map.put("series_url", series_url_name)
        |> Article.update(current_article, conn.user.username)

      conn
      |> send_resp(200, article)
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
    with {:ok, article} <- Article.valid?(article_url) do
      Article.soft_delete(article["series_url"], article_url)

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
