defmodule SimpleXml.XmlNode do
  @moduledoc """
  A simplistic XML node representation that uses the saxy lib, in order to avoid xmerl based
  libraries, which have the vulnerability that they create new atoms for each tag within the XML
  document.

  For simplicity, this module ignores namespaces within the document.
  """

  @type xml_attribute :: SimpleXml.xml_attribute()
  @type xml_node :: SimpleXml.xml_node()

  @doc """
  Obtains value for the given attribute.

  ## Examples

  ### Obtains the value for an attribute

      iex> {:ok, node} = SimpleXml.parse(~S'<foo a="1" b="2"></foo>')
      iex> SimpleXml.XmlNode.attribute(node, "a")
      {:ok, "1"}

  ### Returns the first matching attribute it finds

      iex> {:ok, node} = SimpleXml.parse(~S'<foo a="1" a="2"></foo>')
      iex> SimpleXml.XmlNode.attribute(node, "a")
      {:ok, "1"}

  ### Generates an error when the attribute is missing

      iex> {:ok, node} = SimpleXml.parse(~S'<foo a="1" b="2"></foo>')
      iex> SimpleXml.XmlNode.attribute(node, "c")
      {:error, {:attribute_not_found, "c"}}
  """
  @spec attribute(xml_node(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def attribute({_node, [], _children}, attr_name),
    do: {:error, {:attribute_not_found, attr_name}}

  def attribute({_node, attrs, _children}, attr_name) when is_list(attrs) do
    attrs
    |> Enum.find(fn
      {^attr_name, _value} -> true
      _ -> false
    end)
    |> case do
      nil -> {:error, {:attribute_not_found, attr_name}}
      {_attr_name, value} -> {:ok, value}
    end
  end

  @doc """
  Obtains the first direct child of the given node with the given string tag name via
  case-insensitive match.

  Use a `*:` prefix for the tag name to ignore namespace associated with the tag name.

  Alternatively, you can supply a regex to pattern match the child name.  When Regex is supplied the
  Regex's case sensitivity is respected.

  ## Examples

  ### Obtains the first child by the given name

      iex> {:ok, node} = SimpleXml.parse(~S'<foo><bar>1</bar><baz>2</baz></foo>')
      iex> SimpleXml.XmlNode.first_child(node, "bar")
      {:ok, {"bar", [], ["1"]}}

  ### Returns the first matching node it finds

      iex> {:ok, node} = SimpleXml.parse(~S'<foo><bar>1</bar><bar>2</bar></foo>')
      iex> SimpleXml.XmlNode.first_child(node, "bar")
      {:ok, {"bar", [], ["1"]}}

  ### Ignores case when matching tag name

      iex> {:ok, node} = SimpleXml.parse(~S'<foo><bar>1</bar><bar>2</bar></foo>')
      iex> SimpleXml.XmlNode.first_child(node, "BAR")
      {:ok, {"bar", [], ["1"]}}

  ### Wildcard ignores tag namespace

      iex> {:ok, node} = SimpleXml.parse(~S'<ns:foo><xs:bar>1</xs:bar><xs:bar>2</xs:bar></ns:foo>')
      iex> SimpleXml.XmlNode.first_child(node, "*:Bar")
      {:ok, {"xs:bar", [], ["1"]}}

  ### Use Regex to find a child

      iex> {:ok, node} = SimpleXml.parse(~S'<ns:foo><xs:bar>1</xs:bar><xs:bar>2</xs:bar></ns:foo>')
      iex> SimpleXml.XmlNode.first_child(node, ~r/.*:BAR/i)
      {:ok, {"xs:bar", [], ["1"]}}

  ### Generates an error when there's no child with the given name

      iex> {:ok, node} = SimpleXml.parse(~S'<foo><bar>1</bar></foo>')
      iex> SimpleXml.XmlNode.first_child(node, "baz")
      {:error, {:child_not_found, [child_name: "baz", actual_children: [{"bar", [], ["1"]}]]}}

  ### Generates an error when there no children

      iex> {:ok, node} = SimpleXml.parse(~S'<foo></foo>')
      iex> SimpleXml.XmlNode.first_child(node, "baz")
      {:error, {:child_not_found, [child_name: "baz", actual_children: []]}}
  """
  @spec first_child(xml_node(), String.t() | Regex.t()) :: {:ok, xml_node()} | {:error, any()}
  def first_child({_node, _attrs, [] = children}, child_name),
    do: {:error, {:child_not_found, [child_name: child_name, actual_children: children]}}

  def first_child({_node, _attrs, children} = _xml_node, child_name)
      when is_list(children) and (is_binary(child_name) or is_struct(child_name)) do
    children
    |> Enum.find(&name_matches?(&1, child_name))
    |> case do
      nil -> {:error, {:child_not_found, [child_name: child_name, actual_children: children]}}
      result -> {:ok, result}
    end
  end

  @doc """
  Returns the children of the given node.  To get a filtered list of children, see `children/2`.

  ## Examples

  ### Returns all children

      iex> {:ok, node} = SimpleXml.parse(~S'<foo><bar>1</bar><baz>2</baz></foo>')
      iex> SimpleXml.XmlNode.children(node)
      {:ok, [{"bar", [], ["1"]}, {"baz", [], ["2"]}]}

  ### Returns an error if the node doesn't contain a child

      iex> {:ok, node} = SimpleXml.parse(~S'<foo>bar</foo>')
      iex> SimpleXml.XmlNode.children(node)
      {:error, {:no_children_found, ["bar"]}}

  """
  @spec children(xml_node()) :: {:ok, [String.t() | xml_node()]}
  def children({_node, _attrs, [head | _tail] = children}) when is_binary(head),
    do: {:error, {:no_children_found, children}}

  def children({_node, _attrs, children}) when is_list(children), do: {:ok, children}

  @doc """
  Returns all children that match the given child_name filter.  Filtering matches that of
  `first_child/2`.  A string child tag name or a regex can be supplied for filtering.

  ## Examples

  ### Returns all children by a given string name

      iex> {:ok, node} = SimpleXml.parse(~S'<foo><bar>1</bar><baz>2</baz></foo>')
      iex> SimpleXml.XmlNode.children(node, "bar")
      [{"bar", [], ["1"]}]


  ### Returns all children by a given Regex

      iex> {:ok, node} = SimpleXml.parse(~S'<foo><bar>1</bar><baz>2</baz></foo>')
      iex> SimpleXml.XmlNode.children(node, ~r/BA/i)
      [{"bar", [], ["1"]}, {"baz", [], ["2"]}]

  ### Returns an empty list, if there are no children

      iex> {:ok, node} = SimpleXml.parse(~S'<foo>bar</foo>')
      iex> SimpleXml.XmlNode.children(node, "bar")
      []
  """
  @spec children(xml_node(), String.t() | Regex.t()) :: [xml_node()]
  def children({_node, _attrs, children} = _xml_node, child_name)
      when is_list(children) and (is_binary(child_name) or is_struct(child_name)) do
    children
    |> Enum.filter(&name_matches?(&1, child_name))
  end

  @doc """
  Removes all children that match the given name.  Semantics of the child_name parameter follow
  those of the `first_child/1` function.

  ## Exmaples

  ### All matching children are removed based on a string child name

      iex> {:ok, node} = SimpleXml.parse(~S'<ns:foo><xs:bar>1</xs:bar><xs:bar>2</xs:bar></ns:foo>')
      iex> SimpleXml.XmlNode.drop_children(node, "*:Bar")
      {"ns:foo", [], []}

  ### All matching children are removed based on a Regex child name

      iex> {:ok, node} = SimpleXml.parse(~S'<ns:foo><xs:bar>1</xs:bar><xs:BAR>2</xs:BAR></ns:foo>')
      iex> SimpleXml.XmlNode.drop_children(node, ~r/bar/)
      {"ns:foo", [], [{"xs:BAR", [], ["2"]}]}
  """
  @spec drop_children(xml_node(), String.t() | Regex.t()) :: xml_node()
  def drop_children({node, attrs, children}, child_name)
      when is_list(children) and (is_binary(child_name) or is_struct(child_name)) do
    children
    |> Enum.reject(&name_matches?(&1, child_name))
    |> then(&{node, attrs, &1})
  end

  @doc """
  Obtains text within the body of a tag.

  ## Examples

  ### Obtains the text contents of a tag

      iex> {:ok, node} = SimpleXml.parse(~S'<foo>bar</foo>')
      iex> SimpleXml.XmlNode.text(node)
      {:ok, "bar"}

  ### Generates an error when the tag contains no text

      iex> {:ok, node} = SimpleXml.parse(~S'<foo><bar>1</bar></foo>')
      iex> SimpleXml.XmlNode.text(node)
      {:error, {:text_not_found, [{"bar", [], ["1"]}]}}
  """
  @spec text(xml_node()) :: {:ok, String.t()} | {:error, any()}
  def text({_node, _attrs, [head | _tail]} = _xml_node) when is_binary(head), do: {:ok, head}
  def text({_node, _attrs, children} = _xml_node), do: {:error, {:text_not_found, children}}

  @doc """
  Exports the given node, its attributes, and its decendents into an XML string.

  ## Examples

  ### XML can be exported to string

      iex> input = ~S'<foo>bar</foo>'
      iex> {:ok, node} = SimpleXml.parse(input)
      iex> SimpleXml.XmlNode.to_string(node) == input
      true

  ### Case is preserved for tag names and attributes

      iex> input = ~S'<Foo A="1"><BAR>b</BAR></Foo>'
      iex> {:ok, node} = SimpleXml.parse(input)
      iex> SimpleXml.XmlNode.to_string(node) == input
      true

  ### Attribute order is preserved

      iex> input = ~S'<foo b="b" a="a"><bar d="d" c="c">1</bar></foo>'
      iex> {:ok, node} = SimpleXml.parse(input)
      iex> SimpleXml.XmlNode.to_string(node) == input
      true
  """
  @spec to_string(String.t() | xml_node() | [xml_node()] | [xml_attribute()]) :: String.t()
  def to_string(text) when is_binary(text), do: text

  def to_string(text_attrs_or_children) when is_list(text_attrs_or_children) do
    text_attrs_or_children
    |> Enum.reduce("", fn
      [], acc ->
        acc

      text, acc when is_binary(text) ->
        "#{acc}#{text}"

      {key, value} = _attrs, "" ->
        ~s[#{key}="#{value}"]

      {key, value} = _attrs, acc ->
        ~s[#{acc} #{key}="#{value}"]

      {tag_name, _attrs, children} = node, acc when is_binary(tag_name) and is_list(children) ->
        ~s[#{acc}#{__MODULE__.to_string(node)}]
    end)
  end

  def to_string({tag_name, [], children}) when is_binary(tag_name) and is_list(children) do
    ~s(<#{tag_name}>#{__MODULE__.to_string(children)}</#{tag_name}>)
  end

  def to_string({tag_name, attrs, children})
      when is_binary(tag_name) and is_list(attrs) and is_list(children) do
    ~s(<#{tag_name} #{__MODULE__.to_string(attrs)}>#{__MODULE__.to_string(children)}</#{tag_name}>)
  end

  @spec name_matches?(xml_node(), String.t() | Regex.t()) :: boolean()
  defp name_matches?({tag_name, _, _}, tag_name) when is_binary(tag_name), do: true

  defp name_matches?({tag_name, _, _}, "*:" <> child_name)
       when is_binary(tag_name) and is_binary(child_name) do
    tag_name
    |> String.downcase()
    |> String.ends_with?(":#{String.downcase(child_name)}")
  end

  defp name_matches?({tag_name, _, _}, name) when is_binary(tag_name) and is_binary(name),
    do: String.downcase(tag_name) == String.downcase(name)

  defp name_matches?({tag_name, _, _}, %Regex{} = name) when is_binary(tag_name),
    do: Regex.match?(name, tag_name)

  defp name_matches?(_tag, _child_name), do: false
end
