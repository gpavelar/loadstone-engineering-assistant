import { Controller } from "@hotwired/stimulus"

// Fades out and removes the element after `after-value` milliseconds.
// Used by the shared/_toast partial appended via Turbo Stream.
export default class extends Controller {
  static values = { after: { type: Number, default: 3000 } }

  connect() {
    this.timer = setTimeout(() => {
      this.element.style.opacity = "0"
      setTimeout(() => this.element.remove(), 500)
    }, this.afterValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
