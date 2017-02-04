defmodule PhpInternals.Api.Categories.Category do
  use PhpInternals.Web, :model

  @required_fields ["name", "introduction"]
  @valid_fields ["name", "introduction"]
  @default_order_by "name"

  @view_types ["normal", "overview", "full"]
  @default_view_type "normal"

  def contains_required_fields?(category) do
    if @required_fields -- Map.keys(category) == [] do
      {:ok}
    else
      {:error, 400, "Missing required fields"}
    end
  end

  def contains_only_expected_fields?(category) do
    if Map.keys(category) -- @valid_fields == [] do
      {:ok}
    else
      {:error, 400, "Unknown fields given"}
    end
  end

  def valid_order_by?(order_by) do
    if order_by === nil do
      {:ok, @default_order_by}
    else
      if Enum.member?(@valid_fields, order_by) do
        {:ok, order_by}
      else
        {:error, 400, "Invalid order by field given"}
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
        {:error, 400, "Invalid view type given"}
      end
    end
  end

  def valid_category?(nil = _category_url), do: {:ok, nil}

  def valid_category?(category_url) do
    query = """
      MATCH (category:Category {url: {category_url}})
      RETURN category
    """

    params = %{category_url: category_url}

    category = Neo4j.query!(Neo4j.conn, query, params)

    if category === [] do
      {:error, 404, "Category not found"}
    else
      {:ok, List.first category}
    end
  end

  def valid_categories?([] = _categories) do
    {:error, 400, "At least one category must be given"}
  end

  def valid_categories?(categories) do
    {queries, params, _counter} =
      Enum.reduce(categories, {[], %{}, 0}, fn (cat, {qs, ps, counter}) ->
        {qs ++ ["(c#{counter}:Category {url: {c#{counter}_url}})"], Map.put(ps, "c#{counter}_url", cat), counter + 1}
      end)

    query = "MATCH " <> Enum.join(queries, ",") <> " RETURN c0"

    if Neo4j.query!(Neo4j.conn, query, params) === [] do
      {:error, 400, "An invalid category has been entered"}
    else
      {:ok}
    end
  end

  def contains_no_symbols?(category_url) do
    query = """
      MATCH (symbol:Symbol)-[:CATEGORY]->(category:Category {url: {category_url}})
      RETURN symbol
    """

    params = %{category_url: category_url}

    category = Neo4j.query!(Neo4j.conn, query, params)

    if category == [] do
      {:ok}
    else
      {:error, 400, "A category cannot be deleted whilst linked to symbols"}
    end
  end

  def fetch_all_categories("normal", order_by, ordering, offset, limit) do
    query = """
      MATCH (category:Category)
      RETURN category
      ORDER BY category.#{order_by} #{ordering}
      SKIP #{offset}
      LIMIT #{limit}
    """

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_categories("overview", order_by, ordering, offset, limit) do
    query = """
      MATCH (c:Category)
      RETURN {name: c.name, url: c.url} AS category
      ORDER BY c.#{order_by} #{ordering}
      SKIP #{offset}
      LIMIT #{limit}
    """

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_categories("full", order_by, ordering, offset, limit) do
    query = """
      MATCH (c:Category)
      OPTIONAL MATCH (s:Symbol)-[:CATEGORY]->(c)
      RETURN {
        name: c.name,
        url: c.url,
        introduction: c.introduction,
        revision_id: c.revision_id,
        symbols: collect(CASE s WHEN NULL THEN NULL ELSE {name: s.name, url: s.url, type: s.type} END)
      } AS category
      ORDER BY category.#{order_by} #{ordering}
      SKIP #{offset}
      LIMIT #{limit}
    """

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_categories_patches do
    query = """
      MATCH (category:Category)-[:UPDATE|:DELETE]->(cp)
      RETURN category, collect(cp) as patches
    """

    %{inserts: fetch_all_categories_patches_insert,
      patches: Neo4j.query!(Neo4j.conn, query)}
  end

  def fetch_all_categories_patches_insert do
    query = """
      MATCH (category_insert:InsertCategoryPatch)
      RETURN category_insert
    """
    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_categories_patches_update do
    query = """
      MATCH (category:Category)-[:UPDATE]->(update_category:UpdateCategoryPatch)
      RETURN {category: category, updates: collect(update_category)} as category_update
    """
    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_categories_patches_delete do
    query = """
      MATCH (category_delete:Category)-[:DELETE]-(:DeleteCategoryPatch)
      RETURN category_delete
    """
    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_categories_deleted do
    Neo4j.query!(Neo4j.conn, "MATCH (category:CategoryDeleted) RETURN category")
  end

  def fetch_category_patches(category_url) do
    query = """
      MATCH (category:Category {url: {category_url}})-[:UPDATE|:DELETE]->(cp)
      RETURN category, collect(cp) as patches
    """

    params = %{category_url: category_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category_patch_insert(category_url) do
    query = """
      MATCH (category_insert:InsertCategoryPatch {url: {category_url}})
      RETURN category_insert
    """

    params = %{category_url: category_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category_patch_update(category_url, patch_id) do
    query = """
      MATCH (category:Category {url: {category_url}})-[:UPDATE]->(update_category:UpdateCategoryPatch {revision_id: {patch_id}})
      RETURN {category: category, update: update_category} as category_update
    """

    params = %{category_url: category_url, patch_id: String.to_integer(patch_id)}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category_patches_update(category_url) do
    query = """
      MATCH (category:Category {url: {category_url}})-[:UPDATE]->(update_category:UpdateCategoryPatch)
      RETURN {category: category, updates: collect(update_category)} as category_update
    """

    params = %{category_url: category_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category_patch_delete(category_url) do
    query = """
      MATCH (category_delete:Category {url: {category_url}})
      OPTIONAL MATCH (category_delete)-[:DELETE]->(cd:DeleteCategoryPatch)

      RETURN category_delete, cd
    """

    params = %{category_url: category_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category(category_url) do
    query = """
      MATCH (category:Category {url: {category_url}})
      RETURN category
    """

    params = %{category_url: category_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category_overview(category_url) do
    query = """
      MATCH (c:Category {url: {category_url}})
      RETURN {name: c.name, url: c.name} as category
    """

    params = %{category_url: category_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category_full(category_url) do
    query = """
      MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (s:Symbol)-[:CATEGORY]->(c)
      RETURN {
        name: c.name,
        url: c.url,
        introduction: c.introduction,
        revision_id: c.revision_id,
        symbols: collect(CASE s WHEN NULL THEN NULL ELSE {name: s.name, url: s.url, type: s.type} END)
      } as category
    """

    params = %{category_url: category_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def insert_category(category, 0) do
    query = """
      CREATE (category:Category {name: {name}, introduction: {introduction}, url: {url}, revision_id: {rev_id}})
      RETURN category
    """

    params = %{name: category["name"],
      introduction: category["introduction"],
      url: category["url_name"],
      rev_id: :rand.uniform(100_000_000)}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def insert_category(category, _review) do # review = 1 ?
    query = """
      CREATE (category:InsertCategoryPatch {name: {name}, introduction: {introduction}, url: {url}, revision_id: {rev_id}})
      RETURN category
    """

    params = %{name: category["name"],
      introduction: category["introduction"],
      url: category["url_name"],
      rev_id: :rand.uniform(100_000_000)}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def update_category(new_category, old_category, 0, patch_revision_id) do
    patch_revision_id = String.to_integer(patch_revision_id)

    query = """
      MATCH (category:Category {url: {old_url}})-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
      RETURN category
    """

    params = %{old_url: new_category["old_url"], patch_revision_id: patch_revision_id}

    if Neo4j.query!(Neo4j.conn, query, params) == [] do
      {:error, 404, "Update patch not found"}
    else
      query = """
        MATCH (category:Category {url: {old_url}})-[r1:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
        OPTIONAL MATCH (category)-[r2:REVISION]->(old_revision:CategoryRevision)
        SET category.name = {new_name},
          category.introduction = {new_introduction},
          category.url = {new_url},
          category.revision_id = {new_rev_id}
        CREATE (old_category:CategoryRevision {name: {old_name}, introduction: {old_introduction}, url: {old_url}, revision_id: {old_rev_id}})
        DELETE r1, cp
        WITH category, old_category, r2, old_revision
        FOREACH (ignored IN CASE old_revision WHEN NULL THEN [1] ELSE [] END |
          CREATE (category)-[:REVISION]->(old_category)
        )
        FOREACH (ignored IN CASE old_revision WHEN NULL THEN [] ELSE [1] END |
          DELETE r2
          CREATE (category)-[:REVISION]->(old_category)-[:REVISION]->(old_revision)
        )
        RETURN category
      """

      params = %{new_name: new_category["name"],
        new_introduction: new_category["introduction"],
        new_url: new_category["new_url"],
        new_rev_id: :rand.uniform(100_000_000),
        old_name: old_category["name"],
        old_introduction: old_category["introduction"],
        old_url: new_category["old_url"],
        old_rev_id: old_category["revision_id"],
        patch_revision_id: patch_revision_id}

      {:ok, 200, List.first Neo4j.query!(Neo4j.conn, query, params)}
    end
  end

  def update_category(new_category, old_category, 1, patch_revision_id) do
    patch_revision_id = String.to_integer(patch_revision_id)

    query = """
      MATCH (category:Category {url: {old_url}})-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
      RETURN category
    """

    params = %{old_url: new_category["old_url"], patch_revision_id: patch_revision_id}

    if Neo4j.query!(Neo4j.conn, query, params) == [] do
      {:error, 404, "Update patch not found"}
    else
      query = """
        MATCH (category:Category {url: {old_url}})-[r:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
        CREATE (category)-[:UPDATE]->(:UpdateCategoryPatch {name: {name}, introduction: {introduction}, url: {new_url}, revision_id: {rev_id}, against_revision: {against_rev}})
        DELETE r, cp
        RETURN category
      """

      params = %{name: new_category["name"],
        introduction: new_category["introduction"],
        new_url: new_category["new_url"],
        old_url: new_category["old_url"],
        rev_id: :rand.uniform(100_000_000),
        against_rev: old_category["revision_id"],
        patch_revision_id: patch_revision_id}

      {:ok, 202, List.first Neo4j.query!(Neo4j.conn, query, params)}
    end
  end

  def update_category(_new_category, _old_category, _review, _patch_revision_id) do
    {:error, 400, "Unknown review parameter value"}
  end

  def update_category(new_category, old_category, 0) do
    query = """
      MATCH (category:Category {url: {old_url}})
      OPTIONAL MATCH (category)-[r:REVISION]->(old_revision:CategoryRevision)
      SET category.name = {new_name},
        category.introduction = {new_introduction},
        category.url = {new_url},
        category.revision_id = {new_rev_id}
      CREATE (old_category:CategoryRevision {name: {old_name}, introduction: {old_introduction}, url: {old_url}, revision_id: {old_rev_id}})
      WITH category, old_category, r, old_revision
      FOREACH (ignored IN CASE old_revision WHEN NULL THEN [1] ELSE [] END |
        CREATE (category)-[:REVISION]->(old_category)
      )
      FOREACH (ignored IN CASE old_revision WHEN NULL THEN [] ELSE [1] END |
        DELETE r
        CREATE (category)-[:REVISION]->(old_category)-[:REVISION]->(old_revision)
      )
      RETURN category
    """

    params = %{new_name: new_category["name"],
      new_introduction: new_category["introduction"],
      new_url: new_category["new_url"],
      new_rev_id: :rand.uniform(100_000_000),
      old_name: old_category["name"],
      old_introduction: old_category["introduction"],
      old_url: new_category["old_url"],
      old_rev_id: old_category["revision_id"]}

    {:ok, 200, List.first Neo4j.query!(Neo4j.conn, query, params)}
  end

  def update_category(new_category, old_category, 1) do
    query = """
      MATCH (category:Category {url: {old_url}})
      CREATE (category)-[:UPDATE]->(patch:UpdateCategoryPatch {name: {name}, introduction: {introduction}, url: {new_url}, revision_id: {rev_id}, against_revision: {against_rev}})
      RETURN category
    """

    params = %{name: new_category["name"],
      introduction: new_category["introduction"],
      new_url: new_category["new_url"],
      old_url: new_category["old_url"],
      rev_id: :rand.uniform(100_000_000),
      against_rev: old_category["revision_id"]}

    {:ok, 202, List.first Neo4j.query!(Neo4j.conn, query, params)}
  end

  def update_category(_new_category, _old_category, _review) do
    {:error, 400, "Unknown review parameter value"}
  end

  def accept_category_patch(category_url, "insert") do
    query = "MATCH (category:InsertCategoryPatch {url: {category_url}}) RETURN category"
    params = %{category_url: category_url}

    if Neo4j.query!(Neo4j.conn, query, params) == [] do
      {:error, 404, "Insert patch not found"}
    else
      query = "MATCH (c:Category {url: {category_url}}) RETURN c"

      if Neo4j.query!(Neo4j.conn, query, params) != [] do
        {:error, 400, "A category with the same name already exists"}
      else
        query = """
          MATCH (cp:InsertCategoryPatch {url: {category_url}})
          REMOVE cp:InsertCategoryPatch
          SET cp:Category
          RETURN cp as category
        """

        {:ok, Neo4j.query!(Neo4j.conn, query, params) |> List.first}
      end
    end
  end

  def accept_category_patch(category_url, "delete") do
    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (cp)-[:DELETE]->(:DeleteCategoryPatch)
      RETURN c, cp
    """
    params = %{category_url: category_url}

    category = Neo4j.query!(Neo4j.conn, query, params) |> List.first

    if category["c"] == nil do
      {:error, 404, "Category not found"}
    else
      if category["cp"] == nil do
        {:error, 404, "Delete patch not found for the specified category"}
      else
        query = """
          MATCH (c:Category {url: {category_url}})-[r:DELETE]->(cd:DeleteCategoryPatch)
          REMOVE c:Category
          SET c:CategoryDeleted
          DELETE r, cd
        """

        Neo4j.query!(Neo4j.conn, query, params)

        {:ok, 204}
      end
    end
  end

  def accept_category_patch(category_url, update_or_error) do
    output = String.split(update_or_error, ",")

    if length(output) !== 2 do
      {:error, 400, "Unknown or malformed patch type"}
    else
      [update, for_revision] = output

      if update !== "update" do
        {:error, 400, "Unknown patch type"}
      else
        accept_category_patch(category_url, update, String.to_integer(for_revision))
      end
    end
  end

  def accept_category_patch(category_url, "update", patch_revision_id) do
    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (c)-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
      RETURN c, cp
    """
    params = %{patch_revision_id: patch_revision_id, category_url: category_url}

    category = Neo4j.query!(Neo4j.conn, query, params) |> List.first

    if category["c"] == nil do
      {:error, 404, "Category not found"}
    else
      if category["cp"] == nil do
        {:error, 404, "Update patch not found for the specified category"}
      else
        %{"c" => %{"revision_id" => revision_id}, "cp" => %{"against_revision" => against_rev}} = category

        if against_rev != revision_id do
          {:error, 400, "Cannot apply patch due to revision ID mismatch"}
        else
          query = """
            MATCH (c1:Category {name: {category_url}}),
              (c1)-[r1:UPDATE]->(c2:UpdateCategoryPatch {revision_id: {patch_revision_id}})
            OPTIONAL MATCH (c1)-[r2:REVISION]->(old_revision:CategoryRevision)
            CREATE (old_category:CategoryRevision {name: c1.name, introduction: c1.introduction, url: c1.url, revision_id: c1.revision_id})
            SET c1.name = c2.name, c1.introduction = c2.introduction, c1.url = c2.url, c1.revision_id = c2.revision_id
            WITH c1, c2, old_category, r1, r2, old_revision
            FOREACH (ignored IN CASE old_revision WHEN NULL THEN [1] ELSE [] END |
              CREATE (c1)-[:REVISION]->(old_category)
            )
            FOREACH (ignored IN CASE old_revision WHEN NULL THEN [] ELSE [1] END |
              DELETE r2
              CREATE (c1)-[:REVISION]->(old_category)-[:REVISION]->(old_revision)
            )
            DELETE r1, c2
            RETURN c1 as category
          """

          params = %{category_url: category_url, patch_revision_id: patch_revision_id}

          {:ok, List.first Neo4j.query!(Neo4j.conn, query, params)}
        end
      end
    end
  end

  def discard_category_patch(category_url, "insert") do
    query = "MATCH (category:InsertCategoryPatch {url: {url}}) RETURN category"
    params = %{url: category_url}

    if Neo4j.query!(Neo4j.conn, query, params) === [] do
      {:error, 404, "Insert patch not found"}
    else
      query = """
        MATCH (c:InsertCategoryPatch {url: {url}})
        REMOVE c:InsertCategoryPatch
        SET c:InsertCategoryPatchDeleted
      """

      Neo4j.query!(Neo4j.conn, query, params)

      {:ok, 200}
    end
  end

  def discard_category_patch(category_url, "delete") do
    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (cp)-[:DELETE]->(:DeleteCategoryPatch)
      RETURN c, cp
    """
    params = %{category_url: category_url}

    category = Neo4j.query!(Neo4j.conn, query, params) |> List.first

    if category["c"] == nil do
      {:error, 404, "Category not found"}
    else
      if category["cp"] == nil do
        {:error, 404, "Delete patch not found for the specified category"}
      else
        query = """
          MATCH (:Category {url: {category_url}})-[r:DELETE]->(cp:DeleteCategoryPatch)
          DELETE r, cp
        """
        params = %{category_url: category_url}
        Neo4j.query!(Neo4j.conn, query, params)
        {:ok, 200}
      end
    end
  end

  def discard_category_patch(category_url, update_or_error) do
    output = String.split(update_or_error, ",")

    if length(output) != 2 do
      {:error, 400, "Unknown or malformed patch type"}
    else
      [update, for_revision] = output

      if update != "update" do
        {:error, 400, "Unknown patch type"}
      else
        discard_category_patch(category_url, update, for_revision)
      end
    end
  end

  def discard_category_patch(category_url, "update", patch_revision_id) do
    patch_revision_id = String.to_integer(patch_revision_id)

    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (c)-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
      RETURN c, cp
    """
    params = %{patch_revision_id: patch_revision_id, category_url: category_url}

    category = Neo4j.query!(Neo4j.conn, query, params) |> List.first

    if category["c"] == nil do
      {:error, 404, "Category not found"}
    else
      if category["cp"] == nil do
        {:error, 404, "Update patch not found for the specified category"}
      else
        query = """
          MATCH (:Category {url: {category_url}})-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
          REMOVE cp:UpdateCategoryPatch
          SET cp:UpdateCategoryPatchDeleted
        """
        Neo4j.query!(Neo4j.conn, query, params)
        {:ok, 200}
      end
    end
  end

  def soft_delete_category(category_url, 0) do
    query = """
      MATCH (category:Category {url: {url}})
      OPTIONAL MATCH (category)-[r:DELETE]-(catdel:DeleteCategoryPatch)
      REMOVE category:Category
      SET category:CategoryDeleted
      FOREACH (ignored IN CASE catdel WHEN NULL THEN [] ELSE [1] END |
        DELETE r, catdel
      )
    """

    params = %{url: category_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def soft_delete_category(category_url, _review) do # review = 1 ?
    query = """
      MATCH (category:Category {url: {url}})
      MERGE (category)-[:DELETE]->(catdel:DeleteCategoryPatch)
    """

    params = %{url: category_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def soft_delete_category_undo(category_url, 0) do
    query = """
      MATCH (category:CategoryDeleted {url: {url}})
      REMOVE category:CategoryDeleted
      SET category:Category
    """

    params = %{url: category_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def hard_delete_category(category_url, 0) do
    query = """
      MATCH (category:CategoryDeleted {url: {url}})
      OPTIONAL MATCH (category)-[crel]-()
      DELETE crel, category
    """

    params = %{url: category_url}

    Neo4j.query!(Neo4j.conn, query, params)
  end
end
