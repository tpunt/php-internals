defmodule PhpInternals.Api.Rss.RssView do
  use PhpInternals.Web, :view

  def parse_markdown(markdown), do: Earmark.as_html!(markdown)

  def render_date(timestamp) do
    timestamp
    |> div(1000)
    |> Calendar.DateTime.Parse.unix!
    |> Calendar.DateTime.Format.rfc2822()
  end
end
