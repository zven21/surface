defmodule Surface.API do
  @moduledoc false

  alias Surface.IOHelper

  @types [
    :any,
    :css_class,
    :list,
    :event,
    :boolean,
    :string,
    :date,
    :datetime,
    :number,
    :integer,
    :decimal,
    :map,
    :fun,
    :atom,
    :module,
    :changeset,
    :form,
    :keyword,
    # Private
    :generator,
    :context_put,
    :context_get
  ]

  @private_opts [:action, :to]

  defmacro __using__(include: include) do
    arities = %{
      prop: [2, 3],
      slot: [1, 2],
      data: [2, 3]
    }

    functions = for func <- include, arity <- arities[func], into: [], do: {func, arity}

    quote do
      import unquote(__MODULE__), only: unquote(functions)
      @before_compile unquote(__MODULE__)
      @after_compile unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :assigns, accumulate: false)
      # Any caller component can hold other components with slots
      Module.register_attribute(__MODULE__, :assigned_slots_by_parent, accumulate: false)

      Module.put_attribute(__MODULE__, :use_context?, false)

      for func <- unquote(include) do
        Module.register_attribute(__MODULE__, func, accumulate: true)
        unquote(__MODULE__).init_func(func, __MODULE__)
      end
    end
  end

  defmacro __before_compile__(env) do
    generate_docs(env)

    [
      quoted_prop_funcs(env),
      quoted_slot_funcs(env),
      quoted_data_funcs(env),
      quoted_context_funcs(env)
    ]
  end

  def __after_compile__(env, _) do
    if function_exported?(env.module, :__slots__, 0) do
      validate_slot_props_bindings!(env)
    end
  end

  @doc false
  def init_func(:slot, module) do
    Module.register_attribute(module, :used_slot, accumulate: true)
    :ok
  end

  def init_func(_func, _caller) do
    :ok
  end

  @doc "Defines a property for the component"
  defmacro prop(name_ast, type_ast, opts_ast \\ []) do
    build_assign_ast(:prop, name_ast, type_ast, opts_ast, __CALLER__)
  end

  @doc "Defines a slot for the component"
  defmacro slot(name_ast, opts_ast \\ []) do
    build_assign_ast(:slot, name_ast, :any, opts_ast, __CALLER__)
  end

  @doc "Defines a data assign for the component"
  defmacro data(name_ast, type_ast, opts_ast \\ []) do
    build_assign_ast(:data, name_ast, type_ast, opts_ast, __CALLER__)
  end

  @doc false
  def put_assign!(caller, func, name, type, opts, opts_ast, line) do
    Surface.API.validate!(func, name, type, opts, caller)

    assign = %{
      func: func,
      name: name,
      type: type,
      doc: pop_doc(caller.module),
      opts: opts,
      opts_ast: opts_ast,
      line: line
    }

    assigns = Module.get_attribute(caller.module, :assigns) || %{}
    name = Keyword.get(assign.opts, :as, assign.name)
    existing_assign = assigns[name]

    if existing_assign do
      message = """
      cannot use name \"#{assign.name}\". There's already \
      a #{existing_assign.func} assign with the same name \
      at line #{existing_assign.line}.\
      """

      IOHelper.compile_error(message, caller.file, assign.line)
    else
      assigns = Map.put(assigns, name, assign)
      Module.put_attribute(caller.module, :assigns, assigns)
    end

    Module.put_attribute(caller.module, assign.func, assign)
  end

  @doc false
  def get_assigns(module) do
    if Module.open?(module) do
      module
      |> Module.get_attribute(:assigns)
      |> Kernel.||(%{})
      |> Enum.map(fn {name, %{line: line}} -> {name, line} end)
    else
      data = if function_exported?(module, :__data__, 0), do: module.__data__(), else: []
      props = if function_exported?(module, :__props__, 0), do: module.__props__(), else: []
      slots = if function_exported?(module, :__slots__, 0), do: module.__slots__(), else: []

      Enum.map(data ++ props ++ slots, fn %{name: name, line: line} -> {name, line} end)
    end
  end

  @doc false
  def get_slots(module) do
    used_slots =
      for %{name: name, line: line} <- Module.get_attribute(module, :used_slot) || [] do
        %{func: :slot, name: name, type: :any, doc: nil, opts: [], opts_ast: [], line: line}
      end

    (Module.get_attribute(module, :slot) || []) ++ used_slots
  end

  @doc false
  def get_defaults(module) do
    for %{name: name, opts: opts} <- Module.get_attribute(module, :data),
        Keyword.has_key?(opts, :default) do
      {name, opts[:default]}
    end
  end

  defp quoted_data_funcs(env) do
    data = Module.get_attribute(env.module, :data) || []

    quote do
      @doc false
      def __data__() do
        unquote(Macro.escape(data))
      end
    end
  end

  defp quoted_prop_funcs(env) do
    props =
      (Module.get_attribute(env.module, :prop) || [])
      |> Enum.sort_by(&{&1.name != :id, !&1.opts[:required], &1.line})

    props_names = Enum.map(props, fn prop -> prop.name end)
    props_by_name = for p <- props, into: %{}, do: {p.name, p}

    quote do
      @doc false
      def __props__() do
        unquote(Macro.escape(props))
      end

      @doc false
      def __validate_prop__(prop) do
        prop in unquote(props_names)
      end

      @doc false
      def __get_prop__(name) do
        Map.get(unquote(Macro.escape(props_by_name)), name)
      end
    end
  end

  defp quoted_slot_funcs(env) do
    slots = env.module |> get_slots() |> Enum.uniq_by(& &1.name)
    slots_names = Enum.map(slots, fn slot -> slot.name end)
    slots_by_name = for p <- slots, into: %{}, do: {p.name, p}

    required_slots_names =
      for %{name: name, opts: opts} <- slots, opts[:required] do
        name
      end

    assigned_slots_by_parent = Module.get_attribute(env.module, :assigned_slots_by_parent) || %{}

    quote do
      @doc false
      def __slots__() do
        unquote(Macro.escape(slots))
      end

      @doc false
      def __validate_slot__(prop) do
        prop in unquote(slots_names)
      end

      @doc false
      def __get_slot__(name) do
        Map.get(unquote(Macro.escape(slots_by_name)), name)
      end

      @doc false
      def __assigned_slots_by_parent__() do
        unquote(Macro.escape(assigned_slots_by_parent))
      end

      @doc false
      def __required_slots_names__() do
        unquote(Macro.escape(required_slots_names))
      end
    end
  end

  defp quoted_context_funcs(env) do
    use_context? = Module.get_attribute(env.module, :use_context?)

    quote do
      @doc false
      def __use_context__?() do
        unquote(use_context?)
      end
    end
  end

  def validate!(func, name, type, opts, caller) do
    with :ok <- validate_type(func, name, type),
         :ok <- validate_opts_keys(func, name, type, opts),
         :ok <- validate_opts(func, type, opts),
         :ok <- validate_required_opts(func, type, opts) do
      :ok
    else
      {:error, message} ->
        file = Path.relative_to_cwd(caller.file)
        IOHelper.compile_error(message, file, caller.line)
    end
  end

  defp validate_name_ast!(_func, {name, meta, context}, _caller)
       when is_atom(name) and is_list(meta) and is_atom(context) do
    name
  end

  defp validate_name_ast!(func, name_ast, caller) do
    message = """
    invalid #{func} name. Expected a variable name, got: #{Macro.to_string(name_ast)}\
    """

    IOHelper.compile_error(message, caller.file, caller.line)
  end

  defp validate_type(_func, _name, type) when type in @types do
    :ok
  end

  defp validate_type(func, name, type) do
    message = """
    invalid type #{Macro.to_string(type)} for #{func} #{name}.
    Expected one of #{inspect(@types)}.
    Hint: Use :any if the type is not listed.\
    """

    {:error, message}
  end

  defp validate_opts_keys(func, name, type, opts) do
    with true <- Keyword.keyword?(opts),
         keys <- Keyword.keys(opts),
         valid_opts <- get_valid_opts(func, type, opts),
         [] <- keys -- (valid_opts ++ @private_opts) do
      :ok
    else
      false ->
        {:error,
         "invalid options for #{func} #{name}. " <>
           "Expected a keyword list of options, got: #{inspect(remove_private_opts(opts))}"}

      unknown_options ->
        valid_opts = get_valid_opts(func, type, opts)
        {:error, unknown_options_message(valid_opts, unknown_options)}
    end
  end

  defp validate_opts_ast!(func, opts, caller) when is_list(opts) do
    if Keyword.keyword?(opts) do
      for {key, value} <- opts do
        {key, validate_opt_ast!(func, key, value, caller)}
      end
    else
      opts
    end
  end

  defp validate_opts_ast!(_func, opts, _caller) do
    opts
  end

  defp validate_opts(func, type, opts) do
    Enum.reduce_while(opts, :ok, fn {key, value}, _acc ->
      case validate_opt(func, type, key, value) do
        :ok ->
          {:cont, :ok}

        error ->
          {:halt, error}
      end
    end)
  end

  defp validate_required_opts(func, type, opts) do
    case get_required_opts(func, type, opts) -- Keyword.keys(opts) do
      [] ->
        :ok

      missing_opts ->
        {:error, "the following options are required: #{inspect(missing_opts)}"}
    end
  end

  defp get_valid_opts(:prop, _type, _opts) do
    [:required, :default, :values, :accumulate]
  end

  defp get_valid_opts(:data, _type, _opts) do
    [:default, :values]
  end

  defp get_valid_opts(:slot, _type, _opts) do
    [:required, :props]
  end

  defp get_required_opts(_func, _type, _opts) do
    []
  end

  defp validate_opt_ast!(:slot, :props, args_ast, caller) do
    Enum.map(args_ast, fn
      {name, {:^, _, [{generator, _, context}]}} when context in [Elixir, nil] ->
        Macro.escape(%{name: name, generator: generator})

      name when is_atom(name) ->
        Macro.escape(%{name: name, generator: nil})

      ast ->
        message =
          "invalid slot prop #{Macro.to_string(ast)}. " <>
            "Expected an atom or a binding to a generator as `key: ^property_name`"

        IOHelper.compile_error(message, caller.file, caller.line)
    end)
  end

  defp validate_opt_ast!(_func, _key, value, _caller) do
    value
  end

  defp validate_opt(_func, _type, :required, value) when not is_boolean(value) do
    {:error, "invalid value for option :required. Expected a boolean, got: #{inspect(value)}"}
  end

  defp validate_opt(_func, _type, :values, value) when not is_list(value) do
    {:error,
     "invalid value for option :values. Expected a list of values, got: #{inspect(value)}"}
  end

  defp validate_opt(:prop, _type, :accumulate, value) when not is_boolean(value) do
    {:error, "invalid value for option :accumulate. Expected a boolean, got: #{inspect(value)}"}
  end

  defp validate_opt(_func, _type, _key, _value) do
    :ok
  end

  defp unknown_options_message(valid_opts, unknown_options) do
    {plural, unknown_items} =
      case unknown_options do
        [option] ->
          {"", option}

        _ ->
          {"s", unknown_options}
      end

    """
    unknown option#{plural} #{inspect(unknown_items)}. \
    Available options: #{inspect(valid_opts)}\
    """
  end

  defp format_opts(opts_ast) do
    opts_ast
    |> Macro.to_string()
    |> String.slice(1..-2)
  end

  defp generate_docs(env) do
    case Module.get_attribute(env.module, :moduledoc) do
      {_line, false} ->
        :ok

      nil ->
        props_doc = generate_props_docs(env.module)
        Module.put_attribute(env.module, :moduledoc, {env.line, props_doc})

      {line, doc} ->
        props_doc = generate_props_docs(env.module)
        Module.put_attribute(env.module, :moduledoc, {line, doc <> "\n" <> props_doc})
    end
  end

  defp generate_props_docs(module) do
    docs =
      for prop <- Module.get_attribute(module, :prop) do
        doc = if prop.doc, do: " - #{prop.doc}.", else: ""
        opts = if prop.opts == [], do: "", else: ", #{format_opts(prop.opts_ast)}"
        "* **#{prop.name}** *#{inspect(prop.type)}#{opts}*#{doc}"
      end
      |> Enum.reverse()
      |> Enum.join("\n")

    """
    ### Properties

    #{docs}
    """
  end

  defp validate_slot_props_bindings!(env) do
    for slot <- env.module.__slots__(),
        slot_props = Keyword.get(slot.opts, :props, []),
        %{name: name, generator: generator} <- slot_props,
        generator != nil do
      case env.module.__get_prop__(generator) do
        nil ->
          existing_properties_names = env.module.__props__() |> Enum.map(& &1.name)

          message = """
          cannot bind slot prop `#{name}` to property `#{generator}`. \
          Expected a existing property after `^`, \
          got: an undefined property `#{generator}`.

          Hint: Available properties are #{inspect(existing_properties_names)}\
          """

          IOHelper.compile_error(message, env.file, slot.line)

        %{type: type} when type != :list ->
          message = """
          cannot bind slot prop `#{name}` to property `#{generator}`. \
          Expected a property of type :list after `^`, \
          got: a property of type #{inspect(type)}\
          """

          IOHelper.compile_error(message, env.file, slot.line)

        _ ->
          :ok
      end
    end

    :ok
  end

  defp pop_doc(module) do
    doc =
      case Module.get_attribute(module, :doc) do
        {_, doc} -> doc
        _ -> nil
      end

    Module.delete_attribute(module, :doc)
    doc
  end

  defp build_assign_ast(func, name_ast, type_ast, opts_ast, caller) do
    quote bind_quoted: [
            func: func,
            name: validate_name_ast!(func, name_ast, caller),
            type: type_ast,
            opts: validate_opts_ast!(func, opts_ast, caller),
            opts_ast: Macro.escape(opts_ast),
            line: caller.line
          ] do
      Surface.API.put_assign!(__ENV__, func, name, type, opts, opts_ast, line)
    end
  end

  defp remove_private_opts(opts) do
    if is_list(opts) do
      Enum.reject(opts, fn o -> Enum.any?(@private_opts, fn p -> match?({^p, _}, o) end) end)
    else
      opts
    end
  end
end
