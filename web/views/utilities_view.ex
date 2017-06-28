defmodule PhpInternals.Api.UtilitiesView do
  use PhpInternals.Web, :view

  def render("meta.json", %{"total" => total, "offset" => offset, "limit" => limit}) do
    %{
      total: total,
      offset: offset,
      limit: limit,
      page_count: (if rem(total, limit) !== 0, do: div(total, limit) + 1, else: div(total, limit)),
      current_page: div(offset, limit) + 1
    }
  end
end
