(function () {
  let listenersAttached = false;

  function init() {
    const selectAll = document.querySelector("[data-batch-select-all]");
    const bar = document.querySelector("[data-batch-bar]");
    const countLabel = document.querySelector("[data-batch-count]");
    const deselectBtn = document.querySelector("[data-batch-deselect]");
    const deleteForm = document.querySelector("[data-batch-delete-form]");
    const modal = document.querySelector("[data-batch-modal]");
    let usedSelectAll = false;

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
      if (countLabel) {
        countLabel.textContent =
          count + (count === 1 ? " file selected" : " files selected");
      }

      if (selectAll) {
        selectAll.checked =
          checkboxes.length > 0 && checked.length === checkboxes.length;
        selectAll.indeterminate =
          checked.length > 0 && checked.length < checkboxes.length;
      }

      if (count === 0) {
        usedSelectAll = false;
      }
    }

    function openBatchModal() {
      const m = document.querySelector("[data-batch-modal]");
      if (!m) return;
      const checked = getChecked();
      if (checked.length === 0) return;

      const count = checked.length;
      const isMassDelete = count > 10 || usedSelectAll;

      const titleEl = m.querySelector("[data-batch-modal-title]");
      const promptEl = m.querySelector("[data-batch-modal-prompt]");
      const confirmSection = m.querySelector("[data-batch-modal-confirm-section]");
      const inputEl = m.querySelector("[data-batch-modal-input]");
      const confirmBtn = m.querySelector("[data-batch-modal-confirm-btn]");

      if (isMassDelete) {
        if (titleEl) titleEl.textContent = "Mass delete files?";

        // Extract and sort dates for range
        const dates = checked
          .map((cb) => {
            const iso = cb.getAttribute("data-created-at") || "";
            const formatted = cb.getAttribute("data-formatted-date") || "";
            return { iso, formatted };
          })
          .filter((d) => d.iso);

        let rangeStr = "";
        if (dates.length > 0) {
          dates.sort((a, b) => a.iso.localeCompare(b.iso));
          const minDate = dates[0].formatted;
          const maxDate = dates[dates.length - 1].formatted;

          if (minDate === maxDate) {
            rangeStr = ` uploaded on <strong>${minDate}</strong>`;
          } else {
            rangeStr = ` ranging from <strong>${minDate}</strong> to <strong>${maxDate}</strong>`;
          }
        }

        if (promptEl) {
          promptEl.innerHTML = `Are you sure you want to delete <strong>${count} files</strong>${rangeStr}?`;
        }

        if (confirmSection) {
          confirmSection.style.display = "block";
        }

        if (inputEl) {
          inputEl.value = "";
        }

        if (confirmBtn) {
          const textSpan = confirmBtn.querySelector("[data-batch-modal-confirm-btn-text]");
          const label = `Delete ${count} files`;
          if (textSpan) {
            textSpan.textContent = label;
          } else {
            confirmBtn.textContent = label;
          }
          confirmBtn.disabled = true;
          confirmBtn.style.opacity = "0.6";
          confirmBtn.style.cursor = "not-allowed";
        }

        m.style.display = "flex";
        if (inputEl) {
          setTimeout(() => inputEl.focus(), 50);
        }
      } else {
        // Normal batch delete (<= 10 files and not select all)
        if (titleEl) titleEl.textContent = "Delete selected files?";

        if (promptEl) {
          promptEl.innerHTML = `Are you sure you want to delete <strong>${count} ${count === 1 ? "file" : "files"}</strong>?`;
        }

        if (confirmSection) {
          confirmSection.style.display = "none";
        }

        if (inputEl) {
          inputEl.value = "";
        }

        if (confirmBtn) {
          const textSpan = confirmBtn.querySelector("[data-batch-modal-confirm-btn-text]");
          const label = `Delete ${count} ${count === 1 ? "file" : "files"}`;
          if (textSpan) {
            textSpan.textContent = label;
          } else {
            confirmBtn.textContent = label;
          }
          confirmBtn.disabled = false;
          confirmBtn.style.opacity = "1";
          confirmBtn.style.cursor = "pointer";
        }

        m.style.display = "flex";
        if (confirmBtn) {
          setTimeout(() => confirmBtn.focus(), 50);
        }
      }
    }

    function closeBatchModal() {
      const m = document.querySelector("[data-batch-modal]");
      if (!m) return;
      m.style.display = "none";
      const inputEl = m.querySelector("[data-batch-modal-input]");
      if (inputEl) inputEl.value = "";
    }

    // Only attach global document listeners once
    if (!listenersAttached) {
      listenersAttached = true;

      // Click outside any open <dialog> to dismiss/cancel
      document.addEventListener("click", (e) => {
        if (e.target && e.target.tagName === "DIALOG" && e.target.open) {
          const rect = e.target.getBoundingClientRect();
          const isOutside =
            e.clientX < rect.left ||
            e.clientX > rect.right ||
            e.clientY < rect.top ||
            e.clientY > rect.bottom;
          if (isOutside) {
            e.target.close();
          }
        }
      });

      // Individual checkbox changes
      document.addEventListener("change", (e) => {
        if (e.target.matches("[data-batch-select-item]")) {
          if (!e.target.checked) {
            usedSelectAll = false;
          }
          updateBar();
        }
      });

      // Click filename to toggle its checkbox
      document.addEventListener("click", (e) => {
        const toggle = e.target.closest("[data-batch-select-toggle]");
        if (!toggle) return;

        const uploadId = toggle.dataset.batchSelectToggle;
        const checkbox = document.querySelector(
          '[data-batch-select-item][data-upload-id="' + uploadId + '"]'
        );
        if (checkbox) {
          checkbox.checked = !checkbox.checked;
          if (!checkbox.checked) {
            usedSelectAll = false;
          }
          updateBar();
        }
      });

      // Batch modal close buttons / backdrop
      document.addEventListener("click", (e) => {
        if (e.target.closest("[data-batch-modal-close]") || e.target.id === "batch-delete-modal") {
          closeBatchModal();
        } else if (e.target.closest("[data-batch-trigger-modal]")) {
          e.preventDefault();
          openBatchModal();
        } else if (e.target.closest("[data-batch-modal-confirm-btn]")) {
          const btn = e.target.closest("[data-batch-modal-confirm-btn]");
          if (btn && !btn.disabled) {
            closeBatchModal();
            const form = document.querySelector("[data-batch-delete-form]");
            if (form) form.submit();
          }
        }
      });

      // Confirmation input typing verification: must type 'confirm'
      document.addEventListener("input", (e) => {
        if (e.target.matches("[data-batch-modal-input]")) {
          const m = document.querySelector("[data-batch-modal]");
          if (!m) return;
          const confirmBtn = m.querySelector("[data-batch-modal-confirm-btn]");
          const isMatch = e.target.value.trim().toLowerCase() === "confirm";
          if (confirmBtn) {
            confirmBtn.disabled = !isMatch;
            confirmBtn.style.opacity = isMatch ? "1" : "0.6";
            confirmBtn.style.cursor = isMatch ? "pointer" : "not-allowed";
          }
        }
      });

      // Keyboard shortcuts in modal (Escape to cancel, Enter to submit when valid)
      document.addEventListener("keydown", (e) => {
        const m = document.querySelector("[data-batch-modal]");
        if (!m || m.style.display === "none") return;

        if (e.key === "Escape") {
          closeBatchModal();
        } else if (e.key === "Enter") {
          const confirmBtn = m.querySelector("[data-batch-modal-confirm-btn]");
          if (confirmBtn && !confirmBtn.disabled) {
            e.preventDefault();
            closeBatchModal();
            const form = document.querySelector("[data-batch-delete-form]");
            if (form) form.submit();
          }
        }
      });
    }

    // These reference page-specific elements, rebind on each navigation
    if (selectAll) {
      selectAll.addEventListener("change", () => {
        usedSelectAll = selectAll.checked;
        const checkboxes = getCheckboxes();
        checkboxes.forEach((cb) => {
          cb.checked = selectAll.checked;
        });
        updateBar();
      });
    }

    if (deselectBtn) {
      deselectBtn.addEventListener("click", () => {
        usedSelectAll = false;
        getCheckboxes().forEach((cb) => {
          cb.checked = false;
        });
        if (selectAll) selectAll.checked = false;
        updateBar();
      });
    }

    if (deleteForm) {
      deleteForm.addEventListener("submit", (e) => {
        // Prevent default native form submission or console prompt; route to in-page modal
        e.preventDefault();
        openBatchModal();
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
