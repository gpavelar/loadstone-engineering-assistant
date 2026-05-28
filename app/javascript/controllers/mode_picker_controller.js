import { Controller } from "@hotwired/stimulus"

// Wires a row of mode chips to a hidden `mode` input and the steering textarea.
// Clicking a chip:
//   - sets the hidden mode input value
//   - replaces the steering textarea content with the mode's pre-fill text
//   - highlights the clicked chip
//
// Initial state (page load): the empty-value chip ("Default") is rendered active
// via the server (no JS needed at first paint). Subsequent clicks toggle which
// chip is active.

export default class extends Controller {
  static targets = ["modeInput", "steering"]

  select(event) {
    event.preventDefault()
    const { value, steering, label } = event.params
    this.modeInputTarget.value = value
    this.steeringTarget.value = steering
    this._highlightActive(label)
  }

  _highlightActive(activeLabel) {
    this.element.querySelectorAll("[data-action~='mode-picker#select']").forEach(btn => {
      const isActive = btn.textContent.trim() === activeLabel
      btn.classList.toggle("bg-blue-700", isActive)
      btn.classList.toggle("text-blue-100", isActive)
    })
  }
}
