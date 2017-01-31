defmodule PhpInternals.Api.Docs.TypeView do
  use PhpInternals.Web, :view

  def render("index.json", %{types: types}) do
    %{types: render_many(types, PhpInternals.Api.Docs.TypeView, "type.json")}
  end

  def render("type.json", %{type: type}) do
    %{type: %{name: type["type"]}}
  end
end
