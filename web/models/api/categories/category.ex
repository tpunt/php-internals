defmodule PhpInternals.Api.Categories.Category do
  use PhpInternals.Web, :model

  @required_fields ["name", "introduction"]
  @optional_fields []

  @valid_ordering_fields ["name"]
  @default_order_by "name"

  @view_types ["normal", "overview"]
  @default_view_type "normal"

  def contains_required_fields?(category) do
    if @required_fields -- Map.keys(category) == [] do
      {:ok}
    else
      {:error, 400, "Required fields are missing (expecting: #{Enum.join(@required_fields, ", ")})"}
    end
  end

  def contains_only_expected_fields?(category) do
    all_fields = @required_fields ++ @optional_fields
    if Map.keys(category) -- all_fields == [] do
      {:ok}
    else
      {:error, 400, "Unknown fields given (expecting: #{Enum.join(all_fields, ", ")})"}
    end
  end

  def valid_order_by?(order_by) do
    if order_by === nil do
      {:ok, @default_order_by}
    else
      if Enum.member?(@valid_ordering_fields, order_by) do
        {:ok, order_by}
      else
        {:error, 400, "Invalid order by field given (expecting: #{Enum.join(@valid_ordering_fields, ", ")})"}
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

  def does_not_exist?(category_url) do
    case valid_category?(category_url) do
      {:ok, _category} ->
        {:error, 400, "The category with the specified name already exists"}
      {:error, 404, _status} ->
        {:ok}
    end
  end

  def valid_category?(nil = _category_url), do: {:ok, nil}

  def valid_category?(category_url) do
    query = """
      MATCH (category:Category {url: {category_url}})
      RETURN category
    """

    params = %{category_url: category_url}

    category = List.first Neo4j.query!(Neo4j.conn, query, params)

    if category === nil do
      {:error, 404, "Category not found"}
    else
      {:ok, category}
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
      MATCH (category_delete:Category)-[:DELETE]->(:DeleteCategoryPatch)
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

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category_patch_insert(category_url) do
    query = """
      MATCH (category_insert:InsertCategoryPatch {url: {category_url}})
      RETURN category_insert
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category_patch_update(category_url, patch_id) do
    query = """
      MATCH (category:Category {url: {category_url}})-[:UPDATE]->(update_category:UpdateCategoryPatch {revision_id: {patch_id}})
      RETURN {category: category, update: update_category} as category_update
    """

    params = %{category_url: category_url, patch_id: String.to_integer(patch_id)}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category_patches_update(category_url) do
    query = """
      MATCH (category:Category {url: {category_url}})-[:UPDATE]->(update_category:UpdateCategoryPatch)
      RETURN {category: category, updates: collect(update_category)} as category_update
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category_patch_delete(category_url) do
    query = """
      MATCH (category_delete:Category {url: {category_url}})
      OPTIONAL MATCH (category_delete)-[:DELETE]->(cd:DeleteCategoryPatch)

      RETURN category_delete, cd
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_category(category_url) do
    query = """
      MATCH (category:Category {url: {category_url}})
      RETURN category
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
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
      OPTIONAL MATCH (a:Article)-[:CATEGORY]->(c), (a)-[:AUTHOR]->(u:User)
      WITH c, a, u, collect(
        CASE s WHEN NULL THEN NULL ELSE {name: s.name, url: s.url, type: s.type}
      END) AS symbols
      OPTIONAL MATCH (a)-[:CATEGORY]->(ac)
      WITH c, a, u, symbols, collect(ac) AS acs
      RETURN {
        name: c.name,
        url: c.url,
        introduction: c.introduction,
        revision_id: c.revision_id,
        symbols: symbols,
        articles: collect(CASE a WHEN NULL THEN NULL ELSE {
          article: {
            user: {username: u.username, name: u.name, privilege_level: u.privilege_level},
            categories: acs,
            title: a.title, url: a.url, date: a.date, excerpt: a.excerpt
          }
        } END)
      } as category
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def insert_category(category, 0, username) do
    query = """
      MATCH (user:User {username: {username}})
      CREATE (category:Category {name: {name}, introduction: {introduction}, url: {url}, revision_id: {rev_id}}),
        (category)-[:CONTRIBUTOR {type: "insert"}]->(user)
      RETURN category
    """

    params = %{name: category["name"],
      introduction: category["introduction"],
      url: category["url_name"],
      rev_id: :rand.uniform(100_000_000),
      username: username}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def insert_category(category, _review = 1, username) do
    query = """
      MATCH (user:User {username: {username}})
      CREATE (category:InsertCategoryPatch {name: {name}, introduction: {introduction}, url: {url}, revision_id: {rev_id}}),
        (category)-[:CONTRIBUTOR {type: "insert"}]->(user)
      RETURN category
    """

    params = %{name: category["name"],
      introduction: category["introduction"],
      url: category["url_name"],
      rev_id: :rand.uniform(100_000_000),
      username: username}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def update_category(old_category, new_category, 0 = _review, username, patch_revision_id) do
    patch_revision_id = String.to_integer(patch_revision_id)

    query = """
      MATCH (category:Category {url: {old_url}}),
        (category)-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
      RETURN category
    """

    params = %{
      old_url: old_category["url"],
      patch_revision_id: patch_revision_id,
      new_name: new_category["name"],
      new_url: new_category["url"],
      new_introduction: new_category["introduction"],
      new_rev_id: :rand.uniform(100_000_000),
      username: username
    }

    if Neo4j.query!(Neo4j.conn, query, params) === [] do
      {:error, 404, "Update patch not found"}
    else
      query = """
        MATCH (old_category:Category {url: {old_url}}),
          (user:User {username: {username}}),
          (old_category)-[r1:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})

        CREATE (new_category:Category {
            name: {new_name}, introduction: {new_introduction}, url: {new_url}, revision_id: {new_rev_id}
          }),
          (new_category)-[:REVISION]->(old_category),
          (new_category)-[:UPDATE_REVISION]->(cp),
          (new_category)-[:CONTRIBUTOR {type: "update"}]->(user)

        REMOVE old_category:Category
        SET old_category:CategoryRevision

        REMOVE cp:UpdateCategoryPatch
        SET cp:UpdateCategoryPatchRevision

        DELETE r1

        WITH old_category, new_category, user

        OPTIONAL MATCH (n)-[r2:CATEGORY]->(old_category)
        OPTIONAL MATCH (old_category)-[r3:UPDATE]->(ucp:UpdateCategoryPatch)
        OPTIONAL MATCH (old_category)-[r4:DELETE]->(dcp:DeleteCategoryPatch)

        DELETE r2, r3, r4

        WITH new_category, COLLECT(n) AS ns, COLLECT(ucp) AS ucps, dcp

        FOREACH (n IN ns |
          CREATE (n)-[:CATEGORY]->(new_category)
        )

        FOREACH (ucp IN ucps |
          CREATE (new_category)-[:UPDATE]->(ucp)
        )

        FOREACH (ignored IN CASE dcp WHEN NULL THEN [] ELSE [1] END |
          CREATE (new_category)-[:DELETE]->(cdp)
        )

        return new_category as category
      """

      {:ok, 200, List.first Neo4j.query!(Neo4j.conn, query, params)}
    end
  end

  def update_category(old_category, new_category, 1 = _review, username, patch_revision_id) do
    patch_revision_id = String.to_integer(patch_revision_id)

    query = """
      MATCH (ucp:UpdateCategoryPatch {revision_id: {patch_revision_id}}),
        (category:Category {url: {old_url}})-[:UPDATE]->(ucp)
      RETURN category
    """

    params = %{old_url: old_category["url"], patch_revision_id: patch_revision_id}

    if Neo4j.query!(Neo4j.conn, query, params) == [] do
      {:error, 404, "Update patch not found"}
    else
      query = """
        MATCH (category:Category {url: {old_url}}),
          (category)-[r:UPDATE]->(old_ucp:UpdateCategoryPatch {revision_id: {patch_revision_id}}),
          (user:User {username: {username}})

        CREATE (new_ucp:UpdateCategoryPatch {
            name: {name},
            introduction: {introduction},
            url: {new_url},
            revision_id: {rev_id},
            against_revision: {against_rev}
          }),
          (category)-[:UPDATE]->(new_ucp),
          (new_ucp)-[:CONTRIBUTOR {type: "update"}]->(user),
          (new_ucp)-[:UPDATE_REVISION]->(old_ucp)

        DELETE r

        REMOVE old_ucp:UpdateCategoryPatch
        SET old_ucp:UpdateCategoryPatchRevision

        RETURN category
      """

      params = %{
        name: new_category["name"],
        introduction: new_category["introduction"],
        new_url: new_category["url"],
        rev_id: :rand.uniform(100_000_000),
        old_url: old_category["url"],
        against_rev: old_category["revision_id"],
        patch_revision_id: patch_revision_id,
        username: username
      }

      {:ok, 202, List.first Neo4j.query!(Neo4j.conn, query, params)}
    end
  end

  def update_category(_old_category, _new_category, _review, _patch_revision_id, _username) do
    {:error, 400, "Unknown review parameter value"}
  end

  def update_category(old_category, new_category, 0, username) do
    query = """
      MATCH (old_category:Category {url: {old_url}}),
        (user:User {username: {username}})
      OPTIONAL MATCH (old_category)-[r1:UPDATE]->(ucp:UpdateCategoryPatch)
      OPTIONAL MATCH (old_category)-[r2:DELETE]->(dcp:DeleteCategoryPatch)
      OPTIONAL MATCH (n)-[r3:CATEGORY]->(old_category)

      CREATE (new_category:Category {
          name: {new_name},
          introduction: {new_introduction},
          url: {new_url},
          revision_id: {new_rev_id}
        }),
        (new_category)-[:REVISION]->(old_category),
        (new_category)-[:CONTRIBUTOR {type: "update"}]->(user)

      REMOVE old_category:Category
      SET old_category:CategoryRevision

      DELETE r1, r2, r3

      WITH old_category, new_category, COLLECT(ucp) AS ucps, dcp, COLLECT(n) AS ns

      FOREACH (ucp IN ucps |
        CREATE (new_category)-[:UPDATE]->(ucp)
      )

      FOREACH (ignored IN CASE dcp WHEN NULL THEN [] ELSE [1] END |
        CREATE (new_category)-[:DELETE]->(dcp)
      )

      FOREACH (n IN ns |
        CREATE (n)-[:CATEGORY]->(new_category)
      )

      RETURN new_category as category
    """

    params = %{
      new_name: new_category["name"],
      new_introduction: new_category["introduction"],
      new_url: new_category["url"],
      new_rev_id: :rand.uniform(100_000_000),
      old_url: old_category["url"],
      username: username
    }

    {:ok, 200, List.first Neo4j.query!(Neo4j.conn, query, params)}
  end

  def update_category(old_category, new_category, 1, username) do
    query = """
      MATCH (category:Category {url: {old_url}}),
        (user:User {username: {username}})
      CREATE (ucp:UpdateCategoryPatch {
          name: {name},
          introduction: {introduction},
          url: {new_url},
          revision_id: {rev_id},
          against_revision: {against_rev}
        }),
        (category)-[:UPDATE]->(ucp),
        (ucp)-[:CONTRIBUTOR {type: "update"}]->(user)
      RETURN category
    """

    params = %{
      name: new_category["name"],
      introduction: new_category["introduction"],
      new_url: new_category["url"],
      rev_id: :rand.uniform(100_000_000),
      old_url: old_category["url"],
      against_rev: old_category["revision_id"],
      username: username
    }

    {:ok, 202, List.first Neo4j.query!(Neo4j.conn, query, params)}
  end

  def update_category(_new_category, _old_category, review) do
    {:error, 400, "Unknown review parameter value"}
  end

  def accept_category_patch(category_url, "insert", username) do
    query = "MATCH (category:InsertCategoryPatch {url: {category_url}}) RETURN category"
    params = %{category_url: category_url, username: username}

    if Neo4j.query!(Neo4j.conn, query, params) == [] do
      {:error, 404, "Insert patch not found"}
    else
      query = "MATCH (c:Category {url: {category_url}}) RETURN c"

      if Neo4j.query!(Neo4j.conn, query, params) != [] do
        {:error, 400, "A category with the same name already exists"}
      else
        query = """
          MATCH (cp:InsertCategoryPatch {url: {category_url}}),
            (user:User {username: {username}})
          REMOVE cp:InsertCategoryPatch
          SET cp:Category
          CREATE (cp)-[:CONTRIBUTOR {type: "apply_insert"}]->(user)
          WITH cp
          RETURN cp as category
        """

        {:ok, Neo4j.query!(Neo4j.conn, query, params) |> List.first}
      end
    end
  end

  def accept_category_patch(category_url, "delete", username) do
    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (cp)-[:DELETE]->(:DeleteCategoryPatch)
      RETURN c, cp
    """
    params = %{category_url: category_url, username: username}

    category = Neo4j.query!(Neo4j.conn, query, params) |> List.first

    if category["c"] == nil do
      {:error, 404, "Category not found"}
    else
      if category["cp"] == nil do
        {:error, 404, "Delete patch not found for the specified category"}
      else
        query = """
          MATCH (c:Category {url: {category_url}})-[r:DELETE]->(cd:DeleteCategoryPatch),
            (user:User {username: {username}})
          REMOVE c:Category
          SET c:CategoryDeleted
          CREATE (c)-[:CONTRIBUTOR {type: "apply_delete"}]->(user)
          DELETE r, cd
        """

        Neo4j.query!(Neo4j.conn, query, params)

        {:ok, 204}
      end
    end
  end

  def accept_category_patch(category_url, update, username) do
    [update, for_revision] = String.split(update, ",")
    accept_category_patch(category_url, update, String.to_integer(for_revision), username)
  end

  def accept_category_patch(category_url, "update", patch_revision_id, username) do
    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (c)-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
      RETURN c, cp
    """
    params = %{patch_revision_id: patch_revision_id, category_url: category_url, username: username}

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
            MATCH (old_category:Category {url: {category_url}}),
              (old_category)-[r1:UPDATE]->(new_category:UpdateCategoryPatch {revision_id: {patch_revision_id}}),
              (user:User {username: {username}})

            CREATE (new_category)-[:REVISION]->(old_category),
              (new_category)-[:CONTRIBUTOR {type: "apply_update"}]->(user)

            REMOVE new_category:UpdateCategoryPatch
            SET new_category:Category

            REMOVE old_category:Category
            SET old_category:CategoryRevision

            DELETE r1

            WITH old_category, new_category

            OPTIONAL MATCH (old_category)-[r2:UPDATE]->(ucp:UpdateCategoryPatch)
            OPTIONAL MATCH (old_category)-[r3:DELETE]->(dcp:DeleteCategoryPatch)

            DELETE r2, r3

            WITH new_category, dcp, COLLECT(ucp) AS ucps

            FOREACH (ucp IN ucps |
              CREATE (new_category)-[:UPDATE]->(ucp)
            )

            FOREACH (ignored IN CASE dcp WHEN NULL THEN [] ELSE [1] END |
              CREATE (new_category)-[:DELETE]->(dcp)
            )

            RETURN new_category as category
          """

          {:ok, List.first Neo4j.query!(Neo4j.conn, query, params)}
        end
      end
    end
  end

  def discard_category_patch(category_url, "insert", username) do
    query = """
      MATCH (category:InsertCategoryPatch {url: {url}})
      RETURN category
    """

    params = %{url: category_url, username: username}

    if Neo4j.query!(Neo4j.conn, query, params) === [] do
      {:error, 404, "Insert patch not found"}
    else
      query = """
        MATCH (cp:InsertCategoryPatch {url: {url}}),
          (user:User {username: {username}})
        REMOVE cp:InsertCategoryPatch
        SET cp:InsertCategoryPatchDeleted
        CREATE (cp)-[:CONTRIBUTOR {type: "discard_insert"}]->(user)
      """

      Neo4j.query!(Neo4j.conn, query, params)

      {:ok, 200}
    end
  end

  def discard_category_patch(category_url, "delete", username) do
    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (cp)-[:DELETE]->(:DeleteCategoryPatch)
      RETURN c, cp
    """
    params = %{category_url: category_url, username: username}

    category = Neo4j.query!(Neo4j.conn, query, params) |> List.first

    if category["c"] == nil do
      {:error, 404, "Category not found"}
    else
      if category["cp"] == nil do
        {:error, 404, "Delete patch not found for the specified category"}
      else
        query = """
          MATCH (c:Category {url: {category_url}}),
            (user:User {username: {username}}),
            (c)-[r:DELETE]->(cp:DeleteCategoryPatch)
          DELETE r, cp
          MERGE (c)-[:CONTRIBUTOR {type: "discard_delete"}]->(user)
        """

        Neo4j.query!(Neo4j.conn, query, params)

        {:ok, 200}
      end
    end
  end

  def discard_category_patch(category_url, update, username) do
    [update, for_revision] = String.split(update, ",")
    discard_category_patch(category_url, update, String.to_integer(for_revision), username)
  end

  def discard_category_patch(category_url, "update", patch_revision_id, username) do
    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (c)-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
      RETURN c, cp
    """
    params = %{patch_revision_id: patch_revision_id, category_url: category_url, username: username}

    category = Neo4j.query!(Neo4j.conn, query, params) |> List.first

    if category["c"] == nil do
      {:error, 404, "Category not found"}
    else
      if category["cp"] == nil do
        {:error, 404, "Update patch not found for the specified category"}
      else
        query = """
          MATCH (c:Category {url: {category_url}}),
            (user:User {username: {username}}),
            (c)-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
          REMOVE cp:UpdateCategoryPatch
          SET cp:UpdateCategoryPatchDeleted
          CREATE (cp)-[:CONTRIBUTOR {type: "discard_update"}]->(user)
        """
        Neo4j.query!(Neo4j.conn, query, params)

        {:ok, 200}
      end
    end
  end

  def soft_delete_category(category_url, 0, username) do
    query = """
      MATCH (c:Category {url: {url}}),
        (user:User {username: {username}})
      OPTIONAL MATCH (c)-[r:DELETE]->(catdel:DeleteCategoryPatch)
      REMOVE c:Category
      SET c:CategoryDeleted
      FOREACH (ignored IN CASE catdel WHEN NULL THEN [] ELSE [1] END |
        DELETE r, catdel
      )
      CREATE (c)-[:CONTRIBUTOR {type: "delete"}]->(user)
    """

    params = %{url: category_url, username: username}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def soft_delete_category(category_url, _review = 1, username) do
    query = """
      MATCH (category:Category {url: {url}}),
        (user:User {username: {username}})
      MERGE (category)-[:DELETE]->(catdel:DeleteCategoryPatch)
      CREATE (c)-[:CONTRIBUTOR {type: "delete"}]->(user)
    """

    params = %{url: category_url, username: username}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def soft_delete_category_undo(category_url, 0, username) do
    query = """
      MATCH (c:CategoryDeleted {url: {url}}),
        (user:User {username: {username}})
      REMOVE c:CategoryDeleted
      SET c:Category
      CREATE (c)-[:CONTRIBUTOR {type: "undo_delete"}]->(user)
    """

    params = %{url: category_url, username: username}

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
