defmodule PhpInternals.Api.Symbols.SymbolView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Symbols.SymbolView
  alias PhpInternals.Api.Categories.CategoryView

  def render("index.json", %{symbols: symbols}) do
    %{symbols: render_many(symbols, SymbolView, "show_overview.json")}
  end

  def render("index_deleted.json", %{symbols: symbols}) do
    %{symbols_deleted: render_many(symbols, SymbolView, "show.json")}
  end

  def render("index_patches_all.json", %{symbols_patches: %{inserts: inserts, patches: patches}}) do
    %{symbols_inserts: render_many(inserts, SymbolView, "show_insert.json"),
      symbols_patches: render_many(patches, SymbolView, "show_patches_changes.json")}
  end

  def render("show_patches_changes.json", %{symbol: %{"symbol_patches" => %{"symbol" => symbol, "patches" => %{"updates" => updates, "delete" => delete}}}}) do
    %{symbol_patches:
      %{symbol: render_one(symbol, SymbolView, "symbol.json"), patches:
        %{updates: render_many(updates, SymbolView, "show_updates2.json"), delete: delete}}}
  end

  def render("show_updates2.json", %{symbol: symbol_update}) do
    render_one(symbol_update, SymbolView, "symbol_update.json")
  end

  def render("index_patches_insert.json", %{symbols_patches: symbols_patches}) do
    %{symbols_inserts: render_many(symbols_patches, SymbolView, "show_insert.json")}
  end

  def render("index_patches_update.json", %{symbols_patches: symbols_patches}) do
    %{symbols_updates: render_many(symbols_patches, SymbolView, "show_updates.json")}
  end

  def render("index_patches_delete.json", %{symbols_patches: symbols_patches}) do
    %{symbols_deletes: render_many(symbols_patches, SymbolView, "show_delete.json")}
  end

  def render("show_overview.json", %{symbol: symbol}) do
    %{symbol: render_one(symbol, SymbolView, "symbol_overview.json")}
  end

  def render("show.json", %{symbol: symbol}) do
    %{symbol: render_one(symbol, SymbolView, "symbol.json")}
  end

  def render("show_insert.json", %{symbol: %{"symbol_insert" => symbol_insert}}) do
    %{symbol_insert: %{symbol: render_one(symbol_insert, SymbolView, "symbol.json")}}
  end

  def render("show_update.json", %{symbol: %{"symbol_update" => %{"symbol" => symbol, "update" => update}}}) do
    %{symbol_update:
      %{symbol: render_one(symbol, SymbolView, "symbol.json"),
        update: render_one(update, SymbolView, "symbol.json")}}
  end

  def render("show_updates.json", %{symbol: %{"symbol_updates" => %{"symbol" => symbol, "updates" => updates}}}) do
    %{symbol_updates:
      %{symbol: render_one(symbol, SymbolView, "symbol.json"),
        updates: render_many(updates, SymbolView, "symbol_update.json")}}
  end

  def render("show_delete.json", %{symbol: %{"symbol_delete" => %{"symbol" => symbol}}}) do
    %{symbol_delete: %{symbol: render_one(symbol, SymbolView, "symbol.json")}}
  end

  def render("show_patches.json", %{symbol_patches: symbol_patches}) do
    render_one(symbol_patches, SymbolView, "show_updates.json")
    |> Map.merge(render_one(symbol_patches, SymbolView, "show_delete.json"))
  end

  def render("symbol_overview.json", %{symbol: %{"symbol" => symbol}}) do
    %{name: symbol["name"], url: symbol["url"], type: symbol["type"]}
  end

  # for fetch_all_symbols_full
  def render("symbol_overview.json", %{symbol: symbol}) do
    render_one(%{"symbol" => symbol}, SymbolView, "symbol_overview.json")
  end

  def render("symbol_update.json", %{symbol: %{"update" => %{"symbol" => symbol}}}) do
    %{update: render_one(symbol, SymbolView, "symbol.json")}
  end

  def render("symbol_update.json", %{symbol: symbol}) do
    %{update: render_one(symbol, SymbolView, "symbol.json")}
  end

  def render("symbol.json", %{symbol: %{"symbol" => symbol}}) do
    return_symbol = %{
      name: symbol["name"],
      url: symbol["url"],
      type: symbol["type"],
      declaration: symbol["declaration"],
      description: symbol["description"],
      definition: symbol["definition"],
      definition_location: symbol["definition_location"],
      example: symbol["example"],
      example_explanation: symbol["example_explanation"],
      notes: symbol["notes"],
      revision_id: symbol["revision_id"]
    }

    return_symbol
    |> Map.merge(render_type(symbol))
    |> Map.merge(CategoryView.render("index_overview.json", %{categories: symbol["categories"]}))
  end

  # for fetch_all_symbols_patches
  def render("symbol.json", %{symbol: symbol}) do
    render_one(%{"symbol" => symbol}, SymbolView, "symbol.json")
  end

  def render_type(%{"type" => "function"} = symbol) do
    %{parameters: symbol["parameters"],
      return_type: symbol["return_type"],
      return_description: symbol["return_description"]}
  end

  def render_type(%{"type" => "macro"} = symbol) do
    %{parameters: symbol["parameters"]}
  end

  def render_type(%{"type" => type}) when type in ["type", "variable"] do
    %{}
  end
end
