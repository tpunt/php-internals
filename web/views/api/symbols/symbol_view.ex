defmodule PhpInternals.Api.Symbols.SymbolView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Symbols.SymbolView
  alias PhpInternals.Api.Categories.CategoryView
  alias PhpInternals.Api.Users.UserView

  def render("index.json", %{symbols: symbols}) do
    %{symbols: render_many(symbols, SymbolView, "show_overview_index.json")}
  end

  def render("index_patches_all.json", %{symbols_patches: %{inserts: inserts, patches: patches}}) do
    %{symbols_inserts: render_many(inserts, SymbolView, "show_insert.json"),
      symbols_patches: render_many(patches, SymbolView, "show_patches_changes.json")}
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

  def render("index_deleted.json", %{symbols: symbols}) do
    %{symbols_deleted: render_many(symbols, SymbolView, "show.json")}
  end

  def render("show.json", %{symbol: %{"symbol" => symbol}}) do
    %{symbol: render_one(symbol, SymbolView, "symbol.json")}
  end

  def render("show_overview.json", %{symbol: symbol}) do
    %{symbol: render_one(symbol, SymbolView, "symbol_overview.json")}
  end

  def render("show_overview_index.json", %{symbol: %{"symbol" => symbol}}) do
    %{symbol: render_one(symbol, SymbolView, "symbol_overview.json")}
  end

  def render("show_patches_changes.json", %{symbol: %{"symbol_patches" => symbol_updates}}) do
    %{
      symbol_patches: %{
        symbol: render_one(symbol_updates, SymbolView, "symbol.json"),
        patches: %{
          updates: render_many(symbol_updates["updates"], SymbolView, "show_update.json"),
          delete: symbol_updates["delete"]
        }
      }
    }
  end

  def render("show_insert.json", %{symbol: %{"symbol_insert" => symbol_insert}}) do
    %{symbol_insert: render_one(symbol_insert, SymbolView, "symbol_insert.json")}
  end

  def render("show_updates.json", %{symbol: %{"symbol_updates" => symbol_updates}}) do
    %{
      symbol_updates: %{
        symbol: render_one(symbol_updates, SymbolView, "symbol.json"),
        updates: render_many(symbol_updates["updates"], SymbolView, "symbol_update.json")
      }
    }
  end

  def render("show_update.json", %{symbol: %{"symbol_update" => symbol_update}}) do
    %{symbol_update: render_one(symbol_update, SymbolView, "symbol_update.json")}
  end

  def render("show_specific_update.json", %{symbol: %{"symbol_update" => symbol_update}}) do
    %{
      symbol_update: %{
        symbol: render_one(symbol_update, SymbolView, "symbol.json"),
        update: render_one(symbol_update, SymbolView, "symbol_update.json")
      }
    }
  end

  def render("show_delete.json", %{symbol: %{"symbol_delete" => symbol}}) do
    %{symbol_delete: %{symbol: render_one(symbol, SymbolView, "symbol.json")}}
  end


  def render("symbol.json", %{symbol: %{"symbol" => symbol, "categories" => categories}}) do
    return_symbol = %{
      id: symbol["id"],
      name: symbol["name"],
      url: symbol["url"],
      type: symbol["type"],
      declaration: symbol["declaration"],
      description: symbol["description"],
      definition: symbol["definition"],
      source_location: symbol["source_location"],
      additional_information: symbol["additional_information"],
      revision_id: symbol["revision_id"]
    }

    return_symbol
    |> Map.merge(render_type(symbol))
    |> Map.merge(CategoryView.render("index_overview.json", %{categories: categories}))
  end

  def render("symbol_overview.json", %{symbol: %{"symbol" => symbol, "categories" => categories}}) do
    %{id: symbol["id"], name: symbol["name"], url: symbol["url"], type: symbol["type"]}
    |> Map.merge(CategoryView.render("index_overview.json", %{categories: categories}))
  end

  def render("symbol_overview.json", %{symbol: %{"symbol" => symbol}}) do
    %{id: symbol["id"], name: symbol["name"], url: symbol["url"], type: symbol["type"]}
  end

  # for user contributions
  def render("symbol_overview.json", %{symbol: symbol}) do
    %{id: symbol["id"], name: symbol["name"], url: symbol["url"], type: symbol["type"]}
  end

  def render("symbol_insert.json", %{symbol: symbol_update}) do
    %{
      symbol: render_one(symbol_update, SymbolView, "symbol.json"),
      user: UserView.render("user_overview.json", %{user: %{"user" => symbol_update["user"]}}),
      date: symbol_update["date"]
    }
  end

  def render("symbol_update.json", %{symbol: %{"date" => date, "update" => update, "user" => user}}) do
    %{
      symbol: render_one(update, SymbolView, "symbol.json")
        |> Map.put(:against_revision, update["symbol"]["against_revision"]),
      user: UserView.render("user_overview.json", %{user: %{"user" => user}}),
      date: date
    }
  end


  defp render_type(%{"type" => "function"} = symbol) do
    %{parameters: symbol["parameters"],
      return_type: symbol["return_type"],
      return_description: symbol["return_description"]}
  end

  defp render_type(%{"type" => "macro"} = symbol) do
    %{parameters: symbol["parameters"]}
  end

  defp render_type(%{"type" => "type"} = symbol) do
    %{members: symbol["members"]}
  end

  defp render_type(%{"type" => type}) when type == "variable" do
    %{}
  end
end
