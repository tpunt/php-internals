defmodule PhpInternals.Api.Categories.Category do
  use PhpInternals.Web, :model

  @required_fields ["name", "introduction"]
  @optional_fields []

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
      if is_binary(category[key]), do: {:ok}, else: {:error, "The #{key} field should be a string"}
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

  def validate_values(category) do
    validated = Enum.map(Map.keys(category), fn key ->
      validate_field(key, String.trim(category[key]))
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

  def fetch_all(order_by, ordering, offset, limit, search_term, full_search) do
    {where_query, search_term} =
      if search_term !== nil do
        where_query = "WHERE c."

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

        {where_query <> column <> " =~ {search_term}", search_term}
      else
        {"", nil}
      end

    query = """
      MATCH (c:Category)
      #{where_query}
      RETURN {name: c.name, url: c.url} AS category
      ORDER BY c.#{order_by} #{ordering}
      SKIP #{offset}
      LIMIT #{limit}
    """

    params = %{search_term: search_term}

    Neo4j.query!(Neo4j.conn, query, params)
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
      RETURN {
        category: c,
        update: {
          update: ucp,
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

  def fetch(category_url, "full") do
    query = """
      MATCH (c:Category {url: {category_url}})
      OPTIONAL MATCH (s:Symbol)-[:CATEGORY]->(c)
      OPTIONAL MATCH (a:Article)-[:CATEGORY]->(c), (a)-[:AUTHOR]->(u:User)
      WITH c, a, u, collect(
        CASE s WHEN NULL THEN NULL ELSE {symbol: {name: s.name, url: s.url, type: s.type, id: s.id}}
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

  def insert(category, 0, username) do
    query = """
      MATCH (user:User {username: {username}})
      CREATE (category:Category {name: {name}, introduction: {introduction}, url: {url}, revision_id: {rev_id}}),
        (category)-[:CONTRIBUTOR {type: "insert", date: timestamp()}]->(user)
      RETURN category
    """

    params = %{name: category["name"],
      introduction: category["introduction"],
      url: category["url_name"],
      rev_id: :rand.uniform(100_000_000),
      username: username}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def insert(category, _review = 1, username) do
    query = """
      MATCH (user:User {username: {username}})
      CREATE (category:InsertCategoryPatch {name: {name}, introduction: {introduction}, url: {url}, revision_id: {rev_id}}),
        (category)-[:CONTRIBUTOR {type: "insert", date: timestamp()}]->(user)
      RETURN category
    """

    params = %{name: category["name"],
      introduction: category["introduction"],
      url: category["url_name"],
      rev_id: :rand.uniform(100_000_000),
      username: username}

    List.first Neo4j.query!(Neo4j.conn, query, params)
  end

  def update(old_category, new_category, 0 = _review, username, nil = _patch_revision_id) do
    query = """
      MATCH (old_category:Category {url: {old_url}}),
        (user:User {username: {username}})

      CREATE (new_category:Category {
          name: {new_name},
          introduction: {new_introduction},
          url: {new_url},
          revision_id: {new_rev_id}
        }),
        (new_category)-[:REVISION]->(old_category),
        (new_category)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user)

      WITH old_category, user, new_category

      OPTIONAL MATCH (old_category)-[r1:UPDATE]->(ucp:UpdateCategoryPatch)
      OPTIONAL MATCH (old_category)<-[r2:DELETE]-(user2:User)
      OPTIONAL MATCH (n)-[r3:CATEGORY]->(old_category)

      REMOVE old_category:Category
      SET old_category:CategoryRevision

      DELETE r1, r2, r3

      WITH new_category, COLLECT(ucp) AS ucps, user2, COLLECT(n) AS ns

      FOREACH (ucp IN ucps |
        MERGE (new_category)-[:UPDATE]->(ucp)
      )

      FOREACH (ignored IN CASE user2 WHEN NULL THEN [] ELSE [1] END |
        MERGE (new_category)<-[:DELETE]-(user2)
      )

      FOREACH (n IN ns |
        MERGE (n)-[:CATEGORY]->(new_category)
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

  def update(old_category, new_category, 1 = _review, username, nil = _patch_revision_id) do
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
        (ucp)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user)
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

  def update(old_category, new_category, 0 = _review, username, patch_revision_id) do
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
          (new_category)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user)

        REMOVE old_category:Category
        SET old_category:CategoryRevision

        REMOVE cp:UpdateCategoryPatch
        SET cp:UpdateCategoryPatchRevision

        DELETE r1

        WITH old_category, new_category, user

        OPTIONAL MATCH (n)-[r2:CATEGORY]->(old_category)
        OPTIONAL MATCH (old_category)-[r3:UPDATE]->(ucp:UpdateCategoryPatch)
        OPTIONAL MATCH (old_category)<-[r4:DELETE]-(user2:User)

        DELETE r2, r3, r4

        WITH new_category, COLLECT(n) AS ns, COLLECT(ucp) AS ucps, user2

        FOREACH (n IN ns |
          MERGE (n)-[:CATEGORY]->(new_category)
        )

        FOREACH (ucp IN ucps |
          MERGE (new_category)-[:UPDATE]->(ucp)
        )

        FOREACH (ignored IN CASE user2 WHEN NULL THEN [] ELSE [1] END |
          MERGE (new_category)-[:DELETE]->(user2)
        )

        return new_category as category
      """

      {:ok, 200, List.first Neo4j.query!(Neo4j.conn, query, params)}
    end
  end

  def update(old_category, new_category, 1 = _review, username, patch_revision_id) do
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
          (new_ucp)-[:CONTRIBUTOR {type: "update", date: timestamp()}]->(user),
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
          RETURN cp as category
        """

        {:ok, Neo4j.query!(Neo4j.conn, query, params) |> List.first}
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
              (new_category)-[:CONTRIBUTOR {type: "apply_update", date: timestamp()}]->(user)

            REMOVE new_category:UpdateCategoryPatch
            SET new_category:Category

            REMOVE old_category:Category
            SET old_category:CategoryRevision

            DELETE r1

            WITH old_category, new_category

            OPTIONAL MATCH (n)-[r2:CATEGORY]->(old_category)
            OPTIONAL MATCH (old_category)-[r3:UPDATE]->(ucp:UpdateCategoryPatch)
            OPTIONAL MATCH (old_category)<-[r4:DELETE]-(user2:User)

            DELETE r2, r3, r4

            WITH new_category, COLLECT(n) AS ns, COLLECT(ucp) AS ucps, user2

            FOREACH (n IN ns |
              MERGE (n)-[:CATEGORY]->(new_category)
            )

            FOREACH (ucp IN ucps |
              MERGE (new_category)-[:UPDATE]->(ucp)
            )

            FOREACH (ignored IN CASE user2 WHEN NULL THEN [] ELSE [1] END |
              MERGE (new_category)<-[:DELETE]-(user2)
            )

            RETURN new_category as category
          """

          {:ok, List.first Neo4j.query!(Neo4j.conn, query, params)}
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
