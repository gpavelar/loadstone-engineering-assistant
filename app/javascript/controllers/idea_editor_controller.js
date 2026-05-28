import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "body"]
  static values = { debounce: { type: Number, default: 600 } }

  connect() {
    this.timer = null
    this._beforeDistil = this.beforeDistil.bind(this)
    this._afterDistil = this.afterDistil.bind(this)
    document.addEventListener("turbo:submit-start", this._beforeDistil)
    document.addEventListener("turbo:submit-end", this._afterDistil)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("turbo:submit-start", this._beforeDistil)
    document.removeEventListener("turbo:submit-end", this._afterDistil)
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.formTarget.requestSubmit(), this.debounceValue)
  }

  beforeDistil(event) {
    if (!this._isDistilForm(event)) return
    clearTimeout(this.timer)
    if (this.hasBodyTarget) {
      this.bodyTarget.readOnly = true
      this.bodyTarget.classList.add("opacity-60")
    }
  }

  afterDistil(event) {
    if (!this._isDistilForm(event)) return
    if (this.hasBodyTarget) {
      this.bodyTarget.readOnly = false
      this.bodyTarget.classList.remove("opacity-60")

      // Was this a successful turbo_stream response (vs a redirect to flash)?
      const contentType = event.detail?.fetchResponse?.contentType || ""
      if (contentType.includes("turbo-stream")) {
        this.bodyTarget.scrollTop = this.bodyTarget.scrollHeight
      }
    }
  }

  _isDistilForm(event) {
    const form = event.target
    if (!form || !form.action) return false
    return /\/investigations\/\d+\/distil$/.test(form.action)
  }
}
