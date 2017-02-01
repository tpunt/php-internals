defmodule PhpInternals.Api.Docs.Symbol do
  use PhpInternals.Web, :model

  @default_order_by "name"
  @valid_order_bys ["name"]
  @required_fields [
    "name",
    "description",
    "definition",
    "definition_location",
    "type",
    "categories"
  ]
  @optional_fields [
    "declaration",
    "parameters",
    "example",
    "example_explanation",
    "notes",
    "return_type",
    "return_description"
  ]

  def contains_required_fields?(symbol) do
    if @required_fields -- Map.keys(symbol) === [] and special_required_fields?(symbol) do
      {:ok}
    else
      {:error, 400, "Required fields are missing"}
    end
  end

  defp special_required_fields?(%{"type" => "function"} = symbol) do
    ["parameters", "declaration"] -- Map.keys(symbol) === []
  end

  defp special_required_fields?(_symbol), do: true

  def contains_only_expected_fields?(symbol) do
    if Map.keys(symbol) -- (@required_fields ++ @optional_fields) === [] do
      {:ok}
    else
      {:error, 400, "Contains unknown fields"}
    end
  end

  def valid_order_by?(order_by) do
    if order_by === nil do
      {:ok, @default_order_by}
    else
      if Enum.member?(@valid_order_bys, order_by) do
        {:ok, order_by}
      else
        {:error, 400, "Invalid order by field given"}
      end
    end
  end

  def symbol_exists?(url) do
    query = "MATCH (symbol:Symbol {url: {url}}) RETURN symbol"
    params = %{url: url}
    result = Neo4j.query!(Neo4j.conn, query, params)

    if result == [] do
      {:error, 404, "The specified symbol could not be found"}
    else
      {:ok, List.first result}
    end
  end

  def is_deleted?(symbol_url) do
    query = """
      MATCH (symbol:SymbolDeleted {url: {url}})-[:CATEGORY]->(c:Category)
      RETURN symbol, collect({name: c.name, url: c.url}) AS categories
    """

    params = %{url: symbol_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "The specified deleted symbol could not be found"}
    else
      categories = Enum.map(result["categories"], &(%{"category" => &1}))

      {:ok, %{"symbol_deleted" => Map.merge(result["symbol"], %{"categories" => categories})}}
    end
  end

  def is_insert_patch?(symbol_url) do
    query = """
      MATCH (symbol:InsertSymbolPatch {url: {url}})-[:CATEGORY]->(c:Category)
      RETURN symbol, collect({name: c.name, url: c.url}) AS categories
    """

    params = %{url: symbol_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "The specified symbol insert patch could not be found"}
    else
      categories = Enum.map(result["categories"], &(%{"category" => &1}))

      {:ok, %{"symbol_insert" => Map.merge(result["symbol"], %{"categories" => categories})}}
    end
  end

  def is_delete_patch?(symbol_url) do
    query = """
      MATCH (c:Category)<-[:CATEGORY]-(symbol:Symbol {url: {url}})-[:DELETE]->(:DeleteSymbolPatch)
      RETURN symbol, collect({name: c.name, url: c.url}) AS categories
    """

    params = %{url: symbol_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "The specified symbol delete patch could not be found"}
    else
      %{"symbol" => symbol, "categories" => categories} = result

      categories = Enum.map(categories, &(%{"category" => &1}))
      symbol = Map.merge(symbol, %{"categories" => categories})

      {:ok, %{"symbol_delete" => %{"symbol" => symbol}}}
    end
  end

  def update_patch_exists?(symbol_url, patch_id) do
    query = """
      MATCH (c1:Category)<-[:CATEGORY]-(s1:Symbol {url: {url}})-[:UPDATE]->(s2:UpdateSymbolPatch {revision_id: {patch_id}})-[:CATEGORY]->(c2:Category)
      RETURN {symbol: s1, categories: collect(c1), update: {symbol: s2, categories: collect(c2)}} AS symbol_update
    """

    params = %{url: symbol_url, patch_id: patch_id}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "The specified symbol update patch could not be found"}
    else
      %{"symbol_update" =>
        %{"symbol" => symbol1, "categories" => categories1, "update" =>
          %{"symbol" => symbol2, "categories" => categories2}}}  = result

      categories1 = Enum.map(categories1, &(%{"category" => &1}))
      categories2 = Enum.map(categories2, &(%{"category" => &1}))

      {:ok, %{"symbol_update" =>
        %{"symbol" => Map.merge(symbol1, %{"categories" => categories1}), "update" =>
          %{"symbol" => Map.merge(symbol2, %{"categories" => categories2})}}}}
    end
  end

  def has_patches?(symbol_url) do
    query = """
      MATCH (c1:Category)<-[:CATEGORY]-(s:Symbol {url: {url}})
      OPTIONAL MATCH (s)-[:UPDATE]->(su:UpdateSymbolPatch)-[:CATEGORY]->(c2:Category)
      OPTIONAL MATCH (s)-[:DELETE]->(sd:DeleteSymbolPatch)
      WITH c1, s, sd, {categories: CASE c2 WHEN NULL THEN [] ELSE collect({name: c2.name, url: c2.url}) END, update: su} AS sus
      RETURN {
        symbol: s,
        categories: collect({name: c1.name, url: c1.url}),
        patches: {
          updates: collect(CASE sus.update WHEN NULL THEN NULL ELSE sus END),
          delete: CASE sd WHEN NULL THEN 0 ELSE 1 END
        }
      } AS symbol_patches
    """

    params = %{url: symbol_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    %{"symbol_patches" =>
      %{"categories" => categories, "symbol" => symbol, "patches" =>
        %{"delete" => delete, "updates" => updates}}} = result

    updates =
      Enum.map(updates, fn %{"categories" => categories, "update" => update} ->
        %{"update" => %{"symbol" => Map.merge(update, %{"categories" => categories})}}
      end)

    symbol = Map.merge(symbol, %{"categories" => categories})

    {:ok, %{"symbol_patches" => %{"symbol" => symbol, "patches" => %{"delete" => delete, "updates" => updates}}}}
  end

  def revision_ids_match?(symbol_url, patch_revision_id) do
    query = """
      MATCH (s1:Symbol {url: {url}})-[:UPDATE]->(s2:UpdateSymbolPatch {revision_id: {patch_id}})
      WHERE s2.against_revision = s1.revision_id
      RETURN s1
    """

    params = %{url: symbol_url, patch_id: patch_revision_id}

    result = Neo4j.query!(Neo4j.conn, query, params)

    if result === [] do
      {:error, 400, "Cannot apply patch due to revision ID mismatch"}
    else
      {:ok}
    end
  end

  def fetch_all_symbols(order_by, ordering, offset, limit) do
    query = """
      MATCH (symbol:Symbol)
      RETURN symbol
      ORDER BY symbol.#{order_by} #{ordering}
      SKIP #{offset}
      LIMIT #{limit}
    """

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_symbols_patches do
    query = """
      MATCH (c1:Category)<-[:CATEGORY]-(symbol:Symbol)-[:UPDATE]->(su:UpdateSymbolPatch)-[:CATEGORY]->(c2:Category)
      OPTIONAL MATCH (symbol)-[:DELETE]->(sd:DeleteSymbolPatch)
      WITH c1, symbol, sd, {categories: collect({name: c2.name, url: c2.url}), update: su} AS sus
      RETURN {
        symbol: symbol,
        categories: collect({name: c1.name, url: c1.url}),
        patches: {
          updates: collect(sus),
          delete: CASE sd WHEN NULL THEN 0 ELSE 1 END
        }
      } AS symbol_patches
      UNION
      MATCH (c:Category)<-[:CATEGORY]-(symbol:Symbol)-[:DELETE]->(sd:DeleteSymbolPatch)
      OPTIONAL MATCH (symbol)-[:UPDATE]->(su:UpdateSymbolPatch)-[:CATEGORY]->(c:Category)
      WHERE su = NULL
      RETURN {
        symbol: symbol,
        categories: collect({name: c.name, url: c.url}),
        patches: {updates: [], delete: 1}
      } AS symbol_patches
    """

    patches =
      Neo4j.query!(Neo4j.conn, query)
      |> Enum.map(fn result ->
          case result do
            %{"symbol_patches" => %{"categories" => categories, "symbol" => symbol, "patches" => patches}} ->
              %{"symbol_patches" => %{"patches" => patches, "symbol" => Map.merge(symbol, %{"categories" => categories})}}
            _ ->
              result
          end
        end)
      |> Enum.map(fn result ->
          case result do
            %{"symbol_patches" => %{"symbol" => symbol, "patches" => %{"delete" => delete, "updates" => updates}}} when updates != [] ->
              updates =
                updates
                |> Enum.map(fn %{"categories" => categories, "update" => update} ->
                    %{"update" => %{"symbol" => Map.merge(update, %{"categories" => categories})}}
                  end)
              %{"symbol_patches" => %{"symbol" => symbol, "patches" => %{"delete" => delete, "updates" => updates}}}
            _ ->
              result
          end
        end)

    %{inserts: fetch_all_symbols_patches_insert,
      patches: patches}
  end

  def fetch_all_symbols_patches_insert do
    query = """
      MATCH (symbol:InsertSymbolPatch)-[:CATEGORY]-(c:Category)
      RETURN {symbol: symbol, categories: collect({name: c.name, url: c.url})} as symbol_insert
    """

    Neo4j.query!(Neo4j.conn, query)
    |> Enum.map(fn %{"symbol_insert" => %{"categories" => cats, "symbol" => s}} ->
      cats = Enum.map(cats, fn cat -> %{"category" => cat} end)
      %{"symbol_insert" => Map.merge(s, %{"categories" => cats})}
    end)
  end

  def fetch_all_symbols_patches_update do
    query = """
      MATCH (c1:Category)<-[:CATEGORY]-(symbol:Symbol)-[:UPDATE]->(su:UpdateSymbolPatch)-[:CATEGORY]->(c2:Category)
      WITH c1, symbol, {categories: collect({name: c2.name, url: c2.url}), update: su} AS sus
      RETURN {
        symbol: symbol,
        categories: collect({name: c1.name, url: c1.url}),
        updates: collect(sus)
      } AS symbol_update
    """

    Neo4j.query!(Neo4j.conn, query)
    |> Enum.map(fn %{"symbol_update" => %{"categories" => categories, "symbol" => symbol, "updates" => updates}} ->
        %{"symbol_updates" => %{"updates" => updates, "symbol" => Map.merge(symbol, %{"categories" => categories})}}
      end)
    |> Enum.map(fn result ->
        case result do
          %{"symbol_updates" => %{"symbol" => symbol, "updates" => updates}} ->
            updates =
              updates
              |> Enum.map(fn %{"categories" => categories, "update" => update} ->
                  %{"update" => %{"symbol" => Map.merge(update, %{"categories" => categories})}}
                end)
            %{"symbol_updates" => %{"symbol" => symbol, "updates" => updates}}
          _ ->
            result
        end
      end)
  end

  def fetch_all_symbols_patches_delete do
    query = """
      MATCH (c:Category)<-[:CATEGORY]-(symbol:Symbol)-[:DELETE]->(:DeleteSymbolPatch)
      RETURN {
        symbol: symbol,
        categories: collect({name: c.name, url: c.url})
      } AS symbol_delete
    """

    Neo4j.query!(Neo4j.conn, query)
    |> Enum.map(fn %{"symbol_delete" => %{"categories" => categories, "symbol" => symbol}} ->
        %{"symbol_delete" => %{"symbol" => Map.merge(symbol, %{"categories" => categories})}}
      end)
  end

  def fetch_all_symbols_deleted do
    query = """
      MATCH (c:Category)<-[:CATEGORY]-(s:SymbolDeleted)
      RETURN {
        symbol: s,
        categories: collect({name: c.name, url: c.url})
      } AS symbol
    """

    Neo4j.query!(Neo4j.conn, query)
    |> Enum.map(fn %{"symbol" => %{"categories" => categories, "symbol" => symbol}} ->
        %{"symbol" => Map.merge(symbol, %{"categories" => categories})}
      end)
  end

  def fetch(symbol_url, "normal") do
    query = """
      MATCH (symbol:Symbol {url: {symbol_url}})-[r:CATEGORY]-(category:Category)
      RETURN symbol, collect({name: category.name, url: category.url}) AS categories
    """

    params = %{symbol_url: symbol_url}

    result = Neo4j.query!(Neo4j.conn, query, params)

    if result == [] do
      {:error, 404, "Symbol not found"}
    else
      [%{"categories" => categories, "symbol" => symbol}] = result

      categories = Enum.map(categories, &(%{"category" => &1}))

      {:ok, %{"symbol" => Map.merge(symbol, %{"categories" => categories})}}
    end
  end

  def fetch(symbol_url, "overview") do
    query = """
      MATCH (symbol:Symbol {url: {symbol_url}})
      RETURN {name: symbol.name, url: symbol.url, type: symbol.type} AS symbol
    """

    params = %{symbol_url: symbol_url}

    result = Neo4j.query!(Neo4j.conn, query, params)

    if result == [] do
      {:error, 404, "Symbol not found"}
    else
      [symbol] = result

      {:ok, symbol}
    end
  end

  def fetch(symbol_url, "full") do
    query = """
      MATCH (symbol:Symbol {url: {url}})-[r:CATEGORY]-(category:Category)
      RETURN symbol, collect(category) AS categories
    """

    params = %{url: symbol_url}

    result = Neo4j.query!(Neo4j.conn, query, params)

    if result === [] do
      {:error, 404, "Symbol not found"}
    else
      [%{"categories" => categories, "symbol" => symbol}] = result

      categories = Enum.map(categories, &(%{"category" => &1}))

      {:ok, %{"symbol" => Map.merge(symbol, %{"categories" => categories})}}
    end
  end

  def fetch_symbol_update_patches(symbol_url) do
    query = """
      MATCH (c1:Category)<-[:CATEGORY]-(s1:Symbol {url: {url}})
      OPTIONAL MATCH (s1)-[:UPDATE]->(s2:UpdateSymbolPatch)-[:CATEGORY]->(c2:Category)
      WITH c1, s1, s2, collect({name: c2.name, url: c2.url}) AS c2s
      RETURN {
        symbol: s1,
        categories: collect({name: c1.name, url: c1.url}),
        updates: CASE s2 WHEN NULL THEN [] ELSE collect({symbol: s2, categories: c2s}) END
      } AS symbol_updates
    """

    params = %{url: symbol_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    %{"symbol_updates" => %{"symbol" => symbol, "categories" => categories, "updates" => updates}} = result

    updates =
      Enum.map(updates, fn %{"symbol" => symbol, "categories" => categories} ->
        categories = Enum.map(categories, &(%{"category" => &1}))

        %{"symbol" => Map.merge(symbol, %{"categories" => categories})}
      end)

    categories = Enum.map(categories, &(%{"category" => &1}))
    symbol = Map.merge(symbol, %{"categories" => categories})

    %{"symbol_updates" => %{"symbol" => symbol, "updates" => updates}}
  end

  def insert(symbol, review) do
    query1 =
      Map.keys(symbol)
      |> Enum.filter(fn key -> key !== "categories" end)
      |> Enum.map(fn key -> "#{key}: {#{key}}" end)
      |> Enum.join(",")

    query1 =
      case review do
        0 -> "CREATE (symbol:Symbol {revision_id: {revision_id}, " <> query1 <> "})"
        1 -> "CREATE (symbol:InsertSymbolPatch {revision_id: {revision_id}, " <> query1 <> "})"
      end

    {query2, params1, _counter} =
      symbol["categories"]
      |> Enum.reduce({"", %{}, 0}, fn (cat, {queries, params, n}) ->
        query = """
          WITH symbol
          MATCH (cat#{n}:Category {url: {cat#{n}_url}})
          CREATE (symbol)-[:CATEGORY]->(cat#{n})
        """
        {queries <> query, Map.put(params, "cat#{n}_url", cat), n + 1}
      end)

    query3 = """
      WITH symbol
      MATCH (symbol)-[crel:CATEGORY]->(category:Category)
      RETURN symbol, collect(category) as categories
    """

    query = query1 <> query2 <> query3

    params2 = %{
      name: symbol["name"],
      url: symbol["url"],
      type: symbol["type"],
      description: symbol["description"],
      declaration: symbol["declaration"],
      parameters: symbol["parameters"],
      return_type: symbol["return_type"],
      return_description: symbol["return_description"],
      definition: symbol["definition"],
      definition_location: symbol["definition_location"],
      example: symbol["example"],
      example_explanation: symbol["example_explanation"],
      notes: symbol["notes"],
      revision_id: :rand.uniform(100_000_000)
    }

    params = Map.merge(params1, params2)

    [%{"categories" => categories, "symbol" => symbol}] = Neo4j.query!(Neo4j.conn, query, params)

    categories = Enum.map(categories, &(%{"category" => &1}))

    %{"symbol" => Map.merge(symbol, %{"categories" => categories})}
  end

  def update(new_symbol, old_symbol, 0) do
    query1 = """
      MATCH (old_symbol:Symbol {url: {old_url}})
      OPTIONAL MATCH (old_symbol)-[r1:UPDATE]->(su:UpdateSymbolPatch)
      OPTIONAL MATCH (old_symbol)-[r2:DELETE]->(sd:DeleteSymbolPatch)
      REMOVE old_symbol:Symbol
      SET old_symbol:SymbolRevision
      DELETE r1, r2
      WITH old_symbol, collect(su) as sus, sd
    """

    query2 =
      Map.keys(old_symbol)
      |> Enum.filter(fn key -> key !== "categories" end)
      |> Enum.map(fn key -> "#{key}: {new_#{key}}" end)
      |> Enum.join(",")

    query2 = """
      CREATE (new_symbol:Symbol {#{query2}}),
        (new_symbol)-[:REVISION]->(old_symbol)
    """

    {queries, params1, _counter} =
      new_symbol["categories"]
      |> Enum.reduce({[], %{}, 0},
        fn cat, {queries, params, n} ->
          {queries ++ ["""
            WITH new_symbol, sus, sd
            MATCH (cat#{n}:Category {url: {cat#{n}_url}})
            WITH cat#{n}, new_symbol, sus, sd
            CREATE (new_symbol)-[:CATEGORY]->(cat#{n})
          """], Map.put(params, "cat#{n}_url", cat), n + 1}
        end)

    query3 = Enum.join(queries, " ")

    query4 = """
      WITH new_symbol, sus, sd
      FOREACH (su IN sus |
        CREATE (new_symbol)-[:UPDATE]->(su)
      )
      FOREACH (unused IN CASE sd WHEN NULL THEN [] ELSE [1] END |
        CREATE (new_symbol)-[:DELETE]->(sd)
      )
      WITH new_symbol
      MATCH (new_symbol)-[:CATEGORY]->(category:Category)
      RETURN new_symbol as symbol, collect(category) as categories
    """

    query = query1 <> query2 <> query3 <> query4

    params2 = %{
      new_name: new_symbol["name"],
      new_url: new_symbol["url"],
      new_type: new_symbol["type"],
      new_description: new_symbol["description"],
      new_declaration: new_symbol["declaration"],
      new_parameters: new_symbol["parameters"],
      new_return_type: new_symbol["return_type"],
      new_return_description: new_symbol["return_description"],
      new_definition: new_symbol["definition"],
      new_definition_location: new_symbol["definition_location"],
      new_example: new_symbol["example"],
      new_example_explanation: new_symbol["example_explanation"],
      new_notes: new_symbol["notes"],
      new_revision_id: :rand.uniform(100_000_000),
      old_url: old_symbol["url"]
    }

    params = Map.merge(params1, params2)

    [%{"categories" => categories, "symbol" => symbol}] = Neo4j.query!(Neo4j.conn, query, params)

    categories = Enum.map(categories, &(%{"category" => &1}))

    %{"symbol" => Map.merge(symbol, %{"categories" => categories})}
  end

  def update(new_symbol, old_symbol, 1) do
    query1 = """
      MATCH (old_symbol:Symbol {url: {old_url}})
      WITH old_symbol
    """

    query2 =
      Map.keys(old_symbol)
      |> Enum.filter(fn key -> key !== "categories" end)
      |> Enum.map(fn key -> "#{key}: {new_#{key}}" end)
      |> Enum.join(",")

    query2 = """
      CREATE (new_symbol:UpdateSymbolPatch {against_revision: {against_revision}, #{query2}}),
        (old_symbol)-[:UPDATE]->(new_symbol)
      WITH new_symbol
    """

    {queries, params1, _counter} =
      new_symbol["categories"]
      |> Enum.reduce({[], %{}, 0},
        fn cat, {queries, params, n} ->
          {queries ++ ["""
            MATCH (cat#{n}:Category {url: {cat#{n}_url}})
            WITH cat#{n}, new_symbol
            CREATE (new_symbol)-[:CATEGORY]->(cat#{n})
            WITH new_symbol
          """], Map.put(params, "cat#{n}_url", cat), n + 1}
        end)

    query3 = Enum.join(queries, " ")

    query4 = """
      WITH new_symbol
      MATCH (new_symbol)-[:CATEGORY]->(category:Category)
      RETURN new_symbol as symbol, collect(category) as categories
    """

    query = query1 <> query2 <> query3 <> query4

    params2 = %{
      new_name: new_symbol["name"],
      new_url: new_symbol["url"],
      new_type: new_symbol["type"],
      new_description: new_symbol["description"],
      new_declaration: new_symbol["declaration"],
      new_parameters: new_symbol["parameters"],
      new_return_type: new_symbol["return_type"],
      new_return_description: new_symbol["return_description"],
      new_definition: new_symbol["definition"],
      new_definition_location: new_symbol["definition_location"],
      new_example: new_symbol["example"],
      new_example_explanation: new_symbol["example_explanation"],
      new_notes: new_symbol["notes"],
      new_revision_id: :rand.uniform(100_000_000),
      against_revision: old_symbol["revision_id"],
      old_url: old_symbol["url"]
    }

    params = Map.merge(params1, params2)

    [%{"categories" => categories, "symbol" => symbol}] = Neo4j.query!(Neo4j.conn, query, params)

    categories = Enum.map(categories, &(%{"category" => &1}))

    %{"symbol" => Map.merge(symbol, %{"categories" => categories})}
  end

  def accept_symbol_patch(symbol_url, "insert") do
    query = """
      MATCH (symbol:InsertSymbolPatch {url: {url}})-[:CATEGORY]->(c:Category)
      REMOVE symbol:InsertSymbolPatch
      SET symbol:Symbol
      RETURN symbol, collect({name: c.name, url: c.url}) AS categories
    """

    params = %{url: symbol_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "Insert patch not found"}
    else
      %{"symbol" => symbol, "categories" => categories} = result

      {:ok, %{"symbol" => Map.merge(symbol, %{"categories" => categories})}}
    end
  end

  def accept_symbol_patch(symbol_url, "delete") do
    query = """
      MATCH (symbol:Symbol {url: {url}})-[r:DELETE]->(sd:DeleteSymbolPatch)
      REMOVE symbol:Symbol
      SET symbol:SymbolDeleted
      DELETE r, sd
      RETURN symbol
    """

    params = %{url: symbol_url}

    result = Neo4j.query!(Neo4j.conn, query, params)

    if result === [] do
      {:error, 404, "Delete patch not found"}
    else
      {:ok, 204}
    end
  end

  def accept_symbol_patch(symbol_url, update_or_error) do
    output = String.split(update_or_error, ",")

    if length(output) !== 2 do
      {:error, 400, "Unknown or malformed patch type"}
    else
      [update, for_revision] = output

      if update !== "update" do
        {:error, 400, "Unknown patch type"}
      else
        accept_symbol_patch(symbol_url, update, String.to_integer(for_revision))
      end
    end
  end

  def accept_symbol_patch(symbol_url, "update", patch_revision_id) do
    with {:ok, _symbol} <- update_patch_exists?(symbol_url, patch_revision_id),
         {:ok} <- revision_ids_match?(symbol_url, patch_revision_id) do
      query = """
        MATCH (old_symbol:Symbol {url: {old_url}})-[r1:UPDATE]->(new_symbol:UpdateSymbolPatch {revision_id: {patch_id}})
        DELETE r1

        WITH old_symbol, new_symbol

        OPTIONAL MATCH (old_symbol)-[r2:UPDATE]->(su:UpdateSymbolPatch)
        OPTIONAL MATCH (old_symbol)-[r3:DELETE]->(sd:DeleteSymbolPatch)
        REMOVE old_symbol:Symbol
        REMOVE new_symbol:UpdateSymbolPatch
        REMOVE new_symbol.against_revision
        SET old_symbol:SymbolRevision
        SET new_symbol:Symbol
        DELETE r2, r3

        WITH old_symbol, new_symbol, collect(su) as sus, sd

        CREATE (new_symbol)-[:REVISION]->(old_symbol)
        FOREACH (su IN sus |
          CREATE (new_symbol)-[:UPDATE]->(su)
        )
        FOREACH (unused IN CASE sd WHEN NULL THEN [] ELSE [1] END |
          CREATE (new_symbol)-[:DELETE]->(sd)
        )

        WITH new_symbol

        MATCH (new_symbol)-[:CATEGORY]->(category:Category)
        RETURN new_symbol as symbol, collect(category) as categories
      """

      params = %{
        old_url: symbol_url,
        patch_id: patch_revision_id
      }

      [%{"categories" => categories, "symbol" => symbol}] = Neo4j.query!(Neo4j.conn, query, params)

      categories = Enum.map(categories, &(%{"category" => &1}))

      {:ok, %{"symbol" => Map.merge(symbol, %{"categories" => categories})}}
    else
      error ->
        error
    end
  end

  def discard_symbol_patch(symbol_url, "insert") do
    with {:ok, _symbol} <- is_insert_patch?(symbol_url) do
      query = """
        MATCH (s:InsertSymbolPatch {url: {url}})
        REMOVE s:InsertSymbolPatch
        SET s:InsertSymbolPatchDeleted
      """

      params = %{url: symbol_url}

      Neo4j.query!(Neo4j.conn, query, params)

      {:ok, 200}
    else
      error ->
        error
    end
  end

  def discard_symbol_patch(symbol_url, "delete") do
    with {:ok, _symbol} <- is_delete_patch?(symbol_url) do
      query = """
        MATCH (s:Symbol {url: {url}})-[r:DELETE]-(sd:DeleteSymbolPatch)
        DELETE r, sd
      """

      params = %{url: symbol_url}

      Neo4j.query!(Neo4j.conn, query, params)

      {:ok, 200}
    else
      error ->
        error
    end
  end

  def discard_symbol_patch(symbol_url, update_or_error) do
    output = String.split(update_or_error, ",")

    if length(output) !== 2 do
      {:error, 400, "Unknown or malformed patch type"}
    else
      [update, for_revision] = output

      if update !== "update" do
        {:error, 400, "Unknown patch type"}
      else
        discard_symbol_patch(symbol_url, update, String.to_integer(for_revision))
      end
    end
  end

  def discard_symbol_patch(symbol_url, "update", patch_revision_id) do
    with {:ok, _symbol} <- update_patch_exists?(symbol_url, patch_revision_id) do
      query = """
        MATCH (s:UpdateSymbolPatch {revision_id: {revision_id}})
        REMOVE s:UpdateSymbolPatch
        SET s:UpdateSymbolPatchDeleted
      """

      params = %{revision_id: patch_revision_id}

      Neo4j.query!(Neo4j.conn, query, params)

      {:ok, 200}
    else
      error ->
        error
    end
  end

  def soft_delete_symbol(symbol_url, 0) do
    query = """
      MATCH (symbol:Symbol {url: {symbol_url}})
      OPTIONAL MATCH (symbol)-[r:DELETE]->(sym_del:DeleteSymbolPatch)
      REMOVE symbol:Symbol
      SET symbol:SymbolDeleted
      FOREACH (ignored IN CASE sym_del WHEN NULL THEN [] ELSE [1] END |
        DELETE r, sym_del
      )
    """

    params = %{symbol_url: symbol_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def soft_delete_symbol(symbol_url, 1) do
    query = """
      MATCH (symbol:Symbol {url: {symbol_url}})
      MERGE (symbol)-[:DELETE]->(:DeleteSymbolPatch)
    """

    params = %{symbol_url: symbol_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def soft_delete_symbol_undo(symbol_url, 0) do
    query = """
      MATCH (symbol:SymbolDeleted {url: {symbol_url}})
      REMOVE symbol:SymbolDeleted
      SET symbol:Symbol
    """

    params = %{symbol_url: symbol_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def hard_delete_symbol(symbol_url) do
    query = """
      MATCH (symbol:SymbolDeleted {url: {url}})
      OPTIONAL MATCH (symbol)-[r]-()
      DELETE r, symbol
    """

    params = %{url: symbol_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end
end
