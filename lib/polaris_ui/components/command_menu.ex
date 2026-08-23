defmodule PolarisUI.Components.CommandMenu do
  @moduledoc """
  The Polaris command menu: the app-wide ⌘K control center — the port
  of the Supabase design system Command Menu (`ui-patterns/CommandMenu`),
  which composes the Dialog and Command primitives into one searchable
  palette of actions.

  The React fragment wires valtio stores, page stacks, telemetry, and
  drag-to-close; this port keeps the anatomy, styling, and interaction
  model 1:1 while splitting the brain along the established LiveView
  seam:

    * the **server** owns the command registry — `sections` is a plain
      assign, and activating a command pushes `on_command` with
      `%{"id" => id}`;
    * the colocated **hook** owns the view layer — the ⌘K/Ctrl+K
      shortcut (the source's `openKey` listener), trigger toggling,
      Escape, click-outside dismissal, and focus/scroll locking.
      Filtering and arrow-key navigation ride the Command hook nested
      inside the panel.

  ## Anatomy

      <.command_menu
        id="app-menu"
        open={@menu_open}
        on_open_change="toggle-menu"
        on_command="run-command"
        sections={@sections}
      />

      # sections: [
      #   %{
      #     heading: "Actions",
      #     commands: [
      #       %{id: "alert", name: "Alert"},
      #       %{id: "invite", name: "Invite member", shortcut: "⌘I"},
      #       %{id: "theme", name: "Switch to dark theme",
      #         value: "dark theme, dark mode, theme", disabled: false}
      #     ]
      #   }
      # ]

    * **trigger** — the search-box-styled button (`h-[30px]` bordered
      field) with the magnifier glyph, the placeholder, and the ⌘K
      badge (drop the badge with `show_shortcut={false}`); its whole
      markup can be replaced through the `trigger` slot.
    * **panel** — the mobile bottom sheet (`h-[85dvh] rounded-t-lg`)
      that becomes the centered `md:max-h-[500px]` dialog on desktop,
      over the dimmed blurred overlay.
    * **command** — the Command palette itself: the tall search field,
      the scrollable grouped list, and the "No results found." empty
      state. Groups carry the fragment's `py-3 px-2` rhythm.

  ## Keyboard

    * **⌘K / Ctrl+K** (the `open_key`, `"k"` by default; `""`
      disables) — toggle the menu from anywhere in the document.
    * **Type** — filter commands against `value` (defaulting to
      `name`) plus `keywords`, case-insensitively.
    * **ArrowDown / ArrowUp / Enter** — the Command's navigation;
      Enter activates the highlighted command by dispatching its own
      click, so `on_command` fires identically for pointer and
      keyboard.
    * **Escape** — close (after the query clears, the Command keeps
      focus so the second Escape closes — the fragment's ladder).

  ## Microcopy

  Commands use direct verbs ("Invite member", "Go to Supabase
  website"), the `placeholder` sets the intent ("Run a command or
  search..."), and `empty_label` covers the miss ("No results
  found."). Pack alternate phrasings into `value` or `keywords` — the
  fragment's comma-joined phrase pattern.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  import PolarisUI.Components.Command,
    only: [
      command: 1,
      command_input: 1,
      command_list: 1,
      command_empty: 1,
      command_group: 1,
      command_item: 1,
      command_separator: 1
    ]

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the command menu root — required because the colocated
    hook that manages the shortcut and dismissal anchors on it. Derived
    ids: `"<id>-trigger"`, `"<id>-panel"`, `"<id>-command"`.
    """
  )

  attr(:open, :boolean,
    default: false,
    doc: "Server-driven visibility. Toggle it from the `on_open_change` handler."
  )

  attr(:on_open_change, :string,
    required: true,
    doc: """
    LiveView event pushed on every client-side transition — trigger
    click, ⌘K, Escape, click-outside — with payload `%{"open" =>
    "true" | "false"}`.
    """
  )

  attr(:on_command, :string,
    required: true,
    doc: "LiveView event pushed when a command is activated, with payload `%{\"id\" => id}`."
  )

  attr(:sections, :list,
    required: true,
    doc: """
    Command sections — `[%{heading: "Actions" | nil, commands:
    [%{id: "alert", name: "Alert", value: nil, keywords: [],
    shortcut: nil, disabled: false}]}]`. `id` and `name` are required
    per command; `value` (the filter target, comma-joined phrasings)
    defaults to `name`.
    """
  )

  attr(:open_key, :string,
    default: "k",
    doc: """
    The key combined with ⌘/Ctrl that toggles the menu from anywhere —
    `"k"` by default (the source's `openKey`). Pass `""` to disable.
    """
  )

  attr(:placeholder, :string,
    default: "Run a command or search...",
    doc: "The palette field's placeholder."
  )

  attr(:empty_label, :string,
    default: "No results found.",
    doc: "Text for the filtered-empty state."
  )

  attr(:trigger_label, :string,
    default: "Search...",
    doc: "Placeholder text shown in the search-box trigger button."
  )

  attr(:show_shortcut, :boolean,
    default: true,
    doc: "Render the ⌘K badge in the trigger (hidden below `md:` either way)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the root wrapper.")

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, `phx-*`, …")

  slot(:trigger,
    doc: """
    Replaces the trigger button's inner content (icons, text). The
    styled button, toggling, and ARIA wiring stay.
    """
  )

  def command_menu(assigns) do
    sections = normalize_sections(assigns.sections)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Root",
        sections: sections,
        state: if(assigns.open, do: "open", else: "closed")
      )

    ~H"""
    <div
      id={@id}
      class={@class}
      data-polaris-command-menu
      data-state={@state}
      data-open-event={@on_open_change}
      data-open-key={@open_key}
      phx-hook={@hook}
      {@rest}
    >
      <button
        id={"#{@id}-trigger"}
        type="button"
        data-polaris-command-menu-trigger
        aria-haspopup="dialog"
        aria-expanded={to_string(@open)}
        aria-controls={"#{@id}-panel"}
        class={
          cn([
            "group flex h-[30px] w-full cursor-pointer items-center justify-between gap-2",
            "rounded-md border border-surface-border bg-transparent pl-2 pr-1",
            "text-content-secondary transition-colors",
            "hover:bg-surface-panel hover:border-surface-border-hover",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
          ])
        }
      >
        <%= if @trigger != [] do %>
          {render_slot(@trigger)}
        <% else %>
          <span class="flex items-center gap-1.5">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="size-4 text-content-secondary transition-colors group-hover:text-content-primary"
              aria-hidden="true"
            >
              <circle cx="11" cy="11" r="8" />
              <path d="m21 21-4.3-4.3" />
            </svg>
            <span class="text-xs text-content-muted">{@trigger_label}</span>
          </span>
          <kbd
            :if={@show_shortcut}
            aria-hidden="true"
            class="hidden md:inline-flex h-full items-center rounded-sm border border-surface-border bg-surface-panel-hover px-1.5 font-mono text-xs text-content-secondary"
          >
            ⌘{String.upcase(@open_key)}
          </kbd>
        <% end %>
      </button>

      <%= if @open do %>
        <div
          data-polaris-command-menu-overlay
          aria-hidden="true"
          class="fixed inset-0 z-50 bg-overlay backdrop-blur-xs"
        >
        </div>
        <div
          id={"#{@id}-panel"}
          data-polaris-command-menu-container
          role="dialog"
          aria-modal="true"
          aria-labelledby={"#{@id}-title"}
          aria-describedby={"#{@id}-description"}
          class="fixed inset-0 z-50 grid place-items-end overflow-y-auto md:place-items-center md:py-8"
        >
          <div
            data-polaris-command-menu-content
            tabindex="-1"
            class={
              cn([
                "relative z-50 flex h-[85dvh] w-full flex-col overflow-hidden rounded-t-lg border border-surface-border",
                "bg-surface-panel text-content-primary shadow-md md:h-auto md:max-h-[500px] md:max-w-lg md:rounded-lg"
              ])
            }
          >
            <h2 id={"#{@id}-title"} class="sr-only">Command menu</h2>
            <p id={"#{@id}-description"} class="sr-only">Type a command or search</p>
            <.command id={"#{@id}-command"} class="rounded-none">
              <.command_input placeholder={@placeholder} class="h-11 text-base" />
              <.command_list class="grow max-h-none">
                <.command_empty>{@empty_label}</.command_empty>
                <%= for {section, index} <- Enum.with_index(@sections) do %>
                  <.command_separator :if={index > 0} />
                  <.command_group
                    heading={section.heading}
                    class="py-3 px-2"
                    heading_class="pb-1.5 font-sans text-sm normal-case tracking-normal text-content-secondary"
                  >
                    <.command_item
                      :for={command <- section.commands}
                      value={command.value}
                      keywords={command.keywords}
                      disabled={command.disabled}
                      phx-click={@on_command}
                      phx-value-id={command.id}
                      class="py-2 text-sm"
                    >
                      {command.name}
                      <:shortcut :if={command.shortcut}>{command.shortcut}</:shortcut>
                    </.command_item>
                  </.command_group>
                <% end %>
              </.command_list>
            </.command>
          </div>
        </div>
      <% end %>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          this._open = root.dataset.state === "open"

          this._push = (open) => {
            const name = root.dataset.openEvent
            if (name && typeof this.pushEvent === "function") {
              this.pushEvent(name, { open: open })
            }
          }

          this._isOpen = () => root.dataset.state === "open"

          // The source's CommandShortcut listener: ⌘/Ctrl + openKey with
          // no other modifiers toggles from anywhere in the document.
          this._onKeydown = (event) => {
            const openKey = root.dataset.openKey || ""
            if (openKey && event.key === openKey && (event.metaKey || event.ctrlKey) && !event.altKey && !event.shiftKey) {
              event.preventDefault()
              this._push(!this._isOpen())
              return
            }
            if (event.key === "Escape" && this._isOpen()) {
              event.preventDefault()
              this._push(false)
            } else if (event.key === "Tab" && this._isOpen()) {
              const container = root.querySelector("[data-polaris-command-menu-container]")
              if (!container) return
              const items = Array.from(
                container.querySelectorAll(
                  'a[href], button:not([disabled]), input:not([disabled]), [tabindex]:not([tabindex="-1"])'
                )
              ).filter((el) => el.offsetParent !== null)
              if (items.length === 0) return
              const first = items[0]
              const last = items[items.length - 1]
              if (event.shiftKey && document.activeElement === first) {
                event.preventDefault()
                last.focus()
              } else if (!event.shiftKey && document.activeElement === last) {
                event.preventDefault()
                first.focus()
              }
            }
          }
          document.addEventListener("keydown", this._onKeydown, true)

          this._onClick = (event) => {
            if (event.target.closest("[data-polaris-command-menu-trigger]")) {
              event.preventDefault()
              this._push(!this._isOpen())
            }
          }
          root.addEventListener("click", this._onClick)

          // Click on the overlay/container background dismisses.
          this._onDocumentClick = (event) => {
            if (!this._isOpen()) return
            const container = root.querySelector("[data-polaris-command-menu-container]")
            if (container && event.target === container) {
              this._push(false)
            }
          }
          document.addEventListener("click", this._onDocumentClick)

          this._sync()
        },
        updated() {
          this._sync()
        },
        _sync() {
          const open = this._isOpen()
          if (open) {
            document.body.style.overflow = "hidden"
            const input = this.el.querySelector("[data-polaris-command-input]")
            if (input && !this.el.contains(document.activeElement)) {
              input.focus()
            }
          } else {
            document.body.style.overflow = ""
          }
        },
        destroyed() {
          document.body.style.overflow = ""
          if (!this.el) {
            return
          }
          this.el.removeEventListener("click", this._onClick)
          document.removeEventListener("keydown", this._onKeydown, true)
          document.removeEventListener("click", this._onDocumentClick)
        }
      }
    </script>
    """
  end

  # Sections normalize to the fragment's ICommandSection shape; commands to
  # ICommand (value — the cmdk filter target — defaults to the name).
  defp normalize_sections(sections), do: Enum.map(sections, &normalize_section/1)

  defp normalize_section(%{commands: commands} = section) do
    %{
      heading: Map.get(section, :heading),
      commands: Enum.map(commands, &normalize_command/1)
    }
  end

  defp normalize_section(section) do
    raise ArgumentError, "each section must be a map with a :commands list, got: #{inspect(section)}"
  end

  defp normalize_command(%{id: id, name: name} = command) do
    %{
      id: id,
      name: name,
      value: Map.get(command, :value) || name,
      keywords: Map.get(command, :keywords, []),
      shortcut: Map.get(command, :shortcut),
      disabled: !!Map.get(command, :disabled, false)
    }
  end

  defp normalize_command(command) do
    raise ArgumentError, "each command must be a map with :id and :name, got: #{inspect(command)}"
  end
end
