defmodule AshEdtf.Value do
  @moduledoc """
  A cast EDTF value: the original EDTF string plus the date range it covers.

  Only `AshEdtf.Type` builds this struct, so `lower`/`upper` always agree with
  `value`: a side's date is set exactly when its bound is `:closed`.

  `to_string/1` and HTML rendering return the EDTF string, so a value can be
  used directly as a form input value.
  """

  @enforce_keys [:value, :lower_bound, :upper_bound]
  defstruct [:value, :lower, :upper, :lower_bound, :upper_bound]

  @type bound :: :closed | :open | :unknown

  @type t :: %__MODULE__{
          value: String.t(),
          lower: Date.t() | nil,
          upper: Date.t() | nil,
          lower_bound: bound(),
          upper_bound: bound()
        }

  defimpl String.Chars do
    def to_string(%{value: value}), do: value
  end

  if Code.ensure_loaded?(Phoenix.HTML.Safe) do
    defimpl Phoenix.HTML.Safe do
      alias Phoenix.HTML.Engine

      def to_iodata(%{value: value}), do: Engine.html_escape(value)
    end
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      def encode(%{value: value}, opts), do: Jason.Encode.string(value, opts)
    end
  end
end
