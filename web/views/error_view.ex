defmodule PhpInternals.ErrorView do
  use PhpInternals.Web, :view

  def render("error.json", %{error: error}) do
    %{error: %{message: error}}
  end

  def template_not_found(_template, assigns) do
    render "500.json", assigns
  end
end
