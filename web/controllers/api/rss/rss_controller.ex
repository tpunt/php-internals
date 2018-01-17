defmodule PhpInternals.Api.Rss.RssController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Utilities
  alias PhpInternals.Api.Articles.Article
  alias PhpInternals.Api.Rss.RssView
  alias PhpInternals.Cache.ResultCache

  def index(conn, _params) do
    {:ok, order_by} = Article.valid_order_by?(nil)
    key = "articles?#{order_by}&DESC&0&20&&&&.xml"

    result =
      ResultCache.fetch(key, fn ->
        %{"result" => %{"articles" => articles}} = Article.fetch_all(order_by, "DESC", 0, 20, nil, nil, nil, nil)
        ResultCache.group("articles", key)
        Phoenix.View.render_to_string(RssView, "index.xml", %{articles: articles, host: conn.host})
      end)

    conn
    |> put_layout(:none)
    |> put_resp_content_type("application/xml")
    |> Utilities.set_cache_control_header
    |> send_resp(200, result)
  end
end
