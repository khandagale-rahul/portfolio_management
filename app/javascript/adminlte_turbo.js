// AdminLTE Turbo Integration
// This file ensures AdminLTE components work correctly with Turbo navigation

// Import AdminLTE to ensure it's loaded
import 'admin_lte'

// Constants
const CLASS_NAME_SIDEBAR_COLLAPSE = 'sidebar-collapse'
const CLASS_NAME_SIDEBAR_OPEN = 'sidebar-open'
const CLASS_NAME_HOLD_TRANSITIONS = 'hold-transition'
const SELECTOR_SIDEBAR_TOGGLE = '[data-lte-toggle="sidebar"]'

// Toggle sidebar function with smooth animation
function toggleSidebar() {
  // Remove hold-transition class to allow animations
  document.body.classList.remove(CLASS_NAME_HOLD_TRANSITIONS)

  if (document.body.classList.contains(CLASS_NAME_SIDEBAR_COLLAPSE)) {
    // Expand sidebar
    document.body.classList.remove(CLASS_NAME_SIDEBAR_COLLAPSE)
    document.body.classList.add(CLASS_NAME_SIDEBAR_OPEN)
  } else {
    // Collapse sidebar
    document.body.classList.remove(CLASS_NAME_SIDEBAR_OPEN)
    document.body.classList.add(CLASS_NAME_SIDEBAR_COLLAPSE)
  }
}

// Reinitialize AdminLTE components after Turbo navigation
function initializeAdminLTE() {
  // Reinitialize toggle button listeners
  const sidebarToggleBtns = document.querySelectorAll(SELECTOR_SIDEBAR_TOGGLE)
  sidebarToggleBtns.forEach(btn => {
    // Remove any existing listeners by cloning the node
    const newBtn = btn.cloneNode(true)
    btn.parentNode?.replaceChild(newBtn, btn)

    // Add fresh event listener
    newBtn.addEventListener('click', event => {
      event.preventDefault()
      toggleSidebar()
    })
  })
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', initializeAdminLTE)

// Reinitialize on Turbo navigation
document.addEventListener('turbo:load', initializeAdminLTE)

// Clean up before cache
document.addEventListener('turbo:before-cache', () => {
  // Remove any active states before page is cached
  document.body.classList.remove('sidebar-open', 'sidebar-collapse')
})
