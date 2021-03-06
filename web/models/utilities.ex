defmodule PhpInternals.Utilities do
  use PhpInternals.Web, :model
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Settings.Setting

  @default_result_limit 20
  @max_result_limit 100
  @default_ordering "ASC"

  def is_url_friendly_opt?(nil), do: {:ok, ""}
  def is_url_friendly_opt?(""), do: {:ok, ""}

  def is_url_friendly_opt?(name) do
    is_url_friendly?(name)
  end

  def is_url_friendly?(name) do
    with true <- String.length(name) < 70,
         new_name <- make_url_friendly(name),
         true <- String.length(new_name) > 0 do
      {:ok, new_name}
    else
      _ ->
        {:error, 400, "Bad URL-friendly name"}
    end
  end

  def make_url_friendly(name) do
    name
    |> String.trim
    |> String.replace(~r/([^a-zA-Z0-9 ._-])/, "")
    |> String.replace(" ", "_")
    |> String.downcase
  end

  def valid_review_param?(review) do
    cond do
      review in ["0", "1"] -> {:ok, String.to_integer(review)}
      review in [0, 1] -> {:ok, review}
      true -> {:error, 400, "Unknown review param"}
    end
  end

  def valid_patch_action?(action) do
    case Regex.named_captures(~r/\A(?<type>insert|delete|update,[0-9]{1,10})\z/, action) do
      %{"type" => type} ->
        if type in ["insert", "delete"] do
          {:ok, %{"action" => type}}
        else
          [update, for_revision] = String.split(type, ",")
          {:ok, %{"action" => update, "patch_revision_id" => String.to_integer(for_revision)}}
        end
      _ -> {:error, 400, "Unknown patch action"}
    end
  end

  def valid_patch_type?(type) do
    if type in ["all", "insert", "update", "delete"] do
      {:ok}
    else
      {:error, 400, "Unknown patch type"}
    end
  end

  def valid_limit?(limit) do
    if limit === nil do
      {:ok, @default_result_limit}
    else
      limit = String.to_integer(limit)

      if limit < 1 or limit > @max_result_limit do
        {:error, 400, "The limit should be between 1 and #{@max_result_limit} (inclusive)"}
      else
        {:ok, limit}
      end
    end
  end

  def valid_offset?(offset) do
    if offset === nil, do: {:ok, 0}, else: {:ok, String.to_integer(offset)}
  end

  def valid_ordering?(ordering) do
    if ordering === nil do
      {:ok, @default_ordering}
    else
      if Enum.member?(["ASC", "DESC"], String.upcase(ordering)) do
        {:ok, ordering}
      else
        {:error, 400, "Unknown ordering used"}
      end
    end
  end

  def valid_id?(id) do
    case Integer.parse(id) do
      {int_id, ""} -> {:ok, int_id}
      _ -> {:error, 400, "Invalid integer ID given"}
    end
  end

  def valid_revision_id?(revision_id) do
    query = """
      MATCH (node {revision_id: {revision_id}})
      RETURN node
    """

    params = %{revision_id: revision_id}

    case List.first Neo4j.query!(Neo4j.conn, query, params) do
      nil -> {:error, 404, "Invalid revision ID"}
      _result -> {:ok}
    end
  end

  def valid_optional_id?(id) do
    if id === nil, do: {:ok, id}, else: valid_id?(id)
  end

  def revision_ids_match?(id1, id2) do
    if id1 === id2, do: {:ok}, else: {:error, 400, "Revision ID mismatch"}
  end

  def get_date() do
    {{year, month, day}, _} = :calendar.now_to_datetime(:os.timestamp)

    month = String.pad_leading(Integer.to_string(month), 2, "0")
    day = String.pad_leading(Integer.to_string(day), 2, "0")

    {date, _} = Integer.parse("#{year}#{month}#{day}")

    date
  end

  def set_cache_control_header(conn) do
    cc_header = Enum.find(conn.req_headers, nil, fn {header, _value} ->
      header === "cache-control"
    end)

    case cc_header do
      nil -> put_resp_header(conn, "cache-control", "max-age=#{Setting.get("cache_expiration_time")}, public")
      {_header, value} -> put_resp_header(conn, "cache-control", value)
    end
  end
end
