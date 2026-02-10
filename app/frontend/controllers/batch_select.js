(function () {
  let listenersAttached = false;

  function init() {
    const selectAll = document.querySelector("[data-batch-select-all]");
    const bar = document.querySelector("[data-batch-bar]");
    const countLabel = document.querySelector("[data-batch-count]");
    const deselectBtn = document.querySelector("[data-batch-deselect]");
    const deleteForm = document.querySelector("[data-batch-delete-form]");

    if (!bar) return;

    function getCheckboxes() {
      return document.querySelectorAll("[data-batch-select-item]");
    }

    function getChecked() {
      return Array.from(getCheckboxes()).filter((cb) => cb.checked);
    }

    function updateBar() {
      const checkboxes = getCheckboxes();
      const checked = getChecked();
      const count = checked.length;

      bar.style.display = count > 0 ? "block" : "none";
      countLabel.textContent =
        count + (count === 1 ? " file selected" : " files selected");

      if (selectAll) {
        selectAll.checked =
          checkboxes.length > 0 && checked.length === checkboxes.length;
        selectAll.indeterminate =
          checked.length > 0 && checked.length < checkboxes.length;
      }
    }

    // Only attach global document listeners once
    if (!listenersAttached) {
      listenersAttached = true;

      // Individual checkbox changes
      document.addEventListener("change", (e) => {
        if (e.target.matches("[data-batch-select-item]")) {
          updateBar();
        }
      });

      // Click filename to toggle its checkbox
      document.addEventListener("click", (e) => {
        const toggle = e.target.closest("[data-batch-select-toggle]");
        if (!toggle) return;

        const uploadId = toggle.dataset.batchSelectToggle;
        const checkbox = document.querySelector(
          '[data-batch-select-item][data-upload-id="' + uploadId + '"]',
        );
        if (checkbox) {
          checkbox.checked = !checkbox.checked;
          updateBar();
        }
      });
    }

    // These reference page-specific elements, rebind on each navigation
    if (selectAll) {
      selectAll.addEventListener("change", () => {
        const checkboxes = getCheckboxes();
        checkboxes.forEach((cb) => {
          cb.checked = selectAll.checked;
        });
        updateBar();
      });
    }

    if (deselectBtn) {
      deselectBtn.addEventListener("click", () => {
        getCheckboxes().forEach((cb) => {
          cb.checked = false;
        });
        if (selectAll) selectAll.checked = false;
        updateBar();
      });
    }

    if (deleteForm) {
      deleteForm.addEventListener("submit", (e) => {
        const checked = getChecked();
        if (checked.length === 0) {
          e.preventDefault();
          return;
        }

        const names = checked.map((cb) => {
          const row = cb.closest("[class*='BorderBox']") || cb.parentElement;
          const nameEl = row.querySelector("[data-batch-select-toggle]");
          return nameEl ? nameEl.textContent.trim() : cb.value;
        });

        const message =
          "Delete " +
          checked.length +
          (checked.length === 1 ? " file" : " files") +
          "?\n\n" +
          names.map((n) => "  \u2022 " + n).join("\n") +
          "\n\nThis cannot be undone.";

        if (!confirm(message)) {
          e.preventDefault();
        }
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  document.addEventListener("turbo:load", init);
})();
