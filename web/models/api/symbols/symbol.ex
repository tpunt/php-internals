defmodule PhpInternals.Api.Symbols.Symbol do
  use PhpInternals.Web, :model

  @valid_order_bys ["name", "date"]
  @default_order_by "name"

  @valid_symbol_types ["macro", "function", "variable", "type"]
  @default_symbol_type "all"

  @view_types ["normal", "overview"]
  @default_view_type "normal"

  @required_fields [
    "type",
    "name",
    "declaration",
    "source_location",
    "description",
    "categories"
  ]
  @optional_fields [
    "additional_information"
  ]

  defp special_required_fields("function"), do: ["return_type", "definition"]

  defp special_required_fields(type) when type in ["macro", "type", "variable"], do: []

  defp special_optional_fields("function"), do: ["parameters", "return_description"]

  defp special_optional_fields("macro"), do: ["parameters", "definition"]

  defp special_optional_fields("type"), do: ["members", "definition"]

  defp special_optional_fields("variable"), do: []

  def valid_fields?(symbol) do
    with {:ok} <- valid_type_field?(symbol),
         {:ok} <- contains_required_fields?(symbol),
         {:ok} <- contains_only_expected_fields?(symbol),
         {:ok} <- validate_types(symbol),
         {:ok, symbol} <- validate_values(symbol) do
      {:ok, symbol}
    else
      {:error, cause} ->
        {:error, 400, cause}
    end
  end

  def valid_type_field?(symbol) do
    if Map.has_key?(symbol, "type") do
      if Enum.member?(@valid_symbol_types, symbol["type"]) do
        {:ok}
      else
        {:error, "The type field must be one of the following values: #{Enum.join(@valid_symbol_types, ", ")}"}
      end
    else
      {:error, "The type field must be specified"}
    end
  end

  def validate_types(%{"type" => type} = symbol) do
    validated = Enum.map(Map.keys(symbol), fn key ->
      array_based_fields = ["members", "parameters", "categories"]
      all_fields = @required_fields ++ special_required_fields(type) ++ @optional_fields ++ special_optional_fields(type)

      if key in all_fields -- array_based_fields do
        if is_binary(symbol[key]), do: {:ok}, else: {:error, "The #{key} field should be a string"}
      else
        if is_list(symbol[key]), do: {:ok}, else: {:error, "The #{key} field should be a list"}
      end
    end)

    valid = Enum.filter(validated, fn
      {:ok} -> false
      {:error, _} -> true
    end)

    if valid === [] do
      {:ok}
    else
      List.first valid
    end
  end

  def validate_values(symbol) do
    validated = Enum.map(Map.keys(symbol), fn key ->
      if is_binary(symbol[key]) do
        validate_field(key, String.trim(symbol[key]))
      else
        validate_field(key, symbol[key])
      end
    end)

    invalid = Enum.filter(validated, fn
      {:ok, _map} -> false
      {:error, _} -> true
    end)

    if invalid === [] do
      symbol = Enum.reduce(validated, %{}, fn {:ok, map}, values ->
        Map.merge(map, values)
      end)

      {:ok, symbol}
    else
      List.first invalid
    end
  end

  def validate_field("name", value) do
    if String.length(value) > 0 and String.length(value) < 101 do
      {:ok, %{"name" => value}}
    else
      {:error, "The name field should have a length of between 1 and 100 (inclusive)"}
    end
  end

  def validate_field("declaration", value) do
    if String.length(value) > 0 and String.length(value) < 151 do
      {:ok, %{"declaration" => value}}
    else
      {:error, "The declaration field should have a length of between 1 and 150 (inclusive)"}
    end
  end

  def validate_field("description", value) do
    if String.length(value) > 0 and String.length(value) < 3_001 do
      {:ok, %{"description" => value}}
    else
      {:error, "The description field should have a length of between 1 and 3000 (inclusive)"}
    end
  end

  def validate_field("definition", value) do
    if String.length(value) > 0 and String.length(value) < 6_001 do
      {:ok, %{"definition" => value}}
    else
      {:error, "The definition field should have a length of between 1 and 6000 (inclusive)"}
    end
  end

  def validate_field("source_location", value) do
    if String.length(value) > 0 and String.length(value) < 501 do
      {:ok, %{"source_location" => value}}
    else
      {:error, "The definition location field should have a length of between 1 and 500 (inclusive)"}
    end
  end

  def validate_field("additional_information", value) do
    if String.length(value) < 2_001 do
      {:ok, %{"additional_information" => value}}
    else
      {:error, "The additional information field should have a length of 2000 or less"}
    end
  end

  def validate_field("return_type", value) do
    if String.length(value) > 1 and String.length(value) < 51 do
      {:ok, %{"return_type" => value}}
    else
      {:error, "The return type field should have a length of between 1 and 50 (inclusive)"}
    end
  end

  def validate_field("return_description", value) do
    if String.length(value) < 401 do
      {:ok, %{"return_description" => value}}
    else
      {:error, "The return description field should have a length of 400 or less"}
    end
  end

  def validate_field("type", value) do
    {:ok, %{"type" => value}}
  end

  def validate_field("categories", value) do
    validated = Enum.all?(value, fn category ->
      String.length(category) > 0 and String.length(category) < 51
    end)

    if validated do
      if MapSet.size(MapSet.new(value)) === length(value) do
        {:ok, %{"categories" => value}}
      else
        {:error, "Duplicate category names given"}
      end
    else
      {:error, "Invalid category name(s) given"}
    end
  end

  def validate_field(key, value) when key in ["parameters", "members"] do
    if rem(Enum.count(value), 2) !== 0 do
      {:error, "An even number of values is required"}
    else
      {validated, _c} = Enum.reduce(value, {[], 0}, fn param, {v, c} ->
        param = String.trim(param)
        validate = if rem(c, 2) === 0 do
          if String.length(param) > 0 and String.length(param) < 51 do
            {:ok, param}
          else
            {:error, "The #{key} field name must have a length of between 1 and 50 (inclusive)"}
          end
        else
          if String.length(param) > 0 and String.length(param) < 401 do
            {:ok, param}
          else
            {:error, "The #{key} field description must have a length of between 1 and 400 (inclusive)"}
          end
        end

        {[validate | v], c + 1}
      end)

      invalid = Enum.filter(validated, fn
        {:ok, _value} -> false
        {:error, _} -> true
      end)

      if invalid === [] do
        values = Enum.reduce(validated, [], fn {:ok, value}, values ->
            [value | values]
          end)
        {:ok, %{key => values}}
      else
        List.first invalid
      end
    end
  end

  def contains_required_fields?(symbol) do
    all_required_fields = @required_fields ++ special_required_fields(symbol["type"])

    if all_required_fields -- Map.keys(symbol) === [] do
      {:ok}
    else
      {:error, "Required fields are missing (expecting: #{Enum.join(all_required_fields, ", ")})"}
    end
  end

  def contains_only_expected_fields?(%{"type" => type} = symbol) do
    all_fields = @required_fields ++ special_required_fields(type) ++ @optional_fields ++ special_optional_fields(type)

    if Map.keys(symbol) -- all_fields === [] do
      {:ok}
    else
      {:error, "Unknown fields given (expecting: #{Enum.join(all_fields, ", ")})"}
    end
  end

  def valid_order_by?(order_by) do
    if order_by === nil do
      {:ok, @default_order_by}
    else
      if Enum.member?(@valid_order_bys, order_by) do
        {:ok, order_by}
      else
        {:error, 400, "Invalid order by field given (expecting: #{Enum.join(@valid_order_bys, ", ")})"}
      end
    end
  end

  def valid_type?(symbol_type) do
    if symbol_type === nil do
      {:ok, @default_symbol_type}
    else
      if Enum.member?(@valid_symbol_types, symbol_type) do
        {:ok, symbol_type}
      else
        {:error, 400, "Invalid symbol type field given (expecting: #{Enum.join(@valid_symbol_types, ", ")})"}
      end
    end
  end

  def valid_view_type?(view_type) do
    if view_type === nil do
      {:ok, @default_view_type}
    else
      if Enum.member?(@view_types, view_type) do
        {:ok, view_type}
      else
        {:error, 400, "Invalid view type given (expecting: #{Enum.join(@view_types, ", ")})"}
      end
    end
  end

  def valid?(symbol_id) do
    query = "MATCH (symbol:Symbol {id: {symbol_id}}) RETURN symbol"
    params = %{symbol_id: symbol_id}
    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "The specified symbol could not be found"}
    else
      {:ok, result}
    end
  end

  def is_insert_patch?(symbol_id) do
    query = """
      MATCH (isp:InsertSymbolPatch {id: {symbol_id}})-[:CATEGORY]->(c:Category),
        (isp)-[r:CONTRIBUTOR]->(u:User)
      RETURN CASE isp WHEN NULL THEN NULL ELSE {
        symbol: isp,
        categories: collect({category: {name: c.name, url: c.url}}),
        user: {
          username: u.username,
          name: u.name,
          privilege_level: u.privilege_level,
          avatar_url: u.avatar_url
        },
        date: r.date
      } END AS symbol_insert
    """

    params = %{symbol_id: symbol_id}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "The specified symbol insert patch could not be found"}
    else
      {:ok, result}
    end
  end

  def has_delete_patch?(symbol_id) do
    query = """
      MATCH (s:Symbol {id: {symbol_id}}),
        (:User)-[:DELETE]->(s),
        (s)-[:CATEGORY]->(c:Category)
      RETURN {
        symbol: s,
        categories: COLLECT({category: {name: c.name, url: c.url}})
      } AS symbol_delete
    """

    params = %{symbol_id: symbol_id}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "The specified symbol delete patch could not be found"}
    else
      {:ok, result}
    end
  end

  def has_no_delete_patch?(symbol_id) do
    case has_delete_patch?(symbol_id) do
      {:error, 404, _} ->
        {:ok}
      {:ok, _} ->
        {:error, 400, "The specified symbol already has a delete patch"}
    end
  end

  def update_patch_exists?(symbol_id, patch_id) do
    query = """
      MATCH (s:Symbol {id: {symbol_id}}),
        (usp:UpdateSymbolPatch {revision_id: {patch_id}}),
        (s)-[:UPDATE]->(usp),
        (s)-[:CATEGORY]->(c:Category),
        (usp)-[:CATEGORY]->(uspc:Category),
        (usp)-[r:CONTRIBUTOR]->(u:User)
      WITH s,
        CASE c WHEN NULL THEN [] ELSE COLLECT({category: {name: c.name, url: c.url}}) END AS cs,
        CASE uspc WHEN NULL THEN [] ELSE COLLECT({category: {name: uspc.name, url: uspc.url}}) END AS uspcs,
        usp,
        r,
        u
      RETURN {
        symbol: s,
        categories: cs,
        update: {categories: uspcs, symbol: usp},
        user: {
          username: u.username,
          name: u.name,
          privilege_level: u.privilege_level,
          avatar_url: u.avatar_url
        },
        date: r.date
      } AS symbol_update
    """

    params = %{symbol_id: symbol_id, patch_id: patch_id}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "The specified symbol update patch could not be found"}
    else
      {:ok, result}
    end
  end

  def revision_ids_match?(symbol_id, patch_revision_id) do
    query = """
      MATCH (s1:Symbol {id: {symbol_id}})-[:UPDATE]->(s2:UpdateSymbolPatch {revision_id: {patch_id}})
      WHERE s2.against_revision = s1.revision_id
      RETURN s1
    """

    params = %{symbol_id: symbol_id, patch_id: patch_revision_id}

    result = Neo4j.query!(Neo4j.conn, query, params)

    if result === [] do
      {:error, 400, "Cannot apply patch due to revision ID mismatch"}
    else
      {:ok}
    end
  end

  def fetch_all(order_by, ordering, offset, limit, symbol_type, category_filter, search_term, full_search) do
    {variable_match, order_by, variable_with} =
      if order_by === "date" do
        {", (s)-[scr:CONTRIBUTOR]->(u:User)", "scr.date", ", scr"}
      else
        {"", "s.#{order_by}", ""}
      end
    filter_by_category = if category_filter === nil, do: "", else: ", (c:Category {url: {category_url}})"
    {search_by_symbol_name, search_term} =
      if search_term === nil do
        {"", search_term}
      else
        where_query = "WHERE s."

        {column, search_term} =
          if full_search do
            {"description", "(?i).*#{search_term}.*"}
          else
            if String.first(search_term) === "=" do
              {"name", "(?i)#{String.slice(search_term, 1..-1)}"}
            else
              {"name", "(?i).*#{search_term}.*"}
            end
          end

        {where_query <> column <> " =~ {search_term}", search_term}
      end

    search_by_symbol_type =
      if symbol_type === "all" do
        ""
      else
        if search_term === nil do
          " WHERE s.type = '#{symbol_type}'"
        else
          " AND s.type = '#{symbol_type}'"
        end
      end

    query = """
      MATCH (s:Symbol) #{filter_by_category}, (s)-[:CATEGORY]->(c) #{variable_match}
      #{search_by_symbol_name}
      #{search_by_symbol_type}
      WITH COLLECT({category: {name: c.name, url: c.url}}) AS categories, s #{variable_with}
      ORDER BY #{order_by} #{ordering}
      WITH COLLECT({
        symbol: {
          symbol: {
            id: s.id,
            name: s.name,
            url: s.url,
            type: s.type
          },
          categories: categories
        }
      }) AS symbols
      RETURN {
        symbols: symbols[#{offset}..#{offset + limit}],
        meta: {
          total: LENGTH(symbols),
          offset: #{offset},
          limit: #{limit}
        }
      } AS result
    """

    params = %{category_url: category_filter, search_term: search_term}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_all_patches("all") do
    query = """
      MATCH (s:Symbol)-[:CATEGORY]->(c:Category)
      WITH s,
        COLLECT({category: {name: c.name, url: c.url}}) AS cs
      OPTIONAL MATCH (s)-[:UPDATE]->(usp:UpdateSymbolPatch),
        (usp)-[r:CONTRIBUTOR]->(u:User),
        (usp)-[:CATEGORY]->(uspc:Category)
      OPTIONAL MATCH (s)<-[rd:DELETE]->(:User)
      WITH s,
        cs,
        COLLECT(CASE uspc WHEN NULL THEN [] ELSE {category: {name: uspc.name, url: uspc.url}} END) AS uspcs,
        rd,
        usp,
        r,
        u
      WITH s,
        cs,
        rd,
        COLLECT(CASE usp WHEN NULL THEN NULL ELSE {symbol_update: {
            update: {categories: uspcs, symbol: usp},
            user: {
              username: u.username,
              name: u.name,
              privilege_level: u.privilege_level,
              avatar_url: u.avatar_url
            },
            date: r.date
          }} END) AS usps
      WHERE rd <> FALSE OR usps <> []
      RETURN {
        symbol: s,
        categories: cs,
        updates: usps,
        delete: CASE rd WHEN NULL THEN FALSE ELSE TRUE END
      } AS symbol_patches
    """

    %{patches: Neo4j.query!(Neo4j.conn, query),
      inserts: fetch_all_patches("insert")}
  end

  def fetch_all_patches("insert") do
    query = """
      MATCH (isp:InsertSymbolPatch)-[:CATEGORY]->(c:Category),
        (isp)-[r:CONTRIBUTOR]->(u:User)
      RETURN {
        symbol: isp,
        categories: collect({category: {name: c.name, url: c.url}}),
        user: {
          username: u.username,
          name: u.name,
          privilege_level: u.privilege_level,
          avatar_url: u.avatar_url
        },
        date: r.date
      } as symbol_insert
    """

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_patches("update") do
    query = """
      MATCH (s:Symbol)-[:UPDATE]->(usp:UpdateSymbolPatch),
        (s)-[:CATEGORY]->(c:Category)
      WITH s,
        usp,
        COLLECT({category: {name: c.name, url: c.url}}) AS cs
      MATCH (usp)-[r:CONTRIBUTOR]->(u:User),
        (usp)-[:CATEGORY]->(uspc:Category)
      WITH s,
        usp,
        cs,
        COLLECT({category: {name: uspc.name, url: uspc.url}}) AS uspcs,
        r,
        u
      WITH s,
        cs,
        COLLECT({
            update: {categories: uspcs, symbol: usp},
            user: {
              username: u.username,
              name: u.name,
              privilege_level: u.privilege_level,
              avatar_url: u.avatar_url
            },
            date: r.date
          }) AS usps
      RETURN {
        symbol: s,
        categories: cs,
        updates: usps
      } AS symbol_updates
    """

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_patches("delete") do
    query = """
      MATCH (c:Category)<-[:CATEGORY]-(symbol:Symbol)<-[:DELETE]-(:User)
      RETURN {
        symbol: symbol,
        categories: collect({category: {name: c.name, url: c.url}})
      } AS symbol_delete
    """

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_deleted do
    query = """
      MATCH (c:Category)<-[:CATEGORY]-(s:SymbolDeleted)
      RETURN {
        symbol: s,
        categories: collect({category: {name: c.name, url: c.url}})
      } AS symbol
    """

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch(symbol_id, "normal") do
    query = """
      MATCH (s:Symbol {id: {symbol_id}})-[r:CATEGORY]->(category:Category)
      RETURN {
        symbol: s,
        categories: COLLECT({category: {name: category.name, url: category.url}})
      } AS symbol
    """

    params = %{symbol_id: symbol_id}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_all_patches_for(symbol_id) do
    query = """
      MATCH (s:Symbol {id: {symbol_id}})-[:CATEGORY]->(c:Category)
      OPTIONAL MATCH (s)-[:UPDATE]->(usp:UpdateSymbolPatch),
        (usp)-[r:CONTRIBUTOR]->(u:User),
        (usp)-[:CATEGORY]->(uspc:Category)
      OPTIONAL MATCH (s)<-[rd:DELETE]->(:User)
      WITH s,
        CASE c WHEN NULL THEN [] ELSE COLLECT({category: {name: c.name, url: c.url}}) END AS cs,
        CASE uspc WHEN NULL THEN [] ELSE COLLECT({category: {name: uspc.name, url: uspc.url}}) END AS uspcs,
        rd,
        usp,
        r,
        u
      WITH s,
        cs,
        rd,
        CASE usp WHEN NULL THEN [] ELSE COLLECT({symbol_update: {
            update: {categories: uspcs, symbol: usp},
            user: {
              username: u.username,
              name: u.name,
              privilege_level: u.privilege_level,
              avatar_url: u.avatar_url
            },
            date: r.date
          }}) END AS usps
      RETURN {
        symbol: s,
        categories: cs,
        updates: usps,
        delete: CASE rd WHEN NULL THEN FALSE ELSE TRUE END
      } AS symbol_patches
    """

    params = %{symbol_id: symbol_id}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_update_patches_for(symbol_id) do
    query = """
      MATCH (s:Symbol {id: {symbol_id}})-[:CATEGORY]->(c:Category)
      OPTIONAL MATCH (s)-[:UPDATE]->(usp:UpdateSymbolPatch),
        (usp)-[r:CONTRIBUTOR]->(u:User),
        (usp)-[:CATEGORY]->(uspc:Category)
      WITH s,
        CASE c WHEN NULL THEN [] ELSE COLLECT({category: {name: c.name, url: c.url}}) END AS cs,
        CASE uspc WHEN NULL THEN [] ELSE COLLECT({category: {name: uspc.name, url: uspc.url}}) END AS uspcs,
        usp,
        r,
        u
      WITH s,
        cs,
        CASE usp WHEN NULL THEN [] ELSE COLLECT({
            update: {categories: uspcs, symbol: usp},
            user: {
              username: u.username,
              name: u.name,
              privilege_level: u.privilege_level,
              avatar_url: u.avatar_url
            },
            date: r.date
          }) END AS usps
      RETURN {
        symbol: s,
        categories: cs,
        updates: usps
      } AS symbol_updates
    """

    params = %{symbol_id: symbol_id}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def insert(symbol, review, username) do
    query1 =
      case review do
        0 -> "CREATE (s:Symbol "
        1 -> "CREATE (s:InsertSymbolPatch "
      end

    query2 =
      Map.keys(symbol)
      |> Enum.filter(fn key -> key !== "categories" end)
      |> Enum.map(fn key -> "#{key}: {#{key}}" end)
      |> Enum.join(",")

    query2 = "{id: {id}, revision_id: {revision_id}, #{query2}})"

    {query3, params1, _counter} =
      symbol["categories"]
      |> Enum.reduce({"", %{}, 0}, fn (cat, {queries, params, n}) ->
        query = """
          WITH s
          MATCH (cat#{n}:Category {url: {cat#{n}_url}})
          CREATE (s)-[:CATEGORY]->(cat#{n})
        """
        {queries <> query, Map.put(params, "cat#{n}_url", cat), n + 1}
      end)

    query4 = """
      WITH s
      MATCH (s)-[crel:CATEGORY]->(category:Category),
        (user:User {username: {username}})
      MERGE (s)-[:CONTRIBUTOR {type: "insert", date: timestamp()}]->(user)
      RETURN {
        symbol: s,
        categories: COLLECT({category: {name: category.name, url: category.url}})
      } AS symbol
    """

    query = query1 <> query2 <> query3 <> query4

    params2 = %{
      id: :rand.uniform(100_000_000),
      name: symbol["name"],
      url: symbol["url"],
      type: symbol["type"],
      description: symbol["description"],
      declaration: symbol["declaration"],
      parameters: symbol["parameters"],
      return_type: symbol["return_type"],
      return_description: symbol["return_description"],
      members: symbol["members"],
      definition: symbol["definition"],
      source_location: symbol["source_location"],
      additional_information: symbol["additional_information"],
      revision_id: :rand.uniform(100_000_000),
      username: username
    }

    params = Map.merge(params1, params2)

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def update(old_symbol, new_symbol, 0 = _review, username, nil = _patch_revision_id) do
    query1 = """
      MATCH (old_symbol:Symbol {id: {symbol_id}}),
        (user:User {username: {username}})
      OPTIONAL MATCH (old_symbol)-[r1:UPDATE]->(su:UpdateSymbolPatch)
      OPTIONAL MATCH (old_symbol)<-[r2:DELETE]-(user2:User)
      REMOVE old_symbol:Symbol
      SET old_symbol:SymbolRevision
      DELETE r1, r2
      WITH old_symbol, user, COLLECT(su) as sus, user2
    """

    query2 =
      Map.keys(new_symbol)
      |> Enum.filter(fn key -> key !== "categories" end)
      |> Enum.map(fn key -> "#{key}: {new_#{key}}" end)
      |> Enum.join(",")

    query2 = """
      CREATE (new_symbol:Symbol {
          id: {new_id},
          revision_id: {new_revision_id},
          #{query2}
        }),
        (new_symbol)-[:REVISION]->(old_symbol),
        (new_symbol)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user)
    """

    {queries, params1, _counter} =
      new_symbol["categories"]
      |> Enum.reduce({[], %{}, 0},
        fn cat, {queries, params, n} ->
          {queries ++ ["""
            WITH new_symbol, sus, user2
            MATCH (cat#{n}:Category {url: {cat#{n}_url}})
            CREATE (new_symbol)-[:CATEGORY]->(cat#{n})
          """], Map.put(params, "cat#{n}_url", cat), n + 1}
        end)

    query3 = Enum.join(queries, " ")

    query4 = """
      WITH new_symbol, sus, user2

      FOREACH (su IN sus |
        CREATE (new_symbol)-[:UPDATE]->(su)
      )

      FOREACH (unused IN CASE user2 WHEN NULL THEN [] ELSE [1] END |
        CREATE (new_symbol)<-[:DELETE]-(user2)
      )

      WITH new_symbol
      MATCH (new_symbol)-[:CATEGORY]->(category:Category)
      RETURN {
        symbol: new_symbol,
        categories: COLLECT({category: {name: category.name, url: category.url}})
      } AS symbol
    """

    query = query1 <> query2 <> query3 <> query4

    params2 = %{
      new_id: old_symbol["id"],
      new_name: new_symbol["name"],
      new_url: new_symbol["url"],
      new_type: new_symbol["type"],
      new_description: new_symbol["description"],
      new_declaration: new_symbol["declaration"],
      new_parameters: new_symbol["parameters"],
      new_return_type: new_symbol["return_type"],
      new_return_description: new_symbol["return_description"],
      new_members: new_symbol["members"],
      new_definition: new_symbol["definition"],
      new_source_location: new_symbol["source_location"],
      new_additional_information: new_symbol["additional_information"],
      new_revision_id: :rand.uniform(100_000_000),
      symbol_id: old_symbol["id"],
      username: username
    }

    params = Map.merge(params1, params2)

    {:ok, 200, List.first Neo4j.query!(Neo4j.conn, query, params)}
  end

  def update(old_symbol, new_symbol, 1, username, nil = _patch_revision_id) do
    query1 = """
      MATCH (old_symbol:Symbol {id: {symbol_id}}),
        (user:User {username: {username}})
      WITH old_symbol, user
    """

    query2 =
      Map.keys(old_symbol)
      |> Enum.filter(fn key -> key !== "categories" end)
      |> Enum.map(fn key -> "#{key}: {new_#{key}}" end)
      |> Enum.join(",")

    query2 = """
      CREATE (new_symbol:UpdateSymbolPatch {
          id: {symbol_id},
          against_revision: {against_revision},
          revision_id: {new_revision_id},
          #{query2}
        }),
        (old_symbol)-[:UPDATE]->(new_symbol),
        (new_symbol)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user)
    """

    {queries, params1, _counter} =
      new_symbol["categories"]
      |> Enum.reduce({[], %{}, 0},
        fn cat, {queries, params, n} ->
          {queries ++ ["""
            WITH old_symbol, new_symbol
            MATCH (cat#{n}:Category {url: {cat#{n}_url}})
            CREATE (new_symbol)-[:CATEGORY]->(cat#{n})
          """], Map.put(params, "cat#{n}_url", cat), n + 1}
        end)

    query3 = Enum.join(queries, " ")
    query4 = """
      WITH old_symbol
      MATCH (old_symbol)-[:CATEGORY]->(category:Category)
      RETURN {
        symbol: old_symbol,
        categories: COLLECT({category: {name: category.name, url: category.url}})
      } AS symbol
    """

    query = query1 <> query2 <> query3 <> query4

    params2 = %{
      new_id: old_symbol["id"],
      new_name: new_symbol["name"],
      new_url: new_symbol["url"],
      new_type: new_symbol["type"],
      new_description: new_symbol["description"],
      new_declaration: new_symbol["declaration"],
      new_parameters: new_symbol["parameters"],
      new_return_type: new_symbol["return_type"],
      new_return_description: new_symbol["return_description"],
      new_members: new_symbol["members"],
      new_definition: new_symbol["definition"],
      new_source_location: new_symbol["source_location"],
      new_additional_information: new_symbol["additional_information"],
      new_revision_id: :rand.uniform(100_000_000),
      against_revision: old_symbol["revision_id"],
      symbol_id: old_symbol["id"],
      username: username
    }

    params = Map.merge(params1, params2)

    {:ok, 202, List.first Neo4j.query!(Neo4j.conn, query, params)}
  end

  def update(old_symbol, new_symbol, 0 = _review, username, patch_revision_id) do
    query = """
      MATCH (usp:UpdateSymbolPatch {revision_id: {patch_revision_id}}),
        (symbol:Symbol {url: {old_url}})-[:UPDATE]->(usp)
      RETURN symbol
    """

    params = %{old_url: old_symbol["url"], patch_revision_id: patch_revision_id}

    if Neo4j.query!(Neo4j.conn, query, params) == [] do
      {:error, 404, "Update patch not found"}
    else
      query1 = """
        MATCH (old_symbol:Symbol {id: {symbol_id}}),
          (symbol_patch:UpdateSymbolPatch {revision_id: {patch_revision_id}}),
          (old_symbol)-[r1:UPDATE]->(symbol_patch),
          (user:User {username: {username}})
        REMOVE old_symbol:Symbol
        SET old_symbol:SymbolRevision
        REMOVE symbol_patch:UpdateSymbolPatch
        SET symbol_patch:UpdateSymbolPatchRevision
        DELETE r1
      """

      query2 =
        Map.keys(old_symbol)
        |> Enum.filter(fn key -> key !== "categories" end)
        |> Enum.map(fn key -> "#{key}: {new_#{key}}" end)
        |> Enum.join(",")

      query2 = """
        CREATE (new_symbol:Symbol {#{query2}}),
          (new_symbol)-[:REVISION]->(old_symbol),
          (new_symbol)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user),
          (new_symbol)-[:UPDATE_REVISION]->(symbol_patch)
      """

      {queries, params1, _counter} =
        new_symbol["categories"]
        |> Enum.reduce({[], %{}, 0},
          fn cat, {queries, params, n} ->
            {queries ++ ["""
              WITH old_symbol, new_symbol
              MATCH (cat#{n}:Category {url: {cat#{n}_url}})
              CREATE (new_symbol)-[:CATEGORY]->(cat#{n})
            """], Map.put(params, "cat#{n}_url", cat), n + 1}
          end)

      query3 = Enum.join(queries, " ")

      query4 = """
        WITH old_symbol, new_symbol

        OPTIONAL MATCH (old_symbol)-[r1:UPDATE]->(su:UpdateSymbolPatch)
        OPTIONAL MATCH (old_symbol)<-[r2:DELETE]-(user2:User)

        DELETE r1, r2

        WITH old_symbol, new_symbol, COLLECT(su) as sus, user2

        FOREACH (su IN sus |
          CREATE (new_symbol)-[:UPDATE]->(su)
        )

        FOREACH (unused IN CASE user2 WHEN NULL THEN [] ELSE [1] END |
          CREATE (new_symbol)<-[:DELETE]-(user2)
        )

        WITH new_symbol

        MATCH (new_symbol)-[:CATEGORY]->(category:Category)
        RETURN {
          symbol: new_symbol,
          categories: COLLECT({category: {name: category.name, url: category.url}})
        } AS symbol
      """

      query = query1 <> query2 <> query3 <> query4

      params2 = %{
        new_id: old_symbol["id"],
        new_name: new_symbol["name"],
        new_url: new_symbol["url"],
        new_type: new_symbol["type"],
        new_description: new_symbol["description"],
        new_declaration: new_symbol["declaration"],
        new_parameters: new_symbol["parameters"],
        new_return_type: new_symbol["return_type"],
        new_return_description: new_symbol["return_description"],
        new_members: new_symbol["members"],
        new_definition: new_symbol["definition"],
        new_source_location: new_symbol["source_location"],
        new_additional_information: new_symbol["additional_information"],
        new_revision_id: :rand.uniform(100_000_000),
        symbol_id: old_symbol["id"],
        username: username,
        patch_revision_id: patch_revision_id
      }

      params = Map.merge(params1, params2)

      {:ok, 200, List.first Neo4j.query!(Neo4j.conn, query, params)}
    end
  end

  def update(old_symbol, new_symbol, 1, username, patch_revision_id) do
    query1 = """
      MATCH (old_symbol:Symbol {id: {symbol_id}}),
        (symbol_patch:UpdateSymbolPatch {revision_id: {patch_revision_id}}),
        (old_symbol)-[r1:UPDATE]->(symbol_patch),
        (user:User {username: {username}})

      REMOVE symbol_patch:UpdateSymbolPatch
      SET symbol_patch:UpdateSymbolPatchRevision
      DELETE r1

      WITH old_symbol, user, symbol_patch
    """

    query2 =
      Map.keys(old_symbol)
      |> Enum.filter(fn key -> key !== "categories" end)
      |> Enum.map(fn key -> "#{key}: {new_#{key}}" end)
      |> Enum.join(",")

    query2 = """
      CREATE (new_symbol:UpdateSymbolPatch {id: {symbol_id}, against_revision: {against_revision}, #{query2}}),
        (old_symbol)-[:UPDATE]->(new_symbol),
        (new_symbol)-[:UPDATE_REVISION]->(symbol_patch),
        (new_symbol)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user)
    """

    {queries, params1, _counter} =
      new_symbol["categories"]
      |> Enum.reduce({[], %{}, 0},
        fn cat, {queries, params, n} ->
          {queries ++ ["""
            WITH old_symbol, new_symbol
            MATCH (cat#{n}:Category {url: {cat#{n}_url}})
            CREATE (new_symbol)-[:CATEGORY]->(cat#{n})
          """], Map.put(params, "cat#{n}_url", cat), n + 1}
        end)

    query3 = Enum.join(queries, " ")
    query4 = """
      WITH old_symbol
      MATCH (old_symbol)-[:CATEGORY]->(category:Category)
      RETURN {
        symbol: old_symbol,
        categories: COLLECT({category: {name: category.name, url: category.url}})
      } AS symbol
    """

    query = query1 <> query2 <> query3 <> query4

    params2 = %{
      new_id: old_symbol["id"],
      new_name: new_symbol["name"],
      new_url: new_symbol["url"],
      new_type: new_symbol["type"],
      new_description: new_symbol["description"],
      new_declaration: new_symbol["declaration"],
      new_parameters: new_symbol["parameters"],
      new_return_type: new_symbol["return_type"],
      new_return_description: new_symbol["return_description"],
      new_members: new_symbol["members"],
      new_definition: new_symbol["definition"],
      new_source_location: new_symbol["source_location"],
      new_additional_information: new_symbol["additional_information"],
      new_revision_id: :rand.uniform(100_000_000),
      against_revision: old_symbol["revision_id"],
      symbol_id: old_symbol["id"],
      username: username,
      patch_revision_id: patch_revision_id
    }

    params = Map.merge(params1, params2)

    {:ok, 202, List.first Neo4j.query!(Neo4j.conn, query, params)}
  end

  def apply_patch?(symbol_id, %{"action" => "insert"}, username) do
    query = """
      MATCH (s:InsertSymbolPatch {id: {symbol_id}})-[:CATEGORY]->(category:Category),
        (user:User {username: {username}})
      REMOVE s:InsertSymbolPatch
      SET s:Symbol
      MERGE (s)-[:CONTRIBUTOR {type: "apply_insert", date: timestamp()}]->(user)
      RETURN {
        symbol: s,
        categories: COLLECT({category: {name: category.name, url: category.url}})
      } AS symbol
    """

    params = %{symbol_id: symbol_id, username: username}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:error, 404, "Insert patch not found"}
    else
      {:ok, result}
    end
  end

  def apply_patch?(symbol_id, %{"action" => "update", "patch_revision_id" => patch_revision_id}, username) do
    with {:ok, _symbol} <- update_patch_exists?(symbol_id, patch_revision_id),
         {:ok} <- revision_ids_match?(symbol_id, patch_revision_id) do
      query = """
        MATCH (old_symbol:Symbol {id: {symbol_id}}),
          (old_symbol)-[r1:UPDATE]->(new_symbol:UpdateSymbolPatch {revision_id: {patch_id}})
        DELETE r1

        WITH old_symbol, new_symbol

        OPTIONAL MATCH (old_symbol)-[r2:UPDATE]->(su:UpdateSymbolPatch)
        OPTIONAL MATCH (old_symbol)<-[r3:DELETE]-(user2:User)
        REMOVE old_symbol:Symbol
        REMOVE new_symbol:UpdateSymbolPatch
        REMOVE new_symbol.against_revision
        SET old_symbol:SymbolRevision
        SET new_symbol:Symbol
        DELETE r2, r3

        WITH old_symbol, new_symbol, collect(su) as sus, user2

        CREATE (new_symbol)-[:REVISION]->(old_symbol)
        FOREACH (su IN sus |
          CREATE (new_symbol)-[:UPDATE]->(su)
        )
        FOREACH (unused IN CASE user2 WHEN NULL THEN [] ELSE [1] END |
          CREATE (new_symbol)<-[:DELETE]-(user2)
        )

        WITH new_symbol

        MATCH (new_symbol)-[:CATEGORY]->(category:Category),
          (user:User {username: {username}})
        MERGE (new_symbol)-[:CONTRIBUTOR {type: "apply_update", date: timestamp()}]->(user)
        RETURN {
          symbol: new_symbol,
          categories: COLLECT({category: {name: category.name, url: category.url}})
        } AS symbol
      """

      params = %{
        symbol_id: symbol_id,
        patch_id: patch_revision_id,
        username: username
      }

      {:ok, List.first Neo4j.query!(Neo4j.conn, query, params)}
    else
      error ->
        error
    end
  end

  def apply_patch?(symbol_id, %{"action" => "delete"}, username) do
    query = """
      MATCH (s:Symbol {id: {symbol_id}}),
        (u:User)-[r:DELETE]->(s),
        (u2:User {username: {username}})

      REMOVE s:Symbol
      SET s:SymbolDeleted

      DELETE r
      CREATE (s)-[:CONTRIBUTOR {type: "delete", date: timestamp()}]->(u),
        (s)-[:CONTRIBUTOR {type: "apply_delete", date: timestamp()}]->(u2)

      RETURN s
    """

    params = %{symbol_id: symbol_id, username: username}

    result = Neo4j.query!(Neo4j.conn, query, params)

    if result === [] do
      {:error, 404, "Delete patch not found"}
    else
      {:ok, 204}
    end
  end

  def discard_patch?(symbol_id, %{"action" => "insert"}, username) do
    with {:ok, _symbol} <- is_insert_patch?(symbol_id) do
      query = """
        MATCH (isp:InsertSymbolPatch {id: {symbol_id}}),
          (user:User {username: {username}})
        REMOVE isp:InsertSymbolPatch
        SET isp:InsertSymbolPatchDeleted
        MERGE (isp)-[:CONTRIBUTOR {type: "discard_insert", date: timestamp()}]->(user)
      """

      params = %{symbol_id: symbol_id, username: username}

      Neo4j.query!(Neo4j.conn, query, params)

      {:ok, 200}
    else
      error ->
        error
    end
  end

  def discard_patch?(symbol_id, %{"action" => "update", "patch_revision_id" => patch_revision_id}, username) do
    with {:ok, _symbol} <- update_patch_exists?(symbol_id, patch_revision_id) do
      query = """
        MATCH (usp:UpdateSymbolPatch {revision_id: {revision_id}}),
          (user:User {username: {username}})
        REMOVE usp:UpdateSymbolPatch
        SET usp:UpdateSymbolPatchDeleted
        MERGE (usp)-[:CONTRIBUTOR {type: "discard_update", date: timestamp()}]->(user)
      """

      params = %{revision_id: patch_revision_id, username: username}

      Neo4j.query!(Neo4j.conn, query, params)

      {:ok, 200}
    else
      error ->
        error
    end
  end

  def discard_patch?(symbol_id, %{"action" => "delete"}, username) do
    with {:ok, _symbol} <- has_delete_patch?(symbol_id) do
      query = """
        MATCH (s:Symbol {id: {symbol_id}}),
          (:User)-[r:DELETE]->(s),
          (u2:User {username: {username}})
        DELETE r
        MERGE (s)-[r2:CONTRIBUTOR {type: "discard_delete"}]->(u2)
        SET r2.date = timestamp()
      """

      params = %{symbol_id: symbol_id, username: username}

      Neo4j.query!(Neo4j.conn, query, params)

      {:ok, 200}
    else
      error ->
        error
    end
  end

  def soft_delete(symbol_id, 0 = _review, username) do
    query = """
      MATCH (s:Symbol {id: {symbol_id}}),
        (u:User {username: {username}})
      REMOVE s:Symbol
      SET s:SymbolDeleted
      CREATE (s)-[:CONTRIBUTOR {type: "delete", date: timestamp()}]->(u)
    """

    params = %{symbol_id: symbol_id, username: username}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def soft_delete(symbol_id, 1 = _review, username) do
    query = """
      MATCH (s:Symbol {id: {symbol_id}}),
        (u:User {username: {username}})
      CREATE (u)-[:DELETE]->(s)
    """

    params = %{symbol_id: symbol_id, username: username}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def soft_delete_undo(symbol_id, 0 = _review, username) do
    query = """
      MATCH (sd:SymbolDeleted {id: {symbol_id}}),
        (u:User {username: {username}}),
        (sd)-[r1:CONTRIBUTOR {type: "delete"}]->(u)
      OPTIONAL MATCH (sd)-[r2:CONTRIBUTOR {type: "apply_delete"}]->(u)

      REMOVE sd:SymbolDeleted
      SET sd:Symbol
      DELETE r1, r2

      CREATE (s)-[:CONTRIBUTOR {type: "undo_delete", date: timestamp()}]->(u)
    """

    params = %{symbol_id: symbol_id, username: username}

    Neo4j.query!(Neo4j.conn, query, params)
  end
end
