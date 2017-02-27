defmodule PhpInternals.Utilities do
  @default_result_limit 20
  @max_result_limit 100
  @default_ordering "ASC"

  def is_url_friendly?(name) do
    if String.length(name) < 50 do
      {:ok, String.downcase(String.replace(name, " ", "_"))}
    else
      {:error, 400, "Bad URL-friendly name"}
    end
  end

  def valid_review_param?(review) do
    cond do
      review in ["0", "1"] -> {:ok, String.to_integer(review)}
      true -> {:error, 400, "Unknown review param"}
    end
  end

  def valid_patch_action?(action) do
    case Regex.named_captures(~r/\A(?<type>insert|delete|update,[0-9]{1,10})\z/, action) do
      %{"type" => _type} -> {:ok}
      _ -> {:error, 400, "Unknown patch action"}
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
end
