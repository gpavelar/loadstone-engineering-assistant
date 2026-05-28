import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "form", "sendButton"]
  static values = { commands: { type: Array, default: [] } }

  connect() {
    this.scrollToBottom()
    this.observeMessages()
    this.buildSlashPalette()
    this.listenForTurboEvents()
  }

  submit(event) {
    const input = this.inputTarget
    if (input.value.trim() === "") {
      event.preventDefault()
      return
    }
    // Turbo events handle the loading state — just clear input after submit
    this.pendingMessage = input.value.trim()
  }

  listenForTurboEvents() {
    // Show spinner when Turbo starts the fetch
    this.element.addEventListener("turbo:submit-start", () => {
      this.showLoading()
      this.inputTarget.value = ""
      this.inputTarget.disabled = true
      this.sendButtonTarget.disabled = true
      this.sendButtonTarget.textContent = "Thinking..."
    })

    // Re-enable input when Turbo finishes (success or error)
    this.element.addEventListener("turbo:submit-end", () => {
      this.removeLoading()
    })
  }

  showLoading() {
    const wrapper = document.createElement("div")
    wrapper.id = "loading-indicator"
    wrapper.className = "flex gap-3"

    const bubble = document.createElement("div")
    bubble.className = "max-w-2xl rounded-2xl rounded-bl-md bg-gray-800 px-4 py-3"

    const inner = document.createElement("div")
    inner.className = "flex items-center gap-2 text-gray-400 text-sm"

    const spinner = document.createElement("span")
    spinner.className = "animate-spin inline-block h-4 w-4 border-2 border-gray-400 border-t-transparent rounded-full"

    const messages = [
      "Aligning the magnetic field...",
      "Pulling signals toward you...",
      "Magnetising your priorities...",
      "Finding true north...",
      "Attracting the right data...",
    ]
    const text = document.createElement("span")
    text.textContent = messages[Math.floor(Math.random() * messages.length)]

    inner.appendChild(spinner)
    inner.appendChild(text)
    bubble.appendChild(inner)
    wrapper.appendChild(bubble)
    this.messagesTarget.appendChild(wrapper)
    this.scrollToBottom()
  }

  removeLoading() {
    const indicator = document.getElementById("loading-indicator")
    if (indicator) indicator.remove()
    this.inputTarget.disabled = false
    this.inputTarget.focus()
    this.sendButtonTarget.disabled = false
    this.sendButtonTarget.textContent = "Send"
  }

  scrollToBottom() {
    const el = this.messagesTarget
    el.scrollTop = el.scrollHeight
  }

  observeMessages() {
    const observer = new MutationObserver((mutations) => {
      for (const m of mutations) {
        for (const node of m.addedNodes) {
          if (node.nodeType === 1 && node.id !== "loading-indicator") {
            this.removeLoading()
          }
        }
      }
      this.scrollToBottom()
    })
    observer.observe(this.messagesTarget, { childList: true })
  }

  buildSlashPalette() {
    const input = this.inputTarget
    const palette = document.createElement("div")
    palette.id = "slash-palette"
    palette.className = "hidden absolute bottom-full left-0 right-0 mb-2 bg-gray-800 border border-gray-600 rounded-lg shadow-xl overflow-hidden"

    this.commandsValue.forEach((c, i) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.dataset.index = i
      btn.dataset.cmd = c.cmd
      btn.className = "slash-item flex items-center gap-3 w-full px-4 py-2.5 text-left hover:bg-gray-700 transition text-sm"

      const cmdSpan = document.createElement("span")
      cmdSpan.className = "font-mono text-blue-400 min-w-[200px]"
      cmdSpan.textContent = c.cmd

      const descSpan = document.createElement("span")
      descSpan.className = "text-gray-400"
      descSpan.textContent = c.desc

      btn.appendChild(cmdSpan)
      btn.appendChild(descSpan)
      palette.appendChild(btn)
    })

    const formContainer = input.closest("div")
    formContainer.style.position = "relative"
    formContainer.appendChild(palette)

    let selectedIndex = -1

    input.addEventListener("input", () => {
      const val = input.value
      if (val === "/") {
        palette.classList.remove("hidden")
        selectedIndex = -1
        this._highlightItems(palette, selectedIndex)
      } else if (val.startsWith("/")) {
        const filter = val.toLowerCase()
        let hasVisible = false
        palette.querySelectorAll(".slash-item").forEach(item => {
          const matches = item.dataset.cmd.toLowerCase().startsWith(filter)
          item.style.display = matches ? "" : "none"
          if (matches) hasVisible = true
        })
        palette.classList.toggle("hidden", !hasVisible)
        selectedIndex = -1
      } else {
        palette.classList.add("hidden")
      }
    })

    input.addEventListener("keydown", (e) => {
      if (palette.classList.contains("hidden")) return
      const items = [...palette.querySelectorAll(".slash-item")].filter(i => i.style.display !== "none")

      if (e.key === "ArrowDown") {
        e.preventDefault()
        selectedIndex = Math.min(selectedIndex + 1, items.length - 1)
        this._highlightItems(palette, selectedIndex, items)
      } else if (e.key === "ArrowUp") {
        e.preventDefault()
        selectedIndex = Math.max(selectedIndex - 1, 0)
        this._highlightItems(palette, selectedIndex, items)
      } else if (e.key === "Enter" && selectedIndex >= 0) {
        e.preventDefault()
        input.value = items[selectedIndex].dataset.cmd + " "
        palette.classList.add("hidden")
      } else if (e.key === "Escape") {
        palette.classList.add("hidden")
      } else if (e.key === "Tab" && items.length > 0) {
        e.preventDefault()
        input.value = items[selectedIndex >= 0 ? selectedIndex : 0].dataset.cmd + " "
        palette.classList.add("hidden")
      }
    })

    palette.addEventListener("click", (e) => {
      const item = e.target.closest(".slash-item")
      if (item) {
        input.value = item.dataset.cmd + " "
        palette.classList.add("hidden")
        input.focus()
      }
    })

    document.addEventListener("click", (e) => {
      if (!palette.contains(e.target) && e.target !== input) {
        palette.classList.add("hidden")
      }
    })
  }

  _highlightItems(palette, index, items) {
    const allItems = items || [...palette.querySelectorAll(".slash-item")].filter(i => i.style.display !== "none")
    allItems.forEach((item, i) => {
      item.classList.toggle("bg-gray-700", i === index)
    })
  }
}
