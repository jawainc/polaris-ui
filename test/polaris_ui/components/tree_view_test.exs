defmodule PolarisUI.Components.TreeViewTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.TreeView` — the port
  of the Supabase design system TreeView (react-accessible-treeview
  with the 28px data-row treatment): the nested tree/group anatomy,
  the flatten helper, level-padding guide-line geometry, the selected/
  loading/editing/disabled row states, and the colocated hook owning
  the expansion + selection state machine (roving keyboard, inline
  rename guards).
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.TreeView

  @hook "PolarisUI.Components.TreeView.Root"

  # Three levels, one empty-children leaf ("functions"), one loading
  # branch ("logs"), one disabled leaf with a description ("draft").
  @tree [
    %{
      id: "public",
      name: "public",
      children: [
        %{
          id: "tables",
          name: "Tables",
          children: [
            %{id: "users", name: "users"},
            %{id: "profiles", name: "profiles"}
          ]
        },
        %{id: "functions", name: "Functions", children: []}
      ]
    },
    %{id: "logs", name: "Logs", loading: true, children: [%{id: "today", name: "Today"}]},
    %{id: "draft", name: "Draft", disabled: true, description: "  Not published yet  "}
  ]

  defp render_tree(assigns) do
    assigns =
      Map.merge(
        %{
          id: "schema-tree",
          items: @tree,
          expanded: [],
          selected: nil,
          editing_id: nil,
          on_select: "select-node",
          on_toggle: "toggle-node",
          on_rename: "rename-node",
          label: nil,
          x_padding: 16,
          level_padding: 38,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.tree_view
      id={@id}
      items={@items}
      expanded={@expanded}
      selected={@selected}
      editing_id={@editing_id}
      on_select={@on_select}
      on_toggle={@on_toggle}
      on_rename={@on_rename}
      label={@label}
      x_padding={@x_padding}
      level_padding={@level_padding}
      class={@class}
      {assigns[:rest]}
    />
    """)
  end

  describe "anatomy" do
    test "renders the hook-anchored tree root with the event dataset" do
      html = render_tree(%{})

      assert html =~ ~s{<ul id="schema-tree"}
      assert html =~ ~s{role="tree"}
      assert html =~ ~s{data-polaris-tree-view}
      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ "w-full list-none p-0 text-sm"
    end

    test "one treeitem li per node, one nested group ul per branch" do
      html = render_tree(%{})

      # 8 nodes: public, tables, users, profiles, functions, logs, today, draft.
      assert count(html, ~s{role="treeitem"}) == 8
      # 3 branches own groups: public, tables, logs (functions is an empty leaf).
      assert count(html, ~s{role="group"}) == 3
      assert count(html, ~s{data-parent-id="}) == 3
    end

    test "groups nest inside their branch li, depth-first" do
      html = render_tree(%{expanded: ["public"]})

      assert position(html, ~s{data-polaris-tree-group}) <
               position(html, ~s{id="schema-tree-tables-item"})

      assert position(html, ~s{data-id="tables" data-branch="true"}) <
               position(html, ~s{id="schema-tree-users-item"})
    end

    test "element ids derive from the root id and the node id" do
      html = render_tree(%{})

      assert html =~ ~s{id="schema-tree-users-item"}
      assert html =~ ~s{id="schema-tree-public-group"}
    end

    test "the default cluster: chevron + folder on branches, file glyph on leaves" do
      html = render_tree(%{expanded: ["public", "tables"]})

      # Branch rows carry the chevron and a folder glyph; leaves carry the
      # neutral file glyph and the truncated name span.
      public = segment(html, ~s{data-id="public"})
      assert public =~ "m9 18 6-6-6-6"
      assert public =~ "group-aria-expanded/tree-item:rotate-90"
      assert public =~ "M20 20a2 2 0 0 0 2-2V8a2"

      users = segment(html, ~s{data-id="users"})
      refute users =~ "m9 18 6-6-6-6"
      assert users =~ "M15 2H6a2 2 0 0 0-2 2v16"
      assert users =~ ~s{<span class="truncate text-sm">users</span>}
    end

    test "the folder glyph swaps to the open geometry while expanded" do
      html = render_tree(%{expanded: ["public"]})

      assert segment(html, ~s{data-id="public"}) =~ "M6 14l1.45-2.9"
      assert segment(html, ~s{data-id="tables"}) =~ "M20 20a2 2 0 0 0 2-2V8a2"
    end

    test "the item slot replaces the default cluster with let bindings" do
      assigns = %{tree: @tree}

      html =
        rendered_to_string(~H"""
        <.tree_view id="schema-tree" items={@tree} expanded={["public"]} on_select="select-node">
          <:item :let={row}>
            <span data-level={row.level} data-branch={to_string(row.is_branch)}>{row.item.name}</span>
            <button phx-click="rename-node" phx-value-id={row.item.id}>Rename</button>
          </:item>
        </.tree_view>
        """)

      # The custom content renders on every row with its bindings...
      assert html =~ ~s{<span data-level="1" data-branch="true">public</span>}
      assert html =~ ~s{<span data-level="3" data-branch="false">users</span>}
      assert count(html, ~s{phx-click="rename-node"}) == 8
      # ...and the default cluster is fully replaced.
      refute html =~ "m9 18 6-6-6-6"
      refute html =~ "M15 2H6a2 2 0 0 0-2 2v16"
      refute html =~ ~s{class="truncate text-sm"}
      _ = assigns
    end

    test "a node description rides the native title, trimmed" do
      html = render_tree(%{})

      assert segment(html, ~s{data-id="draft"}) =~ "title=\"Draft\nNot published yet\""
      assert segment(html, ~s{data-id="users"}) =~ ~s{title="users"}
    end
  end

  describe "flatten_tree/1" do
    test "flattens depth-first with levels, parents, and branch flags" do
      entries = flatten_tree(@tree)

      assert Enum.map(entries, & &1.id) ==
               ["public", "tables", "users", "profiles", "functions", "logs", "today", "draft"]

      by_id = Map.new(entries, &{&1.id, &1})
      assert %{level: 1, parent_id: nil, is_branch: true} = by_id["public"]
      assert %{level: 2, parent_id: "public", is_branch: true} = by_id["tables"]
      assert %{level: 3, parent_id: "tables", is_branch: false} = by_id["users"]
      assert by_id["public"].children_ids == ["tables", "functions"]
      assert by_id["tables"].children_ids == ["users", "profiles"]
      assert by_id["functions"].children_ids == []
      # The original node map rides along, extras included.
      assert by_id["logs"].node == %{
               id: "logs",
               name: "Logs",
               loading: true,
               children: [%{id: "today", name: "Today"}]
             }
    end

    test "raises on a non-list input" do
      assert_raise ArgumentError, ~r/must be a list of node maps/, fn ->
        flatten_tree("public")
      end
    end

    test "raises on non-map items" do
      assert_raise ArgumentError, ~r/every tree item must be a map/, fn ->
        flatten_tree([%{id: "a", name: "A"}, 42])
      end
    end

    test "raises on missing or non-binary ids" do
      assert_raise ArgumentError, ~r/non-empty string :id/, fn ->
        flatten_tree([%{name: "NoId"}])
      end

      assert_raise ArgumentError, ~r/non-empty string :id/, fn ->
        flatten_tree([%{id: :public, name: "Public"}])
      end
    end

    test "raises on duplicate ids anywhere in the tree" do
      assert_raise ArgumentError, ~r/duplicate item id "users".*unique/, fn ->
        flatten_tree([
          %{id: "users", name: "One", children: [%{id: "users", name: "Two"}]}
        ])
      end
    end

    test "raises on non-binary names" do
      assert_raise ArgumentError, ~r/string :name/, fn ->
        flatten_tree([%{id: "a", name: 42}])
      end
    end

    test "raises on non-list children" do
      assert_raise ArgumentError, ~r/:children must be a list of item maps/, fn ->
        flatten_tree([%{id: "a", name: "A", children: "nope"}])
      end
    end
  end

  describe "row geometry" do
    test "the 28px row with the source's padding arithmetic" do
      html = render_tree(%{expanded: ["public", "tables"]})

      assert segment(html, ~s{data-id="public"}) =~
               "relative flex h-[28px] items-center gap-3 text-sm cursor-pointer select-none"

      # paddingLeft = 16 + (level - 1) * 38 / 2 — 16, 35, 54.
      assert segment(html, ~s{data-id="public"}) =~ "padding-left: 16px;"
      assert segment(html, ~s{data-id="tables"}) =~ "padding-left: 35px;"
      assert segment(html, ~s{data-id="users"}) =~ "padding-left: 54px;"
    end

    test "guide lines: one per ancestor level, at the chevron's half width" do
      html = render_tree(%{expanded: ["public", "tables"]})

      # 3 level-2 rows x 1 line + 2 level-3 rows x 2 lines.
      assert count(html, "absolute h-full w-px bg-surface-border-hover") == 7
      refute segment(html, ~s{data-id="public"}) =~ "w-px"
      assert segment(html, ~s{data-id="tables"}) =~ "left: 23px;"
      assert segment(html, ~s{data-id="users"}) =~ "left: 23px;"
      assert segment(html, ~s{data-id="users"}) =~ "left: 42px;"
    end

    test "x_padding and level_padding are caller-tunable" do
      html = render_tree(%{expanded: ["public", "tables"], x_padding: 8, level_padding: 20})

      assert segment(html, ~s{data-id="public"}) =~ "padding-left: 8px;"
      assert segment(html, ~s{data-id="users"}) =~ "padding-left: 28px;"
      assert segment(html, ~s{data-id="users"}) =~ "left: 15px;"
      assert segment(html, ~s{data-id="users"}) =~ "left: 25px;"
    end

    test "rejects non-integer and negative paddings" do
      assert_raise ArgumentError, ~r/:x_padding/, fn -> render_tree(%{x_padding: 12.5}) end

      assert_raise ArgumentError, ~r/:level_padding/, fn -> render_tree(%{level_padding: -2}) end
    end
  end

  describe "states" do
    test "selected: aria-selected, the selection bar, and the emerald wash" do
      html = render_tree(%{expanded: ["public", "tables"], selected: "users"})

      assert segment(html, ~s{data-id="users"}) =~ ~s{aria-selected="true"}

      assert segment(html, ~s{data-id="users"}) =~
               "absolute left-0 h-full w-0.5 bg-content-primary"

      assert segment(html, ~s{data-id="users"}) =~
               "group-aria-selected/tree-item:bg-brand-emerald-muted"

      refute segment(html, ~s{data-id="profiles"}) =~ "bg-content-primary"
    end

    test "hover and focus ring ride the row through the group relationship" do
      html = render_tree(%{})

      row = marker_class(html, "data-polaris-tree-row")
      assert row =~ "hover:bg-surface-muted"
      assert row =~ "text-content-secondary"

      assert row =~
               "group-focus-visible/tree-item:ring-2 group-focus-visible/tree-item:ring-brand-emerald"

      assert row =~
               "group-focus-visible/tree-item:ring-offset-2 group-focus-visible/tree-item:ring-offset-surface-ground"
    end

    test "expanded seed opens the group; collapsed groups carry hidden" do
      html = render_tree(%{expanded: ["public"]})

      assert segment(html, ~s{data-id="public"}) =~ ~s{aria-expanded="true"}
      assert segment(html, ~s{data-id="public"}) =~ ~s{data-state="open"}
      assert segment(html, ~s{data-id="logs"}) =~ ~s{aria-expanded="false"}
      assert segment(html, ~s{data-id="logs"}) =~ ~s{data-state="closed"}

      # Only the two collapsed branch groups are hidden (LiveView renders
      # the boolean as a bare `hidden` attribute).
      assert count(html, ~s{" hidden>}) == 2
    end

    test "loading: the spinner replaces the chevron on a branch" do
      html = render_tree(%{})

      logs = segment(html, ~s{data-id="logs"})
      assert logs =~ ~s{data-loading="true"}
      assert logs =~ "M21 12a9 9 0 1 1-6.219-8.56"
      assert logs =~ "animate-spin"
      refute logs =~ "m9 18 6-6-6-6"
    end

    test "editing: the rename form replaces the row's content cluster" do
      html = render_tree(%{editing_id: "tables"})

      tables = segment(html, ~s{data-id="tables"})
      assert tables =~ ~s{<form data-polaris-tree-rename class="w-full">}
      assert tables =~ ~s{data-polaris-tree-rename-input}
      assert tables =~ ~s{aria-label="Rename Tables"}
      assert tables =~ ~s{value="Tables"}
      assert tables =~ "flex h-7 w-full rounded-md border border-surface-border bg-surface-panel"
      assert tables =~ "px-2 py-1 text-sm"
      refute tables =~ "m9 18 6-6-6-6"
      refute tables =~ ~s{<span class="truncate text-sm">Tables</span>}
      # Only the edited row swaps its cluster (a sibling branch keeps
      # its chevron — "users" is a leaf and never carries one).
      assert segment(html, ~s{data-id="public"}) =~ "m9 18 6-6-6-6"
    end

    test "disabled: aria-disabled, out of the tab order, dimmed without hover" do
      html = render_tree(%{})

      draft = segment(html, ~s{data-id="draft"})
      assert draft =~ ~s{aria-disabled="true"}
      assert draft =~ ~s{data-disabled="true"}
      assert draft =~ ~s{tabindex="-1"}

      assert draft =~
               "group-aria-disabled/tree-item:pointer-events-none group-aria-disabled/tree-item:opacity-50"

      assert draft =~ "group-aria-disabled/tree-item:cursor-not-allowed"
    end

    test "roving tabindex seed: the selected row, else the first visible" do
      html = render_tree(%{expanded: ["public", "tables"], selected: "users"})
      assert segment(html, ~s{data-id="users"}) =~ ~s{tabindex="0"}

      # A selected row hidden inside collapsed groups falls back to the
      # first visible row; the selection itself still renders.
      html = render_tree(%{selected: "users"})
      assert segment(html, ~s{data-id="public"}) =~ ~s{tabindex="0"}
      assert segment(html, ~s{data-id="users"}) =~ ~s{tabindex="-1"}
      assert segment(html, ~s{data-id="users"}) =~ ~s{aria-selected="true"}
    end
  end

  describe "events" do
    test "on_select, on_toggle, and on_rename ride the root dataset" do
      html = render_tree(%{})

      assert html =~ ~s{data-select-event="select-node"}
      assert html =~ ~s{data-toggle-event="toggle-node"}
      assert html =~ ~s{data-rename-event="rename-node"}
    end

    test "omit the dataset entries when no event is set" do
      html = render_tree(%{on_select: nil, on_toggle: nil, on_rename: nil})

      refute html =~ "data-select-event="
      refute html =~ "data-toggle-event="
      refute html =~ "data-rename-event="
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook and ships its script inline" do
      html = render_tree(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
      assert html =~ "updated()"
      assert html =~ "destroyed()"
    end

    test "seeds expansion and selection from the server DOM once" do
      html = render_tree(%{})

      assert html =~ ~s{item.dataset.state === "open"}
      assert html =~ ~s{getAttribute("aria-selected") === "true"}
    end

    test "a branch activation both selects and toggles, like the source" do
      html = render_tree(%{})

      assert html =~ "_activate(item)"
      # Branch check then toggle before select — the default-config click.
      activate =
        html |> String.split("_activate(item) {") |> Enum.at(1) |> String.split("_activate")

      [body | _] = activate
      assert body =~ "this._toggle(item.dataset.id)"
      assert body =~ "this._select(item.dataset.id)"
    end

    test "the toggle cycle pushes the open/closed state" do
      html = render_tree(%{})

      assert html =~ "_toggle(id)"
      assert html =~ ~s{state: open ? "open" : "closed"}
      assert html =~ ~s{state: "closed"}
      assert html =~ "this._apply()"
    end

    test "pushes are guarded and event names come from the dataset" do
      html = render_tree(%{})

      assert html =~ "typeof this.pushEvent === \"function\""
      assert html =~ "this.el.dataset.selectEvent"
      assert html =~ "this.el.dataset.toggleEvent"
      assert html =~ "this.el.dataset.renameEvent"
    end

    test "keyboard contract: arrows walk visible items only" do
      html = render_tree(%{})

      for key <- ~w(ArrowDown ArrowUp ArrowRight ArrowLeft Home End Enter) do
        assert html =~ ~s{event.key === "#{key}"}
      end

      assert html =~ "_visibleItems()"
      assert html =~ "[data-polaris-tree-group][hidden]"
    end

    test "ArrowRight expands, else steps; ArrowLeft collapses, else to parent" do
      html = render_tree(%{})

      assert html =~
               ~s{item.dataset.branch === "true" && !this._expanded.has(item.dataset.id)}

      assert html =~
               ~s{item.dataset.branch === "true" && this._expanded.has(item.dataset.id)}

      assert html =~ "group.dataset.parentId"
    end

    test "roving tabindex keeps exactly one tab stop" do
      html = render_tree(%{})

      assert html =~ "item.tabIndex = item === active ? 0 : -1"
      assert html =~ "enabled[0]"
    end

    test "re-applies its state after LiveView patches" do
      html = render_tree(%{})

      updated =
        html
        |> String.split("updated() {")
        |> Enum.at(1)
        |> String.split("destroyed")
        |> List.first()

      assert updated =~ "this._apply()"
      assert updated =~ "this._bindRename()"
    end

    test "cleans up every listener on destroy" do
      html = render_tree(%{})

      destroyed =
        html
        |> String.split("destroyed() {")
        |> Enum.at(1)
        |> String.split("},", parts: 2)
        |> List.first()

      for listener <- ~w(click keydown focusout submit) do
        assert destroyed =~ "removeEventListener(\"#{listener}\""
      end
    end

    test "clicks on actions inside custom rows never select or toggle" do
      html = render_tree(%{})

      assert html =~ ~s{closest("a, button, input, select, textarea, [contenteditable]")}
      assert html =~ "item.dataset.disabled === \"true\""
    end

    test "rename: the source's 200/50/400ms timing contract" do
      html = render_tree(%{})

      assert html =~ "}, 200)"
      assert html =~ "}, 50)"
      assert html =~ "Date.now() - this._editStart < 400"
      assert html =~ "lastIndexOf(\".\")"
      assert html =~ "setSelectionRange(0, endPos)"
      assert html =~ "input.focus()"
    end

    test "rename: Enter blurs into submit, Escape restores the original" do
      html = render_tree(%{})

      assert html =~ "rename.blur()"
      assert html =~ "rename.value = this._renameOriginal"
      assert html =~ "_submitRename(this._renameOriginal)"
      assert html =~ "_submitRename(input.value)"
    end

    test "rename pushes exactly once per edit session" do
      html = render_tree(%{})

      assert html =~ "this._renameDone"
      assert html =~ "_renameOriginal = input.value"
      assert html =~ "item.dataset.id"
    end
  end

  describe "accessibility" do
    test "aria-level mirrors the depth of every row" do
      html = render_tree(%{expanded: ["public", "tables"]})

      assert segment(html, ~s{data-id="public"}) =~ ~s{aria-level="1"}
      assert segment(html, ~s{data-id="tables"}) =~ ~s{aria-level="2"}
      assert segment(html, ~s{data-id="users"}) =~ ~s{aria-level="3"}
    end

    test "aria-selected renders on every item; aria-expanded on branches only" do
      html = render_tree(%{})

      assert count(html, ~s{aria-selected="}) == 8
      assert count(html, ~s{aria-expanded="}) == 3
      refute segment(html, ~s{data-id="users"}) =~ "aria-expanded"
    end

    test "label names the tree landmark" do
      html = render_tree(%{label: "Database schema"})

      assert html =~ ~s{aria-label="Database schema"}
    end

    test "the decorative glyphs are aria-hidden" do
      html = render_tree(%{})

      # chevron + folder + leaf + spinner glyphs.
      assert count(html, ~s{aria-hidden="true"}) >= 8
    end
  end

  describe "attributes" do
    test "forwards global attributes to the root ul" do
      html =
        render_tree(%{rest: %{"data-testid" => "schema-tree-root", "phx-update" => "ignore"}})

      assert html =~ ~s{data-testid="schema-tree-root"}
      assert html =~ ~s{phx-update="ignore"}
    end

    test "caller classes win conflicts via cn/1" do
      html = render_tree(%{class: "w-56"})

      root = marker_class(html, ~s{<ul id="schema-tree"})
      assert root =~ "w-56"
      assert root =~ "list-none p-0 text-sm"
      refute root =~ "w-full"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_tree(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  # ── helpers ──────────────────────────────────────────────────

  defp count(html, str) do
    length(String.split(html, str)) - 1
  end

  # Index of the first occurrence (nil-safe via large default).
  defp position(html, str) do
    case :binary.match(html, str) do
      {index, _} -> index
      :nomatch -> byte_size(html)
    end
  end

  # The chunk from just after `marker` to the next `<li ` open tag —
  # one row's div (and its group ul) without descendant rows.
  defp segment(html, marker) do
    [_, rest | _] = String.split(html, marker, parts: 2)

    rest
    |> String.split("<li ", parts: 2)
    |> List.first()
  end

  # The class attribute of the element carrying the given marker.
  defp marker_class(html, marker) do
    [_, after_marker | _] = String.split(html, marker, parts: 2)

    class =
      case :binary.match(after_marker, ~s{class="}) do
        {index, _} -> binary_part(after_marker, index + 7, byte_size(after_marker) - index - 7)
        :nomatch -> ""
      end

    class |> String.split(~s{"}) |> List.first()
  end
end
