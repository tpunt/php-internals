defmodule PhpInternals.Api.Categories.Category do
  use PhpInternals.Web, :model

  alias PhpInternals.Cache.ResultCache
  alias PhpInternals.Utilities
  alias PhpInternals.Api.Categories.CategoryView
  alias PhpInternals.Api.Locks.Lock

  @required_fields ["name", "introduction"]
  @optional_fields ["subcategories", "supercategories"]

  @valid_ordering_fields ["name"]
  @default_order_by "name"

  @show_view_types ["normal", "overview"]
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
        if is_list(category[key]) do
          if Enum.all?(category[key], &is_binary/1) do
            {:ok}
          else
            {:error, "The category URI names should be strings"}
          end
        else
          {:error, "The #{key} field should be a list"}
        end
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
    if String.length(value) > 0 and String.length(value) < 15_001 do
      {:ok, %{"introduction" => value}}
    else
      {:error, "The introduction field should have a length of between 1 and 15000 (inclusive)"}
    end
  end

  def validate_field("subcategories", value) do
    validated = Enum.all?(value, fn category ->
      String.length(category) > 0 and String.length(category) < 51
    end)

    if validated do
      if MapSet.size(MapSet.new(value)) === length(value) do
        {:ok, %{"subcategories" => value}}
      else
        {:error, "Duplicate subcategory names given"}
      end
    else
      {:error, "Invalid subcategory name(s) given"}
    end
  end

  def validate_field("supercategories", value) do
    validated = Enum.all?(value, fn category ->
      String.length(category) > 0 and String.length(category) < 51
    end)

    if validated do
      if MapSet.size(MapSet.new(value)) === length(value) do
        {:ok, %{"supercategories" => value}}
      else
        {:error, "Duplicate supercategory names given"}
      end
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

  def valid_cache?(nil = _category_url), do: {:ok, nil}

  def valid_cache?(category_url) do
    key = "categories/#{category_url}?overview"
    case ResultCache.get(key) do
      {:not_found} ->
        case valid?(category_url) do
          {:ok, category} ->
            response = Phoenix.View.render_to_string(CategoryView, "show_overview.json", category: category)
            ResultCache.set(key, response)
            {:ok, response}
          error -> error
        end
      {:found, response} -> {:ok, response}
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

  def valid_and_fetch?(category_url) do
    query = """
      MATCH (category:Category {url: {category_url}})

      OPTIONAL MATCH (spc:Category)-[:SUBCATEGORY]->(category)

      WITH COLLECT(spc.url) AS spcs, category

      OPTIONAL MATCH (category)-[:SUBCATEGORY]->(sbc:Category)

      RETURN {
        name: category.name,
        url: category.url,
        revision_id: category.revision_id,
        introduction: category.introduction,
        subcategories: COLLECT(sbc.url),
        supercategories: spcs
      } AS category
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

  def fetch_all_cache(order_by, ordering, offset, limit, nil = _search_term, _full_search) do
    key = "categories?#{order_by}&#{ordering}&#{offset}&#{limit}&&0"
    ResultCache.fetch(key, fn ->
      all_categories = fetch_all(order_by, ordering, offset, limit, nil, false)
      ResultCache.group("categories", key)
      Phoenix.View.render_to_string(CategoryView, "index_overview.json", categories: all_categories["result"])
    end)
  end

  def fetch_all_cache(order_by, ordering, offset, limit, search_term, full_search) do
    # Don't bother caching search terms...
    # key = "categories?#{order_by}&#{ordering}&#{offset}&#{limit}&#{search_term}&#{full_search}"
    # ResultCache.fetch(key, fn ->
    #   all_categories = fetch_all(order_by, ordering, offset, limit, search_term, full_search)
    #   ResultCache.group("categories", key)
    #   Phoenix.View.render_to_string(CategoryView, "index_overview.json", categories: all_categories["result"])
    # end)

    all_categories = fetch_all(order_by, ordering, offset, limit, search_term, full_search)
    Phoenix.View.render_to_string(CategoryView, "index_overview.json", categories: all_categories["result"])
  end

  def fetch_all(order_by, ordering, offset, limit, nil = _search_term, _full_search) do
    query = """
      MATCH (c:Category)

      OPTIONAL MATCH (c)-[:SUBCATEGORY]->(sc:Category)

      WITH c,
        COLLECT(
          CASE sc WHEN NULL THEN NULL ELSE {category: {name: sc.name, url: sc.url}} END
        ) AS subcategories

      OPTIONAL MATCH (pc:Category)-[:SUBCATEGORY]->(c)

      WITH c,
        subcategories,
        COLLECT(
          CASE pc WHEN NULL THEN NULL ELSE {category: {name: pc.name, url: pc.url}} END
        ) AS supercategories

      ORDER BY LOWER(c.#{order_by}) #{ordering}

      WITH COLLECT({
        category: {
          name: c.name,
          url: c.url,
          revision_id: c.revision_id,
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
    {where_query, search_term} =
      if String.first(search_term) === "=" do
        {"WHERE c.name =~ {search_term}", "(?i)#{String.slice(search_term, 1..-1)}"}
      else
        if full_search === "1" do
          {"WHERE (c.name =~ {search_term} OR c.introduction =~ {search_term})", "(?ims).*#{search_term}.*"}
        else
          {"WHERE c.name =~ {search_term} ", "(?i).*#{search_term}.*"}
        end
      end

    query = """
      MATCH (c:Category)

      #{where_query}

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
        category: {
          name: c.name,
          url: c.url
        },
        updates: COLLECT(CASE ucp WHEN NULL THEN NULL ELSE {
          revision_id: ucp.revision_id,
          against_revision: ucp.against_revision,
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
        category: {
          name: c.name,
          url: c.url,
          revision_id: c.revision_id
        },
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
        category: {
          name: c.name,
          url: c.url
        },
        updates: COLLECT({
          revision_id: ucp.revision_id,
          against_revision: ucp.against_revision,
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
        category: {
          name: c.name,
          url: c.url
        },
        updates: CASE ucp WHEN NULL THEN [] ELSE COLLECT({
          revision_id: ucp.revision_id,
          against_revision: ucp.against_revision,
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

      OPTIONAL MATCH (c)-[:SUBCATEGORY]->(sc:Category)

      WITH c,
        r,
        u,
        COLLECT(
          CASE sc WHEN NULL THEN NULL ELSE {category: {name: sc.name, url: sc.url}} END
        ) AS scs

      OPTIONAL MATCH (pc:Category)-[:SUBCATEGORY]->(c)

      WITH c,
        r,
        u,
        scs,
        COLLECT(
          CASE pc WHEN NULL THEN NULL ELSE {category: {name: pc.name, url: pc.url}} END
        ) AS pcs

      RETURN {
        category: {
          name: c.name,
          url: c.url,
          introduction: c.introduction,
          revision_id: c.revision_id,
          subcategories: scs,
          supercategories: pcs
        },
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

  def fetch_revisions(category_url) do
    query = """
      MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (c)-[:REVISION*1..]->(cr:CategoryRevision)
      OPTIONAL MATCH (cr)-[crel:CONTRIBUTOR]->(u:User)

      WITH c, cr, COLLECT(
        CASE WHEN crel.type IN ["update", "insert"] THEN {
          revision_date: crel.date,
          type: crel.type,
          user: {
            username: u.username,
            name: u.name,
            privilege_level: u.privilege_level,
            avatar_url: u.avatar_url
          }
        } END) AS crel2

      RETURN {
        category: {
          name: c.name,
          url: c.url
        },
        revisions: COLLECT(CASE cr.revision_id WHEN NULL THEN NULL ELSE {
          revision_id: cr.revision_id,
          info: crel2
        } END)
      } AS category_revisions
    """

    params = %{category_url: category_url}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def valid_update?(category_url, revision_id) do
    query = """
      MATCH (c:Category {url: {category_url}}),
        (ucp:UpdateCategoryPatch {revision_id: {revision_id}}),
        (ucp)-[r:CONTRIBUTOR]->(u:User)

      OPTIONAL MATCH (ucp)-[:SUBCATEGORY]->(sc:Category)

      WITH c,
        ucp,
        r,
        u,
        COLLECT(
          CASE sc WHEN NULL THEN NULL ELSE {category: {name: sc.name, url: sc.url}} END
        ) AS scs

      OPTIONAL MATCH (pc:Category)-[:SUBCATEGORY]->(ucp)

      WITH c,
        ucp,
        r,
        u,
        scs,
        COLLECT(
          CASE pc WHEN NULL THEN NULL ELSE {category: {name: pc.name, url: pc.url}} END
        ) AS pcs

      RETURN {
        category: {
          name: c.name,
          url: c.url
        },
        update: {
          update: {
            name: ucp.name,
            url: ucp.url,
            introduction: ucp.introduction,
            revision_id: ucp.revision_id,
            against_revision: ucp.against_revision,
            subcategories: scs,
            supercategories: pcs
          },
          user: {
            username: u.username,
            name: u.name,
            privilege_level: u.privilege_level,
            avatar_url: u.avatar_url
          },
          date: r.date
        }
      } AS category_revision
    """

    params = %{category_url: category_url, revision_id: revision_id}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result["category_revision"]["category"]["name"] === nil do
      {:error, 404, "Category revision not found"}
    else
      {:ok, result}
    end
  end

  def valid_revision?(category_url, revision_id) do
    query = """
      MATCH (c:Category {url: {category_url}})-[:REVISION*]->(cr:CategoryRevision {revision_id: {revision_id}}),
        (cr)-[r:CONTRIBUTOR]->(u:User)

      WHERE r.type IN ["insert", "update"]

      OPTIONAL MATCH (sc:Category)
      WHERE sc.id IN cr.subcategories

      WITH c,
        cr,
        r,
        u,
        COLLECT(
          CASE sc WHEN NULL THEN NULL ELSE {category: {name: sc.name, url: sc.url}} END
        ) AS scs

      OPTIONAL MATCH (pc:Category)
      WHERE pc.id IN cr.supercategories

      WITH c,
        cr,
        r,
        u,
        scs,
        COLLECT(
          CASE pc WHEN NULL THEN NULL ELSE {category: {name: pc.name, url: pc.url}} END
        ) AS pcs

      RETURN {
        category: {
          name: c.name,
          url: c.url
        },
        update: {
          update: {
            name: cr.name,
            url: cr.url,
            introduction: cr.introduction,
            revision_id: cr.revision_id,
            subcategories: scs,
            supercategories: pcs
          },
          user: {
            username: u.username,
            name: u.name,
            privilege_level: u.privilege_level,
            avatar_url: u.avatar_url
          },
          date: r.date
        }
      } AS category_revision
    """

    params = %{category_url: category_url, revision_id: revision_id}

    result = List.first Neo4j.query!(Neo4j.conn, query, params)

    if result["category_revision"]["category"]["name"] === nil do
      {:error, 404, "Category revision not found"}
    else
      {:ok, result}
    end
  end

  def fetch_update_patches_for(category_url) do
    query = """
      MATCH (c:Category {url: {category_url}})

      OPTIONAL MATCH (c)-[:UPDATE]->(ucp:UpdateCategoryPatch),
        (ucp)-[r:CONTRIBUTOR]->(u:User)

      RETURN {
        category: {
          name: c.name,
          url: c.url
        },
        updates: COLLECT(CASE ucp WHEN NULL THEN NULL ELSE {
          revision_id: ucp.revision_id,
          against_revision: ucp.against_revision,
          user: {
            username: u.username,
            name: u.name,
            privilege_level: u.privilege_level,
            avatar_url: u.avatar_url
          },
          date: r.date
        } END)
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

  def fetch_cache(category_url, "normal") do
    key = "categories/#{category_url}?normal"
    case ResultCache.get(key) do
      {:not_found} ->
        category = fetch(category_url, "normal")
        response = Phoenix.View.render_to_string(CategoryView, "show.json", category: category)
        ResultCache.set(key, response)
      {:found, response} -> response
    end
  end

  def fetch(category_url, "normal") do
    query = """
      MATCH (c:Category {url: {category_url}})

      OPTIONAL MATCH (c)-[:SUBCATEGORY]->(sc:Category)

      WITH c,
        COLLECT(
          CASE sc WHEN NULL THEN NULL ELSE {category: {name: sc.name, url: sc.url}} END
        ) AS scs

      OPTIONAL MATCH (pc:Category)-[:SUBCATEGORY]->(c)

      RETURN {
        name: c.name,
        url: c.url,
        introduction: c.introduction,
        revision_id: c.revision_id,
        subcategories: scs,
        supercategories: COLLECT(
          CASE pc WHEN NULL THEN NULL ELSE {category: {name: pc.name, url: pc.url}} END
        )
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
          revision_id: {rev_id},
          id: {id}
        }),
        (c)-[:CONTRIBUTOR {type: "insert", date: #{Utilities.get_date()}, time: timestamp()}]->(user)
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
        url: category["url"],
        rev_id: :rand.uniform(100_000_000),
        id: :rand.uniform(100_000_000),
        username: username
      })

    new_category = List.first Neo4j.query!(Neo4j.conn, query, params)

    if review === 1 do
      ""
    else
      update_cache_after_insert(category, new_category)
    end
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

      OPTIONAL MATCH (category)-[r3:SUBCATEGORY]->(subcat:Category)
      DELETE r3

      WITH category,
        user,
        category_revision,
        COLLECT(subcat.id) AS old_scs
        #{linked_categories_propagate}

      OPTIONAL MATCH (category)<-[r4:SUBCATEGORY]-(supercat:Category)
      DELETE r4

      WITH category,
        user,
        category_revision,
        old_scs,
        COLLECT(supercat.id) AS old_pcs
        #{linked_categories_propagate}

      OPTIONAL MATCH (category)-[r5:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision)
      DELETE r5

      WITH category,
        user,
        category_revision,
        old_scs,
        old_pcs,
        ucpr
        #{linked_categories_propagate}

      CREATE (old_category:CategoryRevision {
          name: category.name,
          introduction: category.introduction,
          url: category.url,
          revision_id: category.revision_id,
          id: category.id,
          subcategories: old_scs,
          supercategories: old_pcs
        }),
        (category)-[:REVISION]->(old_category)
        #{linked_categories_join}

      WITH category,
        old_category,
        user,
        category_revision,
        ucpr

      MATCH (category)-[r:CONTRIBUTOR]->(old_user:User)
      CREATE (old_category)-[:CONTRIBUTOR {type: r.type, date: r.date, time: r.time}]->(old_user)
      DELETE r

      WITH category,
        old_category,
        user,
        category_revision,
        ucpr,
        COLLECT(old_user) AS unused

      CREATE (category)-[:CONTRIBUTOR {type: "update", date: #{Utilities.get_date()}, time: timestamp()}]->(user)

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

    update_cache_after_update(old_category, new_category)

    fetch_cache(new_category["url"], "normal")
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
          id: category.id,
          against_revision: {against_rev}
        }),
        (category)-[:UPDATE]->(ucp),
        (ucp)-[:CONTRIBUTOR {type: "update", date: #{Utilities.get_date()}, time: timestamp()}]->(user)
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

    fetch_cache(old_category["url"], "normal")
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

      OPTIONAL MATCH (category)-[r4:SUBCATEGORY]->(subcat:Category)
      DELETE r4

      WITH category,
        user,
        cp,
        category_revision,
        COLLECT(subcat.id) AS old_scs
        #{linked_categories_propagate}

      OPTIONAL MATCH (category)<-[r5:SUBCATEGORY]-(supercat:Category)
      DELETE r5

      WITH category,
        user,
        cp,
        category_revision,
        old_scs,
        COLLECT(supercat.id) AS old_pcs
        #{linked_categories_propagate}

      OPTIONAL MATCH (cp)-[r6:SUBCATEGORY]->(subcat2:Category)
      DELETE r6

      WITH category,
        user,
        cp,
        category_revision,
        old_scs,
        old_pcs,
        COLLECT(subcat2.id) AS old_scs2
        #{linked_categories_propagate}

      OPTIONAL MATCH (cp)<-[r7:SUBCATEGORY]-(supercat2:Category)
      DELETE r7

      WITH category,
        user,
        cp,
        category_revision,
        old_scs,
        old_pcs,
        old_scs2,
        COLLECT(supercat2.id) AS old_pcs2
        #{linked_categories_propagate}

      OPTIONAL MATCH (category)-[r8:UPDATE_REVISION]->(ucpr:UpdateCategoryPatchRevision)
      DELETE r8

      WITH category,
        user,
        cp,
        category_revision,
        old_scs,
        old_pcs,
        old_scs2,
        old_pcs2,
        ucpr
        #{linked_categories_propagate}

      CREATE (old_category:CategoryRevision {
          name: category.name,
          introduction: category.introduction,
          url: category.url,
          revision_id: category.revision_id,
          id: category.id,
          subcategories: old_scs,
          supercategories: old_pcs
        }),
        (category)-[:UPDATE_REVISION]->(cp),
        (category)-[:REVISION]->(old_category)
        #{linked_categories_join}

      WITH category,
        user,
        cp,
        category_revision,
        old_scs2,
        old_pcs2,
        ucpr,
        old_category

      MATCH (category)-[r:CONTRIBUTOR]->(old_user:User)
      CREATE (old_category)-[:CONTRIBUTOR {type: r.type, date: r.date, time: r.time}]->(old_user)
      DELETE r

      WITH category,
        user,
        cp,
        category_revision,
        old_scs2,
        old_pcs2,
        ucpr,
        old_category,
        COLLECT(old_user) AS unused

      CREATE (category)-[:CONTRIBUTOR {type: "update", date: #{Utilities.get_date()}, time: timestamp()}]->(user)

      FOREACH (ignored IN CASE category_revision WHEN NULL THEN [] ELSE [1] END |
        CREATE (old_category)-[:REVISION]->(category_revision)
      )

      FOREACH (ignored IN CASE ucpr WHEN NULL THEN [] ELSE [1] END |
        CREATE (old_category)-[:UPDATE_REVISION]->(ucpr)
      )

      REMOVE cp:UpdateCategoryPatch
      SET cp:UpdateCategoryPatchRevision

      SET cp.subcategories = old_scs2,
        cp.supercategories = old_pcs2

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

    update_cache_after_update(old_category, new_category)

    fetch_cache(new_category["url"], "normal")
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
          id: category.id,
          against_revision: {against_rev}
        }),
        (category)-[:UPDATE]->(new_ucp),
        (new_ucp)-[:CONTRIBUTOR {type: "update", date: #{Utilities.get_date()}, time: timestamp()}]->(user),
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

    fetch_cache(old_category["url"], "normal")
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
    query = """
      MATCH (category:InsertCategoryPatch {url: {category_url}})

      OPTIONAL MATCH (spc:Category)-[:SUBCATEGORY]->(category)

      WITH COLLECT(spc.url) AS spcs, category

      OPTIONAL MATCH (category)-[:SUBCATEGORY]->(sbc:Category)

      RETURN {
        url: category.url,
        subcategories: COLLECT(sbc.url),
        supercategories: spcs
      } AS category
    """
    params = %{category_url: category_url, username: username}
    response = Neo4j.query!(Neo4j.conn, query, params)

    if response === [] do
      {:error, 404, "Insert patch not found"}
    else
      %{"category" => category} = List.first response
      query = "MATCH (c:Category {url: {category_url}}) RETURN c"

      if Neo4j.query!(Neo4j.conn, query, params) != [] do
        {:error, 400, "A category with the same name already exists"}
      else
        query = """
          MATCH (cp:InsertCategoryPatch {url: {category_url}}),
            (user:User {username: {username}})

          REMOVE cp:InsertCategoryPatch
          SET cp:Category

          CREATE (cp)-[:CONTRIBUTOR {type: "apply_insert", date: #{Utilities.get_date()}, time: timestamp()}]->(user)

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

        new_category = List.first Neo4j.query!(Neo4j.conn, query, params)

        {:ok, update_cache_after_insert(category, new_category)}
      end
    end
  end

  def apply_patch?(category_url, %{"action" => "update", "patch_revision_id" => patch_revision_id}, username) do
    query = """
      OPTIONAL MATCH (c:Category {url: {category_url}})

      OPTIONAL MATCH (spc:Category)-[:SUBCATEGORY]->(c)

      WITH COLLECT(spc.url) AS spcs, c

      OPTIONAL MATCH (c)-[:SUBCATEGORY]->(sbc:Category)

      WITH {
        name: c.name,
        url: c.url,
        revision_id: c.revision_id,
        subcategories: COLLECT(sbc.url),
        supercategories: spcs
      } AS category, c

      OPTIONAL MATCH (c)-[:UPDATE]->(ucp:UpdateCategoryPatch {revision_id: {patch_revision_id}})

      OPTIONAL MATCH (spc:Category)-[:SUBCATEGORY]->(ucp)

      WITH COLLECT(spc.url) AS spcs, ucp, category, c

      OPTIONAL MATCH (ucp)-[:SUBCATEGORY]->(sbc:Category)

      WITH {
        name: ucp.name,
        url: ucp.url,
        against_revision: ucp.against_revision,
        subcategories: COLLECT(sbc.url),
        supercategories: spcs
      } AS update_category_patch, ucp, category, c

      RETURN (CASE c WHEN NULL THEN NULL ELSE category END) AS c,
        (CASE ucp WHEN NULL THEN NULL ELSE update_category_patch END) AS ucp
    """

    params = %{patch_revision_id: patch_revision_id, category_url: category_url, username: username}

    category = List.first Neo4j.query!(Neo4j.conn, query, params)

    cond do
      category["c"] === nil -> {:error, 404, "Category not found"}
      category["ucp"] === nil -> {:error, 404, "Update patch not found for the specified category"}
      category["ucp"]["against_revision"] !== category["c"]["revision_id"] ->
        {:error, 400, "Cannot apply patch due to revision ID mismatch"}
      true ->
        with {:ok} <- Lock.has_lock?(patch_revision_id, username),
             {:ok} <- Lock.has_lock?(category["c"]["revision_id"], username) do
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

            OPTIONAL MATCH (category)-[r5:SUBCATEGORY]->(subcat:Category)
            DELETE r5

            WITH category,
              r2,
              ucp,
              user,
              new_user,
              category_revision,
              ucpr,
              COLLECT(subcat.id) AS old_scs

            OPTIONAL MATCH (category)<-[r6:SUBCATEGORY]-(supcat:Category)
            DELETE r6

            WITH category,
              r2,
              ucp,
              user,
              new_user,
              category_revision,
              ucpr,
              old_scs,
              COLLECT(supcat.id) AS old_pcs

            OPTIONAL MATCH (ucp)-[:SUBCATEGORY]->(sc:Category)

            WITH category,
              r2,
              ucp,
              user,
              new_user,
              category_revision,
              ucpr,
              old_scs,
              old_pcs,
              COLLECT(sc) AS scs

            OPTIONAL MATCH (ucp)<-[:SUBCATEGORY]-(pc:Category)

            WITH category,
              r2,
              ucp,
              user,
              new_user,
              category_revision,
              ucpr,
              old_scs,
              old_pcs,
              scs,
              COLLECT(pc) AS pcs

            CREATE (old_category:CategoryRevision {
                name: category.name,
                introduction: category.introduction,
                url: category.url,
                revision_id: category.revision_id,
                id: category.id,
                subcategories: old_scs,
                supercategories: old_pcs
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
            CREATE (old_category)-[:CONTRIBUTOR {type: r.type, date: r.date, time: r.time}]->(old_user)
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

            CREATE (category)-[:CONTRIBUTOR {type: "apply_update", date: #{Utilities.get_date()}, time: timestamp()}]->(new_user),
              (category)-[:CONTRIBUTOR {type: r2.type, date: r2.date, time: r2.time}]->(user)

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

          Neo4j.query!(Neo4j.conn, query, params)

          update_cache_after_update(category["c"], category["ucp"])

          {:ok, fetch_cache(category["ucp"]["url"], "normal")}
        else
          error -> error
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

    cond do
      category["c"] === nil -> {:error, 404, "Category not found"}
      category["cp"] === nil -> {:error, 404, "Delete patch not found for the specified category"}
      true ->
        with {:ok} <- Lock.has_lock?(category["c"]["revision_id"], username) do
          query = """
            MATCH (c:Category {url: {category_url}})<-[r:DELETE]-(user2:User),
              (user:User {username: {username}})

            REMOVE c:Category
            SET c:CategoryDeleted

            CREATE (c)-[:CONTRIBUTOR {type: "delete", date: #{Utilities.get_date()}, time: timestamp()}]->(user2),
              (c)-[:CONTRIBUTOR {type: "apply_delete", date: #{Utilities.get_date()}, time: timestamp()}]->(user)

            DELETE r

            WITH c

            OPTIONAL MATCH (spc:Category)-[:SUBCATEGORY]->(c)

            WITH COLLECT(spc.url) AS spcs, c

            OPTIONAL MATCH (c)-[:SUBCATEGORY]->(sbc:Category)

            RETURN {
              url: c.url,
              subcategories: COLLECT(sbc.url),
              supercategories: spcs
            } AS category
          """

          %{"category" => category} = List.first Neo4j.query!(Neo4j.conn, query, params)

          update_cache_after_delete(category)

          {:ok, 204}
        else
          error -> error
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
        CREATE (cp)-[:CONTRIBUTOR {type: "discard_insert", date: #{Utilities.get_date()}, time: timestamp()}]->(user)
      """

      Neo4j.query!(Neo4j.conn, query, params)

      ResultCache.invalidate_contributions()

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

    cond do
      category["c"] === nil -> {:error, 404, "Category not found"}
      category["cp"] === nil -> {:error, 404, "Update patch not found for the specified category"}
      true ->
        with {:ok} <- Lock.has_lock?(patch_revision_id, username) do
          query = """
            MATCH (c:Category {url: {category_url}}),
              (user:User {username: {username}}),
              (c)-[:UPDATE]->(cp:UpdateCategoryPatch {revision_id: {patch_revision_id}})
            REMOVE cp:UpdateCategoryPatch
            SET cp:UpdateCategoryPatchDeleted
            CREATE (cp)-[:CONTRIBUTOR {type: "discard_update", date: #{Utilities.get_date()}, time: timestamp()}]->(user)
          """

          Neo4j.query!(Neo4j.conn, query, params)

          ResultCache.invalidate_contributions()

          {:ok, 200}
        else
          error -> error
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
          MERGE (c)-[:CONTRIBUTOR {type: "discard_delete", date: #{Utilities.get_date()}, time: timestamp()}]->(user)
        """

        Neo4j.query!(Neo4j.conn, query, params)

        ResultCache.invalidate_contributions()

        {:ok, 200}
      end
    end
  end

  def soft_delete(category, 0, username) do
    query = """
      MATCH (c:Category {url: {url}}),
        (user:User {username: {username}})
      REMOVE c:Category
      SET c:CategoryDeleted
      CREATE (c)-[:CONTRIBUTOR {type: "delete", date: #{Utilities.get_date()}, time: timestamp()}]->(user)
    """

    params = %{url: category["url"], username: username}

    Neo4j.query!(Neo4j.conn, query, params)

    update_cache_after_delete(category)
  end

  def soft_delete(category, _review = 1, username) do
    query = """
      MATCH (c:Category {url: {url}}),
        (user:User {username: {username}})
      CREATE (c)<-[:DELETE]-(user)
    """

    params = %{url: category["url"], username: username}

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

      CREATE (s)-[:CONTRIBUTOR {type: "undo_delete", date: #{Utilities.get_date()}, time: timestamp()}]->(u)
    """

    params = %{url: category_url, username: username}

    Neo4j.query!(Neo4j.conn, query, params)
  end

  # cache invalidation functions here

  def update_cache_after_insert(category, new_category) do
    key = "categories/#{category["url"]}?normal"
    new_category = ResultCache.set(key, Phoenix.View.render_to_string(CategoryView, "show.json", category: new_category))
    ResultCache.flush("categories")
    ResultCache.invalidate_contributions()

    for category_url <- (category["subcategories"] || []) ++ (category["supercategories"] || []) do
      ResultCache.invalidate("categories/#{category_url}?normal")
    end

    new_category
  end

  def update_cache_after_update(old_category, new_category) do
    ResultCache.invalidate("categories/#{old_category["url"]}?overview")
    ResultCache.invalidate("categories/#{old_category["url"]}?normal")

    category_diff =
      ((new_category["subcategories"] || []) -- old_category["subcategories"]) ++
      (old_category["subcategories"] -- (new_category["subcategories"] || [])) ++
      ((new_category["supercategories"] || []) -- old_category["supercategories"]) ++
      (old_category["supercategories"] -- (new_category["supercategories"] || []))

    if old_category["name"] !== new_category["name"] or category_diff !== [] do
      ResultCache.flush("categories")
    end

    for category_url <- category_diff do
      ResultCache.invalidate("categories/#{category_url}?normal")
    end

    ResultCache.invalidate_contributions()
  end

  def update_cache_after_delete(category) do
    ResultCache.invalidate("categories/#{category["url"]}?overview")
    ResultCache.invalidate("categories/#{category["url"]}?normal")
    ResultCache.flush("categories")
    ResultCache.invalidate_contributions()

    for category_url <- category["subcategories"] ++ category["supercategories"] do
      ResultCache.invalidate("categories/#{category_url}?normal")
    end
  end
end
