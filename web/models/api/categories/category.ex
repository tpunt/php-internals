defmodule PhpInternals.Api.Categories.Category do
  use PhpInternals.Web, :model

  @required_fields ["name", "introduction"]
  @optional_fields ["subcategories", "supercategories"]

  @valid_ordering_fields ["name"]
  @default_order_by "name"

  @show_view_types ["normal", "overview", "full"]
  @default_show_view_type "normal"

  def valid_fields?(category) do
    with {:ok} <- contains_required_fields?(category),
         {:ok} <- contains_only_expected_fields?(category),
         {:ok} <- validate_types(category),
         {:ok, category} <- validate_values(category) do
      {:ok, category}
    else
      {:error, cause} ->
        {:error, 400, cause}
    end
  end

  def validate_types(category) do
    validated = Enum.map(Map.keys(category), fn key ->
      array_based_fields = ["subcategories", "supercategories"]
      all_fields = @required_fields ++ @optional_fields

      if key in all_fields -- array_based_fields do
        if is_binary(category[key]), do: {:ok}, else: {:error, "The #{key} field should be a string"}
      else
        if is_list(category[key]), do: {:ok}, else: {:error, "The #{key} field should be a list"}
      end
    end)

    invalid = Enum.filter(validated, fn
      {:ok} -> false
      {:error, _} -> true
    end)

    if invalid === [] do
      {:ok}
    else
      List.first invalid
    end
  end

  def validate_values(category) do
    validated = Enum.map(Map.keys(category), fn key ->
      if is_binary(category[key]) do
        validate_field(key, String.trim(category[key]))
      else
        validate_field(key, category[key])
      end
    end)

    invalid = Enum.filter(validated, fn
      {:ok, _map} -> false
      {:error, _} -> true
    end)

    if invalid === [] do
      category = Enum.reduce(validated, %{}, fn {:ok, map}, values ->
        Map.merge(values, map)
      end)

      {:ok, category}
    else
      List.first invalid
    end
  end

  def validate_field("name", value) do
    if String.length(value) > 0 and String.length(value) < 51 do
      {:ok, %{"name" => value}}
    else
      {:error, "The name field should have a length of between 1 and 50 (inclusive)"}
    end
  end

  def validate_field("introduction", value) do
    if String.length(value) > 0 and String.length(value) < 6_001 do
      {:ok, %{"introduction" => value}}
    else
      {:error, "The introduction field should have a length of between 1 and 6000 (inclusive)"}
    end
  end

  def validate_field("subcategories", value) do
    validated = Enum.all?(value, fn category ->
      String.length(category) > 0 and String.length(category) < 51
    end)

    if validated do
      {:ok, %{"subcategories" => value}}
    else
      {:error, "Invalid subcategory name(s) given"}
    end
  end

  def validate_field("supercategories", value) do
    validated = Enum.all?(value, fn category ->
      String.length(category) > 0 and String.length(category) < 51
    end)

    if validated do
      {:ok, %{"supercategories" => value}}
    else
      {:error, "Invalid supercategory name(s) given"}
    end
  end

  def contains_required_fields?(category) do
    if @required_fields -- Map.keys(category) == [] do
      {:ok}
    else
      {:error, "Required fields are missing (expecting: #{Enum.join(@required_fields, ", ")})"}
    end
  end

  def contains_only_expected_fields?(category) do
    all_fields = @required_fields ++ @optional_fields
    if Map.keys(category) -- all_fields == [] do
      {:ok}
    else
      {:error, "Unknown fields given (expecting: #{Enum.join(all_fields, ", ")})"}
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

  def valid_show_view_type?(view_type) do
    if view_type === nil do
      {:ok, @default_show_view_type}
    else
      if Enum.member?(@show_view_types, view_type) do
        {:ok, view_type}
      else
        {:error, 400, "Invalid view type given (expecting: #{Enum.join(@show_view_types, ", ")})"}
      end
    end
  end

  def does_not_exist?(category_url) do
    case valid?(category_url) do
      {:ok, _category} ->
        {:error, 400, "The category with the specified name already exists"}
      {:error, 404, _status} ->
        {:ok}
    end
  end

  def does_not_exist?(new_category_url, old_category_url) do
    if new_category_url === old_category_url do
      {:ok}
    else
      case valid?(new_category_url) do
        {:ok, _category} ->
          {:error, 400, "The category with the specified name already exists"}
        {:error, 404, _status} ->
          {:ok}
      end
    end
  end

  def has_no_delete_patch?(category_url) do
    query = """
      MATCH (c:Category {url: {category_url}}),
        (c)<-[:DELETE]-(:User)
      RETURN c
    """

    params = %{category_url: category_url}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result === nil do
      {:ok}
    else
      {:error, 400, "The specified category already has a delete patch"}
    end
  end

  def update_patch_exists?(_category_url, nil), do: {:ok}

  def update_patch_exists?(category_url, patch_revision_id) do
    query = """
      MATCH (category:Category {url: {url}}),
        (category)-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
      RETURN category
    """

    params = %{url: category_url, patch_revision_id: patch_revision_id}

    if Neo4j.query!(Neo4j.conn, query, params) === [] do
      {:error, 404, "Update patch not found"}
    else
      {:ok}
    end
  end

  def valid?(nil = _category_url), do: {:ok, nil}

  def valid?(category_url) do
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

  def all_valid?([] = _categories) do
    {:error, 400, "At least one category must be given"}
  end

  def all_valid?(categories) do
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

  def valid_linked_categories?(subcategories, supercategories, category) do
    subcategories = if subcategories === nil, do: [], else: subcategories
    supercategories = if supercategories === nil, do: [], else: supercategories

    if subcategories === [] and supercategories === [] do
      {:ok}
    else
      if MapSet.size(MapSet.intersection(MapSet.new(subcategories), MapSet.new(supercategories))) === 0 do
        linked_categories = subcategories ++ supercategories

        if Enum.member?(linked_categories, category) do
          {:error, 400, "A category may not be a subcategory of itself"}
        else
          all_valid?(linked_categories)
        end
      else
        {:error, 400, "A category may not have the same category in its super and sub categories"}
      end
    end
  end

  def contains_nothing?(category_url) do
    query = """
      MATCH (n)-[:CATEGORY]->(category:Category {url: {category_url}})
      RETURN n
    """

    params = %{category_url: category_url}

    category = Neo4j.query!(Neo4j.conn, query, params)

    if category == [] do
      {:ok}
    else
      {:error, 400, "A category cannot be deleted whilst linked to symbols or articles"}
    end
  end

  def fetch_all(order_by, ordering, offset, limit, nil = _search_term, _full_search) do
    query = """
      MATCH (c:Category)
      OPTIONAL MATCH (c)-[:SUBCATEGORY]->(sc:Category)
      OPTIONAL MATCH (pc:Category)-[:SUBCATEGORY]->(c)

      WITH c,
        COLLECT(
          CASE sc WHEN NULL THEN NULL ELSE {category: {name: sc.name, url: sc.url}} END
        ) AS subcategories,
        COLLECT(
          CASE pc WHEN NULL THEN NULL ELSE {category: {name: pc.name, url: pc.url}} END
        ) AS supercategories

      ORDER BY LOWER(c.#{order_by}) #{ordering}

      WITH COLLECT({
        category: {
          name: c.name,
          url: c.url,
          subcategories: subcategories,
          supercategories: supercategories
        }
      }) AS categories

      RETURN {
        categories: categories[#{offset}..#{offset + limit}],
        meta: {
          total: LENGTH(categories),
          offset: #{offset},
          limit: #{limit}
        }
      } AS result
    """

    List.first Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all(order_by, ordering, offset, limit, search_term, full_search) do
    {column, search_term} =
      if full_search do
        {"introduction", "(?i).*#{search_term}.*"}
      else
        if String.first(search_term) === "=" do
          {"name", "(?i)#{String.slice(search_term, 1..-1)}"}
        else
          {"name", "(?i).*#{search_term}.*"}
        end
      end

    query = """
      MATCH (c:Category)

      WHERE c.#{column} =~ {search_term}

      WITH c

      ORDER BY LOWER(c.#{order_by}) #{ordering}

      WITH COLLECT({category: {name: c.name, url: c.url}}) AS categories

      RETURN {
        categories: categories[#{offset}..#{offset + limit}],
        meta: {
          total: LENGTH(categories),
          offset: #{offset},
          limit: #{limit}
        }
      } AS result
    """

    params = %{search_term: search_term}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_all_patches("all") do
    query = """
      MATCH (c:Category)
      OPTIONAL MATCH (c)-[:UPDATE]->(ucp:UpdateCategoryPatch),
        (ucp)-[r:CONTRIBUTOR]->(u:User)
      WITH c, ucp, r, u, EXISTS((c)<-[:DELETE]-(:User)) AS delete
      WHERE ucp IS NOT NULL OR delete
      RETURN {
        category: c,
        updates: COLLECT(CASE ucp WHEN NULL THEN NULL ELSE {
          update: ucp,
          user: {
            username: u.username,
            name: u.name,
            privilege_level: u.privilege_level,
            avatar_url: u.avatar_url
          },
          date: r.date
        } END),
        delete: delete
      } AS patches
    """

    %{inserts: fetch_all_patches("insert"),
      patches: Neo4j.query!(Neo4j.conn, query)}
  end

  def fetch_all_patches("insert") do
    query = """
      MATCH (c:InsertCategoryPatch),
        (c)-[r:CONTRIBUTOR]->(u:User)
      RETURN {
        category: c,
        user: {
          username: u.username,
          name: u.name,
          privilege_level: u.privilege_level,
          avatar_url: u.avatar_url
        },
        date: r.date
      } AS category_insert
    """

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_patches("update") do
    query = """
      MATCH (c:Category)-[:UPDATE]->(ucp:UpdateCategoryPatch),
        (ucp)-[r:CONTRIBUTOR]->(u:User)
      RETURN {
        category: c,
        updates: COLLECT({
            update: ucp,
            user: {
              username: u.username,
              name: u.name,
              privilege_level: u.privilege_level,
              avatar_url: u.avatar_url
            },
            date: r.date
          })
      } AS category_update
    """

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_patches("delete") do
    query = """
      MATCH (category_delete:Category)<-[:DELETE]-(:User)
      RETURN category_delete
    """
    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_all_deleted do
    Neo4j.query!(Neo4j.conn, "MATCH (category:CategoryDeleted) RETURN category")
  end

  def fetch_patches_for(category_url) do
    query = """
      MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (c)-[:UPDATE]->(ucp:UpdateCategoryPatch),
        (ucp)-[r:CONTRIBUTOR]->(u:User)
      OPTIONAL MATCH (c)<-[rd:DELETE]->(:User)
      RETURN {
        category: c,
        updates: CASE ucp WHEN NULL THEN [] ELSE COLLECT({
            update: ucp,
            user: {
              username: u.username,
              name: u.name,
              privilege_level: u.privilege_level,
              avatar_url: u.avatar_url
            },
            date: r.date
          }) END,
        delete: CASE rd WHEN NULL THEN FALSE ELSE TRUE END
      } AS patches
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_insert_patch_for(category_url) do
    query = """
      MATCH (c:InsertCategoryPatch {url: {category_url}}),
        (c)-[r:CONTRIBUTOR]->(u:User)
      RETURN {
        category: c,
        user: {
          username: u.username,
          name: u.name,
          privilege_level: u.privilege_level,
          avatar_url: u.avatar_url
        },
        date: r.date
      } AS category_insert
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_update_patch_for(category_url, patch_id) do
    query = """
      MATCH (c:Category {url: {category_url}}),
        (ucp:UpdateCategoryPatch {revision_id: {patch_id}}),
        (c)-[:UPDATE]->(ucp),
        (ucp)-[r:CONTRIBUTOR]->(u:User)

      OPTIONAL MATCH (c)-[:SUBCATEGORY]->(sc:Category)
      OPTIONAL MATCH (pc:Category)-[:SUBCATEGORY]->(c)
      OPTIONAL MATCH (ucp)-[:SUBCATEGORY]->(sc2:Category)
      OPTIONAL MATCH (pc2:Category)-[:SUBCATEGORY]->(ucp)

      RETURN {
        category: {
          name: c.name,
          url: c.url,
          introduction: c.introduction,
          revision_id: c.revision_id,
          subcategories: COLLECT(
            CASE sc WHEN NULL THEN NULL ELSE {category: {name: sc.name, url: sc.url}} END
          ),
          supercategories: COLLECT(
            CASE pc WHEN NULL THEN NULL ELSE {category: {name: pc.name, url: pc.url}} END
          )
        },
        update: {
          update: {
            name: ucp.name,
            url: ucp.url,
            introduction: ucp.introduction,
            revision_id: ucp.revision_id,
            against_revision: ucp.against_revision,
            subcategories: COLLECT(
              CASE sc2 WHEN NULL THEN NULL ELSE {category: {name: sc2.name, url: sc2.url}} END
            ),
            supercategories: COLLECT(
              CASE pc2 WHEN NULL THEN NULL ELSE {category: {name: pc2.name, url: pc2.url}} END
            )
          },
          user: {
            username: u.username,
            name: u.name,
            privilege_level: u.privilege_level,
            avatar_url: u.avatar_url
          },
          date: r.date
        }
      } AS category_update
    """

    params = %{category_url: category_url, patch_id: patch_id}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_update_patches_for(category_url) do
    query = """
      MATCH (c:Category {url: {category_url}})-[:UPDATE]->(ucp:UpdateCategoryPatch),
        (ucp)-[r:CONTRIBUTOR]->(u:User)
      RETURN {
        category: c,
        updates: COLLECT({
            update: ucp,
            user: {
              username: u.username,
              name: u.name,
              privilege_level: u.privilege_level,
              avatar_url: u.avatar_url
            },
            date: r.date
          })
      } AS category_update
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch_delete_patch_for(category_url) do
    query = """
      MATCH (category_delete:Category {url: {category_url}})
      OPTIONAL MATCH (category_delete)<-[rd:DELETE]-(:User)

      RETURN category_delete, rd
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch(category_url, "normal") do
    query = """
      MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (c)-[:SUBCATEGORY]->(sc:Category)
      OPTIONAL MATCH (pc:Category)-[:SUBCATEGORY]->(c)

      RETURN {
        name: c.name,
        url: c.url,
        introduction: c.introduction,
        revision_id: c.revision_id,
        subcategories: COLLECT(
          CASE sc WHEN NULL THEN NULL ELSE {category: {name: sc.name, url: sc.url}} END
        ),
        supercategories: COLLECT(
          CASE pc WHEN NULL THEN NULL ELSE {category: {name: pc.name, url: pc.url}} END
        )
      } as category
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def fetch(category_url, "full") do
    query = """
      MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (c)-[:SUBCATEGORY]->(sc:Category)
      OPTIONAL MATCH (pc:Category)-[:SUBCATEGORY]->(c)
      OPTIONAL MATCH (s:Symbol)-[:CATEGORY]->(c)
      OPTIONAL MATCH (a:Article)-[:CATEGORY]->(c), (a)-[:AUTHOR]->(u:User), (a)-[:CATEGORY]->(ac)

      WITH c,
        a,
        u,
        COLLECT(
          CASE s WHEN NULL THEN NULL ELSE {symbol: {name: s.name, url: s.url, type: s.type, id: s.id}} END
        ) AS symbols,
        COLLECT(
          CASE ac WHEN NULL THEN NULL ELSE {category: {name: ac.name, url: ac.url}} END
        ) AS acs,
        COLLECT(
          CASE sc WHEN NULL THEN NULL ELSE {category: {name: sc.name, url: sc.url}} END
        ) AS subcategories,
        COLLECT(
          CASE pc WHEN NULL THEN NULL ELSE {category: {name: pc.name, url: pc.url}} END
        ) AS supercategories

      RETURN {
        name: c.name,
        url: c.url,
        introduction: c.introduction,
        revision_id: c.revision_id,
        subcategories: subcategories,
        supercategories: supercategories,
        symbols: symbols,
        articles: COLLECT(CASE a WHEN NULL THEN NULL ELSE {
          article: {
            user: {
              username: u.username,
              name: u.name,
              privilege_level: u.privilege_level
            },
            categories: acs,
            title: a.title,
            url: a.url,
            date: a.date,
            excerpt: a.excerpt
          }
        } END)
      } as category
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def insert(category, review, username) do
    label = if review === 1, do: "InsertCategoryPatch", else: "Category"

    {linked_categories_match, linked_categories_join, linked_categories_params, _linked_categories_propagate} =
      linked_categories_query_builder(category["subcategories"], category["supercategories"], "c")

    query = """
      MATCH (user:User {username: {username}})
        #{linked_categories_match}

      CREATE (c:#{label} {
          name: {name},
          introduction: {introduction},
          url: {url},
          revision_id: {rev_id}
        }),
        (c)-[:CONTRIBUTOR {type: "insert", date: timestamp()}]->(user)
        #{linked_categories_join}

      WITH c

      OPTIONAL MATCH (c)-[:SUBCATEGORY]->(sc:Category)

      WITH c,
        COLLECT(CASE sc WHEN NULL THEN NULL ELSE {category: {name: sc.name, url: sc.url}} END) AS scs

      OPTIONAL MATCH (pc:Category)-[:SUBCATEGORY]->(c)

      WITH c,
        scs,
        COLLECT(CASE pc WHEN NULL THEN NULL ELSE {category: {name: pc.name, url: pc.url}} END) AS pcs

      RETURN {
        name: c.name,
        url: c.url,
        introduction: c.introduction,
        revision_id: c.revision_id,
        subcategories: scs,
        supercategories: pcs,
        symbols: [],
        articles: []
      } as category
    """

    params =
      Map.merge(linked_categories_params, %{
        name: category["name"],
        introduction: category["introduction"],
        url: category["url_name"],
        rev_id: :rand.uniform(100_000_000),
        username: username
      })

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def update(old_category, new_category, 0 = _review, username, nil = _patch_revision_id) do
    {linked_categories_match, linked_categories_join, linked_categories_params, linked_categories_propagate} =
      linked_categories_query_builder(new_category["subcategories"], new_category["supercategories"], "category")

    query = """
      MATCH (category:Category {url: {old_url}}),
        (user:User {username: {username}})
        #{linked_categories_match}

      OPTIONAL MATCH (category)-[r2:REVISION]->(category_revision:CategoryRevision)
      DELETE r2

      WITH category,
        user,
        category_revision
        #{linked_categories_propagate}

      OPTIONAL MATCH (category)-[r3:SUBCATEGORY]->(subcats:Category)
      DELETE r3

      WITH category,
        user,
        category_revision,
        COLLECT(subcats) AS unused
        #{linked_categories_propagate}

      OPTIONAL MATCH (category)<-[r4:SUBCATEGORY]-(supercats:Category)
      DELETE r4

      WITH category,
        user,
        category_revision,
        COLLECT(supercats) AS unused
        #{linked_categories_propagate}

      OPTIONAL MATCH (category)-[r5:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision)
      DELETE r5

      WITH category,
        user,
        category_revision,
        ucpr
        #{linked_categories_propagate}

      CREATE (old_category:CategoryRevision {
          name: category.name,
          introduction: category.introduction,
          url: category.url,
          revision_id: category.revision_id
        }),
        (category)-[:REVISION]->(old_category)
        #{linked_categories_join}

      WITH category,
        old_category,
        user,
        category_revision,
        ucpr

      MATCH (category)-[r:CONTRIBUTOR]->(old_user:User)
      CREATE (old_category)-[:CONTRIBUTOR {type: r.type, date: r.date}]->(old_user)
      DELETE r

      WITH category,
        old_category,
        user,
        category_revision,
        ucpr,
        COLLECT(old_user) AS unused

      CREATE (category)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user)

      FOREACH (ignored IN CASE category_revision WHEN NULL THEN [] ELSE [1] END |
        CREATE (old_category)-[:REVISION]->(category_revision)
      )

      FOREACH (ignored IN CASE ucpr WHEN NULL THEN [] ELSE [1] END |
        CREATE (old_category)-[:UPDATE_REVISION]->(ucpr)
      )

      SET category.name = {new_name},
        category.introduction = {new_introduction},
        category.url = {new_url},
        category.revision_id = {new_rev_id}
    """

    params =
      Map.merge(linked_categories_params, %{
        new_name: new_category["name"],
        new_introduction: new_category["introduction"],
        new_url: new_category["url"],
        new_rev_id: :rand.uniform(100_000_000),
        old_url: old_category["url"],
        username: username
      })

    Neo4j.query!(Neo4j.conn, query, params)

    fetch(new_category["url"], "full")
  end

  def update(old_category, new_category, 1 = _review, username, nil = _patch_revision_id) do
    {linked_categories_match, linked_categories_join, linked_categories_params, _linked_categories_propagate} =
      linked_categories_query_builder(new_category["subcategories"], new_category["supercategories"], "ucp")

    query = """
      MATCH (category:Category {url: {old_url}}),
        (user:User {username: {username}})
        #{linked_categories_match}

      CREATE (ucp:UpdateCategoryPatch {
          name: {name},
          introduction: {introduction},
          url: {new_url},
          revision_id: {rev_id},
          against_revision: {against_rev}
        }),
        (category)-[:UPDATE]->(ucp),
        (ucp)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user)
        #{linked_categories_join}
    """

    params =
      Map.merge(linked_categories_params, %{
        name: new_category["name"],
        introduction: new_category["introduction"],
        new_url: new_category["url"],
        rev_id: :rand.uniform(100_000_000),
        old_url: old_category["url"],
        against_rev: old_category["revision_id"],
        username: username
      })

    Neo4j.query!(Neo4j.conn, query, params)

    fetch(old_category["url"], "full")
  end

  def update(old_category, new_category, 0 = _review, username, patch_revision_id) do
    {linked_categories_match, linked_categories_join, linked_categories_params, linked_categories_propagate} =
      linked_categories_query_builder(new_category["subcategories"], new_category["supercategories"], "category")

    query = """
      MATCH (category:Category {url: {old_url}}),
        (user:User {username: {username}}),
        (category)-[r2:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
        #{linked_categories_match}

      OPTIONAL MATCH (category)-[r3:REVISION]->(category_revision:CategoryRevision)
      DELETE r2, r3

      WITH category,
        user,
        cp,
        category_revision
        #{linked_categories_propagate}

      OPTIONAL MATCH (category)-[r4:SUBCATEGORY]->(subcats:Category)
      DELETE r4

      WITH category,
        user,
        cp,
        category_revision,
        COLLECT(subcats) AS unused
        #{linked_categories_propagate}

      OPTIONAL MATCH (category)<-[r5:SUBCATEGORY]-(supercats:Category)
      DELETE r5

      WITH category,
        user,
        cp,
        category_revision,
        COLLECT(supercats) AS unused
        #{linked_categories_propagate}

      OPTIONAL MATCH (cp)-[r6:SUBCATEGORY]->(subcats2:Category)
      DELETE r6

      WITH category,
        user,
        cp,
        category_revision,
        COLLECT(subcats2) AS unused
        #{linked_categories_propagate}

      OPTIONAL MATCH (cp)<-[r7:SUBCATEGORY]-(supercats2:Category)
      DELETE r7

      WITH category,
        user,
        cp,
        category_revision,
        COLLECT(supercats2) AS unused
        #{linked_categories_propagate}

      OPTIONAL MATCH (category)-[r8:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision)
      DELETE r8

      WITH category,
        user,
        cp,
        category_revision,
        ucpr
        #{linked_categories_propagate}

      CREATE (old_category:CategoryRevision {
          name: category.name,
          introduction: category.introduction,
          url: category.url,
          revision_id: category.revision_id
        }),
        (category)-[:UPDATE_REVISION]->(cp),
        (category)-[:REVISION]->(old_category)
        #{linked_categories_join}

      WITH category,
        user,
        cp,
        category_revision,
        ucpr,
        old_category

      MATCH (category)-[r:CONTRIBUTOR]->(old_user:User)
      CREATE (old_category)-[:CONTRIBUTOR {type: r.type, date: r.date}]->(old_user)
      DELETE r

      WITH category,
        user,
        cp,
        category_revision,
        ucpr,
        old_category,
        COLLECT(old_user) AS unused

      CREATE (category)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user)

      FOREACH (ignored IN CASE category_revision WHEN NULL THEN [] ELSE [1] END |
        CREATE (old_category)-[:REVISION]->(category_revision)
      )

      FOREACH (ignored IN CASE ucpr WHEN NULL THEN [] ELSE [1] END |
        CREATE (old_category)-[:UPDATE_REVISION]->(ucpr)
      )

      REMOVE cp:UpdateCategoryPatch
      SET cp:UpdateCategoryPatchRevision

      SET category.name = {new_name},
        category.introduction = {new_introduction},
        category.url = {new_url},
        category.revision_id = {new_rev_id}
    """

    params =
      Map.merge(linked_categories_params, %{
        old_url: old_category["url"],
        patch_revision_id: patch_revision_id,
        new_name: new_category["name"],
        new_url: new_category["url"],
        new_introduction: new_category["introduction"],
        new_rev_id: :rand.uniform(100_000_000),
        username: username
      })

    Neo4j.query!(Neo4j.conn, query, params)

    fetch(new_category["url"], "full")
  end

  def update(old_category, new_category, 1 = _review, username, patch_revision_id) do
    {linked_categories_match, linked_categories_join, linked_categories_params, linked_categories_propagate} =
      linked_categories_query_builder(new_category["subcategories"], new_category["supercategories"], "new_ucp")

    query = """
      MATCH (category:Category {url: {old_url}}),
        (category)-[r:UPDATE]->(old_ucp:UpdateCategoryPatch {revision_id: {patch_revision_id}}),
        (user:User {username: {username}})
        #{linked_categories_match}

      OPTIONAL MATCH (old_ucp)-[r2:SUBCATEGORY]->(subcats:Category)
      DELETE r, r2

      WITH category,
        old_ucp,
        user,
        COLLECT(subcats) AS unused
        #{linked_categories_propagate}

      OPTIONAL MATCH (old_ucp)<-[r3:SUBCATEGORY]-(supercats:Category)
      DELETE r3

      WITH category,
        old_ucp,
        user,
        COLLECT(supercats) AS unused
        #{linked_categories_propagate}

      CREATE (new_ucp:UpdateCategoryPatch {
          name: {name},
          introduction: {introduction},
          url: {new_url},
          revision_id: {rev_id},
          against_revision: {against_rev}
        }),
        (category)-[:UPDATE]->(new_ucp),
        (new_ucp)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user),
        (new_ucp)-[:UPDATE_REVISION]->(old_ucp)
        #{linked_categories_join}

      REMOVE old_ucp:UpdateCategoryPatch
      SET old_ucp:UpdateCategoryPatchRevision
    """

    params =
      Map.merge(linked_categories_params, %{
        name: new_category["name"],
        introduction: new_category["introduction"],
        new_url: new_category["url"],
        rev_id: :rand.uniform(100_000_000),
        old_url: old_category["url"],
        against_rev: old_category["revision_id"],
        patch_revision_id: patch_revision_id,
        username: username
      })

    Neo4j.query!(Neo4j.conn, query, params)

    fetch(old_category["url"], "full")
  end

  defp linked_categories_query_builder(nil, nil, _name), do: {"", "", %{}, ""}

  defp linked_categories_query_builder(nil = _subcategories, supercategories, name) do
    linked_categories_query_builder([], supercategories, name)
  end

  defp linked_categories_query_builder(subcategories, nil = _supercategories, name) do
    linked_categories_query_builder(subcategories, [], name)
  end

  defp linked_categories_query_builder(subcategories, supercategories, name) do
    return =
      Enum.reduce(subcategories, {"", "", %{}, "", 0}, fn (cat, {m, j, p, w, n}) ->
        {
          m <> ", (cat#{n}:Category {url: {cat#{n}_url}})",
          j <> ", (#{name})-[:SUBCATEGORY]->(cat#{n})",
          Map.put(p, "cat#{n}_url", cat),
          w <> ", cat#{n}",
          n + 1
        }
      end)

    {m, j, p, w, _n} =
      Enum.reduce(supercategories, return, fn (cat, {m, j, p, w, n}) ->
        {
          m <> ", (cat#{n}:Category {url: {cat#{n}_url}})",
          j <> ", (cat#{n})-[:SUBCATEGORY]->(#{name})",
          Map.put(p, "cat#{n}_url", cat),
          w <> ", cat#{n}",
          n + 1
        }
      end)

    {m, j, p, w}
  end

  def apply_patch?(category_url, %{"action" => "insert"}, username) do
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

          CREATE (cp)-[:CONTRIBUTOR {type: "apply_insert", date: timestamp()}]->(user)

          WITH cp

          OPTIONAL MATCH (cp)-[:SUBCATEGORY]->(sc:Category)

          WITH cp,
            COLLECT(CASE sc WHEN NULL THEN NULL ELSE {category: {name: sc.name, url: sc.url}} END) AS scs

          OPTIONAL MATCH (pc:Category)-[:SUBCATEGORY]->(cp)

          WITH cp,
            scs,
            COLLECT(CASE pc WHEN NULL THEN NULL ELSE {category: {name: pc.name, url: pc.url}} END) AS pcs

          RETURN {
            name: cp.name,
            url: cp.url,
            introduction: cp.introduction,
            revision_id: cp.revision_id,
            subcategories: scs,
            supercategories: pcs,
            symbols: [],
            articles: []
          } as category
        """

        {:ok, List.first Neo4j.query!(Neo4j.conn, query, params)}
      end
    end
  end

  def apply_patch?(category_url, %{"action" => "update", "patch_revision_id" => patch_revision_id}, username) do
    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (c)-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
      RETURN c, cp
    """
    params = %{patch_revision_id: patch_revision_id, category_url: category_url, username: username}

    category = List.first Neo4j.query!(Neo4j.conn, query, params)

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
            MATCH (category:Category {url: {category_url}}),
              (category)-[:UPDATE]->(ucp:UpdateCategoryPatch {revision_id: {patch_revision_id}}),
              (ucp)-[r2:CONTRIBUTOR]->(user:User),
              (new_user:User {username: {username}})

            WITH category,
              r2,
              ucp,
              user,
              new_user

            OPTIONAL MATCH (category)-[r3:REVISION]->(category_revision:CategoryRevision)
            DELETE r3

            WITH category,
              r2,
              ucp,
              user,
              new_user,
              category_revision

            OPTIONAL MATCH (category)-[r4:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision)
            DELETE r4

            WITH category,
              r2,
              ucp,
              user,
              new_user,
              category_revision,
              ucpr

            OPTIONAL MATCH (category)-[r5:SUBCATEGORY]->(subcats:Category)
            DELETE r5

            WITH category,
              r2,
              ucp,
              user,
              new_user,
              category_revision,
              ucpr,
              COLLECT(subcats) AS unused

            OPTIONAL MATCH (category)<-[r6:SUBCATEGORY]-(supcats:Category)
            DELETE r6

            WITH category,
              r2,
              ucp,
              user,
              new_user,
              category_revision,
              ucpr,
              COLLECT(supcats) AS unused

            OPTIONAL MATCH (ucp)-[:SUBCATEGORY]->(sc:Category)

            WITH category,
              r2,
              ucp,
              user,
              new_user,
              category_revision,
              ucpr,
              COLLECT(sc) AS scs

            OPTIONAL MATCH (ucp)<-[:SUBCATEGORY]-(pc:Category)

            WITH category,
              r2,
              ucp,
              user,
              new_user,
              category_revision,
              ucpr,
              scs,
              COLLECT(pc) AS pcs

            CREATE (old_category:CategoryRevision {
                name: category.name,
                introduction: category.introduction,
                url: category.url,
                revision_id: category.revision_id
              }),
              (category)-[:REVISION]->(old_category)

            WITH category,
              old_category,
              category_revision,
              user,
              new_user,
              ucp,
              ucpr,
              scs,
              pcs,
              r2

            MATCH (category)-[r:CONTRIBUTOR]->(old_user:User)
            CREATE (old_category)-[:CONTRIBUTOR {type: r.type, date: r.date}]->(old_user)
            DELETE r

            WITH category,
              old_category,
              category_revision,
              user,
              new_user,
              ucp,
              ucpr,
              scs,
              pcs,
              r2,
              COLLECT(old_user) AS unused

            CREATE (category)-[:CONTRIBUTOR {type: "apply_update", date: timestamp()}]->(new_user),
              (category)-[:CONTRIBUTOR {type: r2.type, date: r2.date}]->(user)

            FOREACH (ignored IN CASE category_revision WHEN NULL THEN [] ELSE [1] END |
              CREATE (old_category)-[:REVISION]->(category_revision)
            )

            FOREACH (ignored IN CASE ucpr WHEN NULL THEN [] ELSE [1] END |
              CREATE (old_category)-[:UPDATE_REVISION]->(ucpr)
            )

            FOREACH (sc IN scs |
              CREATE (category)-[:SUBCATEGORY]->(sc)
            )

            FOREACH (pc IN pcs |
              CREATE (category)<-[:SUBCATEGORY]-(pc)
            )

            SET category.name = ucp.name,
              category.introduction = ucp.introduction,
              category.url = ucp.url,
              category.revision_id = ucp.revision_id

            DELETE r2
            DETACH DELETE ucp
          """

          List.first Neo4j.query!(Neo4j.conn, query, params)

          {:ok, fetch(category["cp"]["url"], "full")}
        end
      end
    end
  end

  def apply_patch?(category_url, %{"action" => "delete"}, username) do
    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (c)<-[cp:DELETE]-(:User)
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
          MATCH (c:Category {url: {category_url}})<-[r:DELETE]-(user2:User),
            (user:User {username: {username}})
          REMOVE c:Category
          SET c:CategoryDeleted
          CREATE (c)-[:CONTRIBUTOR {type: "delete", date: timestamp()}]->(user2),
            (c)-[:CONTRIBUTOR {type: "apply_delete", date: timestamp()}]->(user)
          DELETE r
        """

        Neo4j.query!(Neo4j.conn, query, params)

        {:ok, 204}
      end
    end
  end

  def discard_patch?(category_url, %{"action" => "insert"}, username) do
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
        CREATE (cp)-[:CONTRIBUTOR {type: "discard_insert", date: timestamp()}]->(user)
      """

      Neo4j.query!(Neo4j.conn, query, params)

      {:ok, 200}
    end
  end

  def discard_patch?(category_url, %{"action" => "update", "patch_revision_id" => patch_revision_id}, username) do
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
          CREATE (cp)-[:CONTRIBUTOR {type: "discard_update", date: timestamp()}]->(user)
        """
        Neo4j.query!(Neo4j.conn, query, params)

        {:ok, 200}
      end
    end
  end

  def discard_patch?(category_url, %{"action" => "delete"}, username) do
    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (cp)<-[:DELETE]-(:User)
      RETURN c, cp
    """
    params = %{category_url: category_url, username: username}

    category = List.first Neo4j.query!(Neo4j.conn, query, params)

    if category["c"] == nil do
      {:error, 404, "Category not found"}
    else
      if category["cp"] == nil do
        {:error, 404, "Delete patch not found for the specified category"}
      else
        query = """
          MATCH (c:Category {url: {category_url}}),
            (user:User {username: {username}}),
            (c)<-[r:DELETE]-(:User)
          DELETE r
          MERGE (c)-[r2:CONTRIBUTOR {type: "discard_delete"}]->(user)
          SET r2.date = timestamp()
        """

        Neo4j.query!(Neo4j.conn, query, params)

        {:ok, 200}
      end
    end
  end

  def soft_delete(category_url, 0, username) do
    query = """
      MATCH (c:Category {url: {url}}),
        (user:User {username: {username}})
      REMOVE c:Category
      SET c:CategoryDeleted
      CREATE (c)-[:CONTRIBUTOR {type: "delete", date: timestamp()}]->(user)
    """

    params = %{url: category_url, username: username}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def soft_delete(category_url, _review = 1, username) do
    query = """
      MATCH (c:Category {url: {url}}),
        (user:User {username: {username}})
      CREATE (c)<-[:DELETE]-(user)
    """

    params = %{url: category_url, username: username}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  def soft_delete_undo(category_url, 0, username) do
    query = """
      MATCH (cd:CategoryDeleted {url: {url}}),
        (u:User {username: {username}})
        (cd)-[r1:CONTRIBUTOR {type: "delete"}]->(u)
      OPTIONAL MATCH (cd)-[r2:CONTRIBUTOR {type: "apply_delete"}]->(u)

      REMOVE sd:CategoryDeleted
      SET sd:Category
      DELETE r1, r2

      CREATE (s)-[:CONTRIBUTOR {type: "undo_delete", date: timestamp()}]->(u)
    """

    params = %{url: category_url, username: username}

    Neo4j.query!(Neo4j.conn, query, params)
  end
end
