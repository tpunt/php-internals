defmodule PhpInternals.Site.HomeController do
  use PhpInternals.Web, :controller

  def index(conn, _params) do
    send_resp(conn, 200, "")
  end
end
