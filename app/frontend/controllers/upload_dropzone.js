// Upload dropzone and clipboard paste controller
(function () {
  let initialized = false;
  let form = null;
  let fileInput = null;

  function directUpload(files) {
    if (!files || files.length === 0 || !form) return;

    const formData = new FormData();
    Array.from(files).forEach((file) => {
      formData.append("files[]", file);
    });

    const csrfToken =
      document.querySelector('meta[name="csrf-token"]')?.content ||
      (form ? form.querySelector('input[name="authenticity_token"]')?.value : "") ||
      "";
    if (csrfToken) {
      formData.append("authenticity_token", csrfToken);
    }

    form.submit();
  }

  function bindPasteEvents() {
    window.addEventListener("paste", (e) => {
      if (!e.clipboardData || !e.clipboardData.files) return;
      const target = e.target;
      if (
        target &&
        (target.tagName === "INPUT" ||
          target.tagName === "TEXTAREA" ||
          target.isContentEditable)
      ) {
        return;
      }

      const files = e.clipboardData.files;
      if (files.length > 0) {
        e.preventDefault();
        directUpload(files);
      }
    });
  }

  function bindNativeFileInput() {
    if (!fileInput) return;
    fileInput.addEventListener("change", () => {
      if (fileInput.files && fileInput.files.length > 0) {
        directUpload(fileInput.files);
      }
    });
  }

  function init() {
    const formElement = document.querySelector("[data-dropzone-form]");
    if (!formElement) return;

    form = formElement;
    fileInput = document.querySelector("[data-dropzone-input]");

    if (!initialized) {
      initialized = true;
      bindPasteEvents();
      bindNativeFileInput();
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  document.addEventListener("turbo:load", init);
})();
